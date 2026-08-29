-- Fase 10: arbitrary multi-study resolution and concrete branch coverage.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(10);

select extensions.has_function(
  'public',
  'api_resolve_package',
  array['jsonb','text','double precision','double precision','uuid','integer'],
  'package resolver RPC exists'
);

insert into core.provider_brands(id, name, normalized_name, slug)
values ('00000000-0000-0000-0000-000000000901', 'Package Fixture Brand', 'package fixture brand', 'package-fixture-brand');

insert into core.provider_locations(id, provider_brand_id, name, normalized_name, coordinates)
values ('00000000-0000-0000-0000-000000000902', '00000000-0000-0000-0000-000000000901', 'Package Fixture Branch', 'package fixture branch', gis.st_geogfromtext('SRID=4326;POINT(-98.20 19.04)'));

insert into supply.offers(id, provider_brand_id, catalog_item_id, provider_display_name, normalized_provider_name)
values
  ('00000000-0000-0000-0000-000000000911', '00000000-0000-0000-0000-000000000901', '00000000-0000-0000-0000-000000001103', 'Package Fixture Brand', 'package fixture brand'),
  ('00000000-0000-0000-0000-000000000912', '00000000-0000-0000-0000-000000000901', '00000000-0000-0000-0000-000000001104', 'Package Fixture Brand', 'package fixture brand'),
  ('00000000-0000-0000-0000-000000000913', '00000000-0000-0000-0000-000000000901', '00000000-0000-0000-0000-000000001109', 'Package Fixture Brand', 'package fixture brand');

insert into supply.offer_scopes(id, offer_id, scope_type, provider_location_id)
values
  ('00000000-0000-0000-0000-000000000921', '00000000-0000-0000-0000-000000000911', 'location', '00000000-0000-0000-0000-000000000902'),
  ('00000000-0000-0000-0000-000000000922', '00000000-0000-0000-0000-000000000912', 'location', '00000000-0000-0000-0000-000000000902'),
  ('00000000-0000-0000-0000-000000000923', '00000000-0000-0000-0000-000000000913', 'location', '00000000-0000-0000-0000-000000000902');

select extensions.is(
  (select jsonb_array_length(public.api_resolve_package(jsonb_build_array('BH', 'EGO', 'Glucosa'))->'items')),
  3,
  'arbitrary list preserves all three input items'
);
select extensions.is(
  (select count(*) from jsonb_array_elements(public.api_resolve_package(jsonb_build_array('BH', 'EGO', 'Glucosa'))->'items') item where item->>'status' = 'resolved'),
  3::bigint,
  'three unrelated studies resolve independently'
);
select extensions.is(
  (select count(*) from jsonb_array_elements(public.api_resolve_package(jsonb_build_array('BH', 'EGO', 'Glucosa'))->'offers') offer where offer->>'provider_location_id' = '00000000-0000-0000-0000-000000000902'),
  3::bigint,
  'one concrete branch exposes coverage for every study'
);
select extensions.is(
  (select (public.api_resolve_package(jsonb_build_array('BH', 'EGO', 'Glucosa'))->'offers'->0->>'requires_quote')::boolean),
  true,
  'missing prices remain quote-required instead of being fabricated'
);
select extensions.is(
  (select jsonb_array_length(public.api_resolve_package(jsonb_build_array('B H', 'Q S completa', 'EGO', 'perfil toroideo'))->'items')),
  4,
  'prescription-style list preserves four independent inputs'
);
select extensions.is(
  (select count(*) from jsonb_array_elements(public.api_resolve_package(jsonb_build_array('B H', 'Q S completa', 'EGO', 'perfil toroideo'))->'items') item where item->>'status' = 'ambiguous'),
  2::bigint,
  'ambiguous panels remain explicit and do not get guessed'
);
select extensions.is(
  (select count(*) from jsonb_array_elements(public.api_resolve_package(jsonb_build_array('B H', 'Q S completa', 'EGO', 'perfil toroideo'))->'items') item where item->>'status' = 'resolved'),
  2::bigint,
  'unambiguous prescription entries still resolve'
);
select extensions.is(
  (select (public.api_resolve_package(to_jsonb('not-an-array'::text))->'items')::text),
  '[]',
  'malformed JSON input fails closed without scanning offers'
);
select extensions.is(
  (select jsonb_array_length(public.api_resolve_package((select jsonb_agg('BH'::text) from generate_series(1, 31)))->'items')),
  30,
  'direct RPC calls are bounded to 30 entries'
);

select * from extensions.finish();
rollback;
