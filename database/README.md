# Pruevia Database V1

Executable PostgreSQL/Supabase foundation for the Pruevia data engine.

Entrada vigente: [operación y comprobaciones](../docs/OPERATIONS_GUIDE.md).
Para cambios críticos seguir [propuesta y aprobación](../docs/DECISIONS.md#cambios-críticos-y-aprobación).
El modelo V1 de este documento no acredita el esquema actualmente desplegado.

## Goals

- Multi-city and multi-country ready.
- Provider brand -> organization -> physical location separation.
- Canonical catalog independent from each provider's commercial naming.
- Provider-specific aliases without contaminating global terminology.
- Prices inherited by brand/market/location, with location overrides.
- Simultaneous regular/online/promo/member prices and time-window rules.
- Full source provenance and RAW ingestion before normalization/publishing.
- Medical-domain tables separated from reusable marketplace/catalog core.
- Big-data-ready event architecture without adding Big Data infrastructure now.

## Folder layout in this repository

```text
database/
  supabase/
    migrations/
    seed.sql
    tests/
docs/                    # sibling directory: ../docs
```

La migración `20260918100000_product_feedback_android_pilot.sql` prepara el
feedback anónimo y la cola aislada de testers Android en el esquema `research`.
Instala ambos flujos cerrados por defecto. La consulta pública se declara para
adultos en Play, pero no bloquea a menores ni crea cuentas de paciente; la cola
de testers exige confirmar 18 años. Su contrato es
`supabase/tests/product_feedback_pilot_test.sql`. La migración ya fue aplicada
al proyecto DEV enlazado el 19-sep-2026 y el contrato remoto pasó `22/22`.

La migración `20260919100000_pilot_cohort_click_analytics.sql` añade la meta de
20 testers, la activación comprobada y el reloj de 21 días, además de clics
estructurados de oferta y agregados con alcance Admin/proveedor. No almacena texto
de búsquedas ni recetas; las filas pseudónimas vencen a los 400 días para sostener
como máximo la ventana anual del dashboard. Su contrato es
`supabase/tests/pilot_cohort_click_analytics_test.sql` (22 aserciones). Fue
aplicada al proyecto DEV enlazado el 19-sep-2026: el contrato pasó `22/22` y el
de privilegios `30/30`. La configuración permanece cerrada en `0/20`, sin fecha
de inicio y sin envío de notificaciones.

## Apply locally

Desde `database`, el proyecto ya está inicializado. `supabase start` arranca el
entorno local. Un `supabase db reset` recrea sus datos: usarlo sólo en una base
local desechable identificada o con autorización y recuperación adecuadas.
Para contratos enlazados usar `python scripts/run_sql_contracts.py`; si el CLI se
ejecuta mediante npx en Windows, fijar la versiÃ³n con
`python scripts/run_sql_contracts.py --cli npx.cmd --package supabase@2.116.0`.
Consultar
la guía de operación para entorno, precondiciones y selección de pruebas.

## Deploy to DEV

Antes de aplicar cualquier migraciÃ³n, consulta el estado remoto y el corte de
seguridad vigente. Las migraciones de aislamiento Worker/Storage requieren una
ventana coordinada; no ejecutes un `db push` en solitario.

```bash
supabase login
supabase link
npx.cmd supabase@2.116.0 migration list --linked
npx.cmd supabase@2.116.0 db push --linked --dry-run
```

El `db push` real sÃ³lo debe ejecutarse con autorizaciÃ³n explÃ­cita, contratos
SQL aprobados y despliegue coordinado del Worker/scanner. Consulta
`../docs/SECURITY_HARDENING_20260904.md` para el procedimiento actual.

Once migrations are adopted, do not make ad-hoc schema changes directly on the remote project. All database changes should become versioned migration files.

## Extensions

The first migration enables:

- PostGIS (`gis` schema)
- `pg_trgm`
- `unaccent`
- `pgcrypto`

PostGIS powers radius/distance searches. `pg_trgm` powers bounded candidate
generation; the clinical resolver adds token coverage and hard attribute
conflict checks before an item can be considered resolved.

## Data flow

```text
provider website/API/PDF
        |
        v
ingest.raw_documents / raw_records
        |
        v
normalization candidates + decisions
        |
        v
catalog canonical item / clinical resolver
        |
        v
supply offer -> scope -> price / availability
```

A collector must never delete or overwrite canonical production data just because a crawl returned fewer records. Suspicious runs must be quarantined.

## Important V1 decisions

### Provider hierarchy

A brand exists once. Cities are represented by locations/markets, not duplicate brands.

### Canonical catalog

Provider wording is stored in `supply.offers.provider_display_name`; canonical wording stays in `catalog`.

### Price inheritance

Each offer gets a default brand scope. Additional market or location scopes may exist. `supply.resolve_prices()` resolves location > market > brand while respecting validity dates, weekday rules and local-time windows.

### History

Price rows are versioned. A logical price series is uniquely identified by scope + price type + channel + `price_key` while current. Collectors update `last_seen_at` when unchanged and close/insert a version when the amount/rule changes.

### Sensitive data

Medical-order images are intentionally absent from this V1 schema. Temporary/private document storage belongs in R2 and must use short retention by default.

### Free-form prescription lines

`public.api_segment_package_text(text, domain, max_items)` handles a common OCR
or copy/paste shape where several studies arrive on one line without commas or
line breaks. It uses only unique, active catalog names and approved global
aliases, matching complete normalized token sequences. A unique partition is
returned as `segmented` with `catalog_exact` evidence. Approved disambiguation
phrases may be segmented with `catalog_exact_ambiguous`, but never select a
service; the normal resolver then returns candidates for confirmation. A whole
known phrase is `whole_match`; incomplete or multiply-partitionable input returns no segments
so the normal resolver can request clarification. Original text is always
returned and remains the audit/display value.

## What is intentionally not in V1 yet

The schemas `marketplace`, `sensitive`, and `billing` remain reserved for later
phases. `analytics` now contains anonymous product events and structured offer
clicks; it remains private behind service-role RPC boundaries. The broader target
model is documented in [`../docs/DB_ARCHITECTURE_V1.md`](../docs/DB_ARCHITECTURE_V1.md).
