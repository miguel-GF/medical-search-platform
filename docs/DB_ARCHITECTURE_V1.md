# Pruevia — Database Architecture V1

## 1. Architectural stance

Pruevia is modeled as a **reusable catalog/marketplace core** plus a **health-diagnostics domain module**. This is deliberate: the product launches with diagnostic studies, but the same core can later power a different product for medicines, auto parts, industrial parts, etc. without contaminating Pruevia with cross-domain business rules.

The design avoids a universal EAV model. Stable domain concepts are represented as proper relational tables with constraints. JSONB is reserved for evidence/raw payloads, non-core conditions, and audit metadata.

## 2. Schemas

| Schema | Purpose |
|---|---|
| `geo` | Geographic hierarchy and PostGIS shapes/points |
| `core` | Organizations, brands, locations, commercial markets |
| `catalog` | Domain-independent normalized catalog |
| `health` | Health-diagnostics semantics |
| `supply` | Provider offers, scopes, prices, availability, links |
| `ingest` | Sources, crawlers, RAW evidence, normalization, quality |
| `identity` | Application profiles; provider membership is Phase 2 |
| `audit` | Append-oriented security/business audit |
| `ops` | Alerts and feature flags |
| `analytics` | Consent-gated anonymous events and future aggregates |
| `marketplace` | Reserved for leads/appointments/attribution |
| `sensitive` | Reserved for separately controlled personal/health data |
| `billing` | Reserved for PRO/enterprise billing |

## 3. Provider identity model

A provider brand is not a city-specific record.

```text
Organization / legal operator
       |
       +-- Provider Brand: Laboratorios Ruiz
                |
                +-- Puebla / Anzures location
                +-- Puebla / Cholula location
                +-- Querétaro location
```

`core.provider_brand_organizations` supports owner/operator/franchise relationships so an acquisition or franchise does not force us to merge public brands.

La relación legal de una sucursal se mantiene por separado en
`core.provider_location_organizations`, porque el operador, franquiciatario o
entidad de facturación puede cambiar entre ubicaciones. Una reclamación no
reemplaza la evidencia descubierta: agrega una relación verificada, un usuario
con permisos acotados y eventos de auditoría.

La Fase 12 usa dos alcances de reclamación:

- `brand`: la empresa solicita administrar una marca y después selecciona sus
  sucursales;
- `location`: un operador o encargado solicita administrar únicamente una
  sucursal.

Los servicios, precios, horarios y contactos continúan siendo datos de la
sucursal. Una reclamación de marca no copia esos datos a todas las ubicaciones.

`core.provider_markets` represents commercial pricing regions that do not necessarily equal official cities. A market can contain many physical locations. A DB trigger prevents a market from accidentally containing a location from a different provider brand.

## 4. Catalog identity model

`catalog.items` is the stable internal identity of the normalized thing being searched.

For Pruevia it can represent:

- laboratory test;
- laboratory panel;
- imaging study;
- neurophysiology procedure;
- cardiology diagnostic procedure;
- package/concept.

Names are not identity. They live in `catalog.item_names` and `catalog.item_aliases`.

Provider-specific aliases are first-class. Example: a provider-specific package label can map to a canonical item without becoming a global synonym.

External terminologies such as LOINC are mappings in `catalog.item_identifiers`; they are never primary keys.

## 5. Health model

`health.services` is a 1:1 extension of a `catalog.items` row in the `health_diagnostics` domain. A trigger rejects accidental cross-domain inserts.

Strong structured fields cover concepts where free text would be dangerous:

- laterality;
- contrast mode;
- service type;
- anatomy;
- specimens;
- package/components;
- default preparation.

`health.service_components` models panels/packages explicitly. A trigger rejects recursive component cycles.

## 6. Provider offer model

A canonical service and the provider's commercial offer are different entities.

```text
Canonical:
  Resonancia magnética de rodilla sin contraste

Provider offer:
  "RM RODILLA SIMPLE"
```

This is stored in `supply.offers`.

There is intentionally no `UNIQUE(provider,item)` constraint because a provider may legitimately sell multiple variants of the same canonical service. Only one active offer can be marked primary for a provider/item pair.

## 7. Scope and inheritance

Every offer automatically receives a brand scope. Additional scopes can be market- or location-specific.

