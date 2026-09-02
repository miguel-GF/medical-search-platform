# Pruevia Database V1

Executable PostgreSQL/Supabase foundation for the Pruevia data engine.

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

## Apply locally

```bash
supabase init
supabase start
supabase db reset
supabase test db
```

## Deploy to DEV

```bash
supabase login
supabase link
supabase db push --include-seed
```

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

The schemas `analytics`, `marketplace`, `sensitive`, and `billing` are reserved now but their high-volume/transaction tables are added by later migrations when those product phases begin. Their target model is documented in [`../docs/DB_ARCHITECTURE_V1.md`](../docs/DB_ARCHITECTURE_V1.md).
