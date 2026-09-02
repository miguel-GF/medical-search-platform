# Pruevia V1 Table Catalog

The executable foundation currently creates **59 tables**. That is larger than the early ~30-table estimate because the physical review kept provenance, data quality, scope inheritance, geographic integrity, provider identity, audit and consent-gated analytics concerns separate instead of hiding them in JSON.

## `geo` (1)

- `areas` — hierarchical official/commercial geography with PostGIS support.

## `core` (11)

- `organizations` — legal/operator entities.
- `provider_brands` — public-facing provider brands.
- `provider_brand_organizations` — ownership/operator/franchise relationships.
- `provider_locations` — physical sites.
- `provider_location_organizations` — legal owner/operator/franchise relationships at a specific site.
- `provider_location_hours` — regular opening windows.
- `provider_location_closures` — exceptional closures.
- `provider_markets` — provider commercial/pricing regions.
- `provider_market_locations` — market/location membership.
- `provider_external_ids` — DENUE/other brand identifiers.
- `location_external_ids` — DENUE/other location identifiers.

## `catalog` (12)

- `domains`
- `items`
- `item_names`
- `item_aliases`
- `categories`
- `item_categories`
- `item_identifiers`
- `item_relations`
- `disambiguation_terms`
- `disambiguation_candidates`
- `item_descriptions`
- `ocr_correction_rules`

## `health` (10)

- `anatomical_sites`
- `services`
- `service_anatomy`
- `specimen_types`
- `service_specimens`
- `service_components`
- `service_preparations`
- `lab_service_definitions`
- `service_methods`
- `query_lexicon`

## `supply` (5)

- `offers`
- `offer_scopes`
- `price_versions`
- `offer_links`
- `availability_current`

## `ingest` (10)

- `sources`
- `source_endpoints`
- `crawl_runs`
- `raw_documents`
- `raw_records`
- `source_observations`
- `normalization_runs`
- `normalization_candidates`
- `normalization_decisions`
- `data_quality_issues`

## `identity` (6)

- `user_profiles`
- `provider_claims` — company/brand or individual-location claim requests.
- `provider_verifications` — auditable verification attempts and outcomes.
- `verification_documents` — private object references and hashes, never raw documents in core.
- `provider_memberships` — scoped organization/brand/location roles.
- `provider_change_requests` — reviewed provider proposals for location profile fields.

## `audit` (1)

- `events`

## `ops` (2)

- `system_alerts`
- `feature_flags`

## `analytics` (1)

- `anonymous_events` — consent-gated, non-clinical event envelopes. Direct
  table access is revoked for Data API roles; inserts go through a constrained
  RPC.

The `marketplace`, `sensitive`, and `billing` schemas remain reserved until
those product phases begin.