```text
Brand price             MXN 500
  |
  +-- Puebla market     MXN 450
       |
       +-- Anzures      MXN 420
```

For a request at Anzures the location rule wins; another Puebla branch gets the market rule; a branch outside that market receives the brand rule.

The database validates that scopes belong to the same provider brand as the offer.

## 8. Price model

Prices are versioned facts, not a mutable `offers.price` field.

A current price series is identified by:

- offer scope;
- price type;
- channel;
- `price_key`.

This allows simultaneous:

- regular price;
- web price;
- promotional price;
- member price;
- cash price;
- "from" price.

Time windows and weekday rules support real cases such as a lower tomography price after 13:00 or overnight rules that cross midnight.

`amount_minor` stores money in minor units. MXN 3,806.41 is `380641`, never a floating-point number.

`supply.resolve_prices()` applies scope inheritance plus time/date eligibility.

### Collector update rule

If the price did not change: update `last_seen_at` only.

If it changed: mark the previous series version `is_current=false`, then insert the new version. Never create one identical historical row per crawl.

## 9. Provenance model

Every source has an explicit trust/policy status. A page/API/PDF is an endpoint. A run creates RAW documents/records and source observations.

```text
source
  -> endpoint
     -> crawl run
        -> raw document / record
           -> source observation
              -> normalized business fact
```

This creates traceability from a displayed fact back to the evidence that produced it.

Source precedence belongs in the publisher logic. The intended order is roughly:

1. verified provider-supplied data;
2. official provider API/feed;
3. official provider public site;
4. government data;
5. trusted directory;
6. user report/manual candidate.

A lower-authority crawler must not silently overwrite a newer verified-provider value.

## 10. Crawler safety

`ingest.source_endpoints` stores expected record ranges and allowed negative deviation. `ingest.crawl_runs` stores received/valid/rejected/published counts.

A suspicious run must enter `quarantined`, not publish destructive changes.

Example:

```text
Yesterday: 1,555 studies
Today:       17 studies
Deviation: -98.9%
Decision: QUARANTINE
```

No missing crawl result directly deletes canonical data.

## 11. Normalization

Normalization is evidence-based and reviewable:

```text
raw/provider/OCR text
  -> normalization run
  -> ranked candidates
  -> decision
  -> optionally approved alias
```

Candidate methods include exact, alias, provider alias, trigram, terminology, rules, embeddings and LLM. The V1 search helper only requires exact/alias/trigram. LLM is a last resort, not the primary index.

A normalization decision history is retained. A corrected mapping does not erase the old evidence.

## 12. Search

`catalog.search_terms` unifies canonical names and approved aliases. `catalog.search_items()` uses normalized text and trigram similarity.

Future ranking may combine:

- exact alias confidence;
- provider context;
- terminology matches;
- historical user-resolution feedback;
- domain-specific rules;
- embeddings.

### 12.1 Clinical resolver gate B

Search is split into two decisions:

```text
text/OCR
  -> deterministic resolver
  -> resolved | ambiguous | no_match
  -> provider offers and prices
```

`pg_trgm` and full-text search only generate candidates. The resolver validates
structured health attributes (service type, method, anatomy, laterality,
contrast, specimen and panel components) and rejects hard contradictions. A
short abbreviation is accepted only when it is an approved, unambiguous alias.
Weak fuzzy candidates below the `0.75` confidence guard remain visible as
suggestions requiring confirmation and cannot contribute provider offers.

Ambiguous local terms such as `QS completa` or `perfil tiroideo` return all
reviewed variants separately; no variant is silently selected. The public
contracts are `POST /api/v1/resolve` for one study,
`POST /api/v1/resolve-batch` for an arbitrary list of up to 30 studies, and
`POST /api/v1/resolve-image` for literal OCR before the batch flow. The image
route may use the private Python extractor or an optional Workers AI binding;
both remain outside the clinical decision boundary. The image workflow then
uses `api_resolve_ocr_package`, whose reviewed rules preserve raw text and
attach a correction suggestion without selecting an ambiguous panel. The
batch contract resolves every entry independently, then computes concrete
branch coverage (one branch first, combinations of up to three when needed)
without changing the existing `GET /api/v1/search` contract.

