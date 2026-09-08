-- Pin the search path for internal and trigger functions.  These functions
-- are not SECURITY DEFINER, but leaving the default path mutable allows
-- name-resolution surprises if a writable schema is ever added to a role's
-- path.  Every application object referenced by these bodies is explicitly
-- schema-qualified; pg_catalog is sufficient for built-in operators/functions.
begin;

alter function catalog.resolve_items(text, text, uuid, integer)
  set search_path = pg_catalog;
alter function catalog.resolve_items_v2(text, text, uuid, integer)
  set search_path = pg_catalog;
alter function catalog.resolve_items_v3(text, text, uuid, integer)
  set search_path = pg_catalog;
alter function catalog.resolve_items_v4(text, text, uuid, integer)
  set search_path = pg_catalog;
alter function catalog.resolve_items_v5(text, text, uuid, integer)
  set search_path = pg_catalog;
alter function catalog.resolve_items_v6(text, text, uuid, integer)
  set search_path = pg_catalog;
alter function catalog.search_items(text, text, uuid, integer)
  set search_path = pg_catalog;

alter function catalog.validate_category_parent_domain()
  set search_path = pg_catalog;
alter function catalog.validate_item_category_domain()
  set search_path = pg_catalog;

alter function core.normalized_text(text)
  set search_path = pg_catalog;
alter function core.touch_updated_at()
  set search_path = pg_catalog;
alter function core.touch_updated_at_version()
  set search_path = pg_catalog;
alter function core.validate_provider_claim_scope()
  set search_path = pg_catalog;
alter function core.validate_provider_market_location()
  set search_path = pg_catalog;
alter function core.validate_provider_membership_scope()
  set search_path = pg_catalog;

alter function health.prevent_service_component_cycle()
  set search_path = pg_catalog;
alter function health.validate_service_catalog_item()
  set search_path = pg_catalog;

alter function ingest.touch_endpoint_last_success()
  set search_path = pg_catalog;
alter function ingest.validate_observation_provenance()
  set search_path = pg_catalog;
alter function ingest.validate_raw_record_provenance()
  set search_path = pg_catalog;

alter function public.apply_package_confidence_guard(jsonb)
  set search_path = pg_catalog;
alter function public.apply_resolution_confidence_guard(jsonb)
  set search_path = pg_catalog;

alter function supply.create_default_brand_scope()
  set search_path = pg_catalog;
alter function supply.resolve_prices(uuid, uuid, timestamptz)
  set search_path = pg_catalog;
alter function supply.validate_offer_scope()
  set search_path = pg_catalog;

commit;