The resolver currently uses PostgreSQL only. Vector retrieval and LLM-assisted
curation remain optional future candidate generators and cannot make the final
clinical equivalence decision.

Provider ingestion follows the same evidence boundary. Official catalogs are
stored in `ingest.raw_records`/`ingest.source_observations`; only reviewed exact
clinical mappings from `clinical_provider_mappings_v1.json` create
`supply.offers` and current prices. DENUE records remain an independent
identity/location evidence source and can support a later provider claim, but
do not establish clinical capability or price validity.

## 13. Merge/split strategy

Catalog IDs are stable. If duplicate concepts are discovered, mark one item `merged` and use `redirect_to_item_id`. Do not hard-delete historical IDs.

If one concept later proves to represent multiple distinct services, mark it `split` and create explicit successor relations. Historical observations remain interpretable.

The same principle applies to closed/moved provider locations: preserve identity/history and link to the replacement when appropriate.

## 14. Privacy stance

Medical-order images are not part of the core database. The preferred future path is:

```text
camera -> on-device OCR when possible -> normalized request
```

If server-side image processing is required, R2 stores the object transiently with a lifecycle deletion policy. Persisted health documents, if ever offered as an opt-in product, belong in the isolated `sensitive` model with separate authorization and encryption controls.

Search analytics should prefer aggregate/coarse geography. The current
`analytics.anonymous_events` table accepts only allowlisted, non-clinical
metadata through a constrained RPC; there is no need to permanently associate
a diagnostic search with a named patient's profile for the B2B demand product.

## 15. Big-data readiness

PostgreSQL remains the transactional source of truth even if Pruevia grows large.

High-volume future events are designed to move independently:

```text
Worker events
   -> operational buffer/stream
   -> R2 Parquet
   -> ClickHouse / BigQuery / equivalent
```

Stable UUID dimensions (`catalog_item_id`, `provider_id`, `location_id`) are deliberately suitable as warehouse dimensions. Event tables use BIGINT identities when added.

We do **not** introduce Kafka/Spark/warehouse infrastructure in MVP. Add an analytical store when operational evidence demands it (e.g. hundreds of millions of events, dashboard pressure, TB-scale historical analysis).

## 16. Phase-2 data model (reserved schemas)

### Analytics

Planned tables:

- `analytics.search_requests`
- `analytics.search_request_items`
- `analytics.result_impressions` (time partitioned)
- `analytics.engagement_events` (time partitioned)
- `analytics.unmatched_queries`
- `analytics.provider_metrics_daily`
- `analytics.demand_metrics_daily`

### Provider identity

- `identity.provider_memberships` (implemented in migration 118)
- `identity.provider_claims` (implemented in migration 118)
- `identity.provider_verifications` (implemented in migration 118)
- `identity.verification_documents` (implemented in migration 118)
- `identity.provider_change_requests` (implemented in migration 121)

El ciclo de vida de claims se endurece en las migraciones 122–126: la aprobación
requiere evidencia documental, las invitaciones deben aceptarse, la revocación
cierra relaciones/membresías sin borrar historia y los RPC quedan limitados por
rol (`authenticated` para autoservicio y `service_role` para administración).

### Marketplace

- `marketplace.leads`
- `marketplace.appointments`
- `marketplace.appointment_status_history`
- `marketplace.attribution_touchpoints`
- `marketplace.provider_integrations`
- `marketplace.webhook_events`
- `marketplace.idempotency_keys`

### Sensitive

- `sensitive.lead_contacts`
- `sensitive.transient_uploads`
- future opt-in saved orders

### Billing

- `billing.plans`
- `billing.subscriptions`
- `billing.entitlements`

These are intentionally not created yet. Their IDs/FKs fit the V1 core without changing core identity.

## 17. Another domain later

A medicine product would add a new `catalog.domains` row plus domain tables such as ingredients, strengths, forms, commercial presentations and regulatory/interchangeability mappings. Pharmacies still use the existing brands, locations, offers, scopes, prices, availability, sources and analytics model.

An auto-parts product would add vehicles, parts, OEM/aftermarket identifiers and fitment rules. The marketplace core remains unchanged.

That is the intended reuse boundary: **shared commerce/discovery infrastructure, strongly typed domain semantics.**
