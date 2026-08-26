-- Additional V1 invariants. Run against the linked project with:
-- supabase db query --linked --file supabase/tests/database_v1_invariants.sql

begin;
create extension if not exists pgtap with schema extensions;

select extensions.plan(10);

select extensions.is(
  core.normalized_text('  RM COLUMNA LS SIMPLE  '),
  'rm columna ls simple',
  'normalized_text removes accents, punctuation and outer whitespace'
);
select extensions.is(
  core.normalized_text('Electromiografía + VCN'),
  'electromiografia vcn',
  'normalized_text is accent-insensitive'
);

insert into catalog.domains(id, code, name)
values
  ('00000000-0000-0000-0000-000000000710', 'fixture_other', 'Fixture other domain')
on conflict (id) do nothing;

insert into core.provider_brands(id, name, normalized_name, slug)
values ('00000000-0000-0000-0000-000000000701', 'Invariant Brand', 'invariant brand', 'invariant-brand');

insert into core.provider_locations(id, provider_brand_id, name, normalized_name, coordinates, timezone)
values
  ('00000000-0000-0000-0000-000000000702', '00000000-0000-0000-0000-000000000701', 'Invariant Location', 'invariant location', gis.st_geogfromtext('SRID=4326;POINT(-99.13 19.43)'), 'America/Mexico_City'),
  ('00000000-0000-0000-0000-000000000703', '00000000-0000-0000-0000-000000000701', 'Invariant Outside Market', 'invariant outside market', gis.st_geogfromtext('SRID=4326;POINT(-99.14 19.44)'), 'America/Mexico_City');

insert into core.provider_markets(id, provider_brand_id, name, normalized_name, slug)
values ('00000000-0000-0000-0000-000000000704', '00000000-0000-0000-0000-000000000701', 'Invariant Market', 'invariant market', 'invariant-market');

insert into core.provider_market_locations(provider_market_id, provider_location_id)
values
  ('00000000-0000-0000-0000-000000000704', '00000000-0000-0000-0000-000000000702'),
  ('00000000-0000-0000-0000-000000000704', '00000000-0000-0000-0000-000000000703');

insert into catalog.items(id, domain_id, item_type, status)
select '00000000-0000-0000-0000-000000000711', id, 'service', 'active'
from catalog.domains where code = 'health_diagnostics';
insert into catalog.item_names(item_id, name, normalized_name, is_primary)
values ('00000000-0000-0000-0000-000000000711', 'Invariant electromyography', 'invariant electromyography', true);
insert into catalog.item_aliases(item_id, alias, normalized_alias, alias_type, status)
values ('00000000-0000-0000-0000-000000000711', 'EMG INVARIANTE', 'emg invariante', 'abbreviation', 'approved');
insert into health.services(catalog_item_id, service_type)
values ('00000000-0000-0000-0000-000000000711', 'neurophysiology');

select extensions.is(
  (select item_id from catalog.search_items('emg invariante', 'health_diagnostics', null, 10) limit 1),
  '00000000-0000-0000-0000-000000000711'::uuid,
  'search_items resolves an approved alias'
);
select extensions.is(
  (select term_source from catalog.search_items('emg invariante', 'health_diagnostics', null, 10) limit 1),
  'alias',
  'search_items reports the alias source'
);

insert into supply.offers(id, provider_brand_id, catalog_item_id, provider_display_name, normalized_provider_name)
values ('00000000-0000-0000-0000-000000000721', '00000000-0000-0000-0000-000000000701', '00000000-0000-0000-0000-000000000711', 'EMG INVARIANTE', 'emg invariante');
insert into supply.offer_scopes(id, offer_id, scope_type, provider_market_id)
values ('00000000-0000-0000-0000-000000000722', '00000000-0000-0000-0000-000000000721', 'market', '00000000-0000-0000-0000-000000000704');
insert into supply.offer_scopes(id, offer_id, scope_type, provider_location_id)
values ('00000000-0000-0000-0000-000000000723', '00000000-0000-0000-0000-000000000721', 'location', '00000000-0000-0000-0000-000000000702');
insert into supply.price_versions(offer_scope_id, amount_minor)
select id, 50000 from supply.offer_scopes
where offer_id = '00000000-0000-0000-0000-000000000721' and scope_type = 'brand';
insert into supply.price_versions(offer_scope_id, amount_minor, day_time_from, day_time_to)
values ('00000000-0000-0000-0000-000000000722', 45000, '08:00', '18:00');
insert into supply.price_versions(offer_scope_id, amount_minor)
values ('00000000-0000-0000-0000-000000000723', 42000);

select extensions.is(
  (select amount_minor from supply.resolve_prices('00000000-0000-0000-0000-000000000721', '00000000-0000-0000-0000-000000000702', '2026-08-25 10:00:00-06'::timestamptz) where price_type = 'regular' and channel = 'any' and price_key = 'default'),
  42000::bigint,
  'location scope wins over market scope'
);
select extensions.is(
  (select amount_minor from supply.resolve_prices('00000000-0000-0000-0000-000000000721', '00000000-0000-0000-0000-000000000703', '2026-08-25 10:00:00-06'::timestamptz) where price_type = 'regular' and channel = 'any' and price_key = 'default'),
  45000::bigint,
  'market scope applies to a member location'
);
select extensions.is(
  (select amount_minor from supply.resolve_prices('00000000-0000-0000-0000-000000000721', '00000000-0000-0000-0000-000000000703', '2026-08-25 20:00:00-06'::timestamptz) where price_type = 'regular' and channel = 'any' and price_key = 'default'),
  50000::bigint,
  'expired time-window eligibility falls back to brand price'
);

insert into catalog.items(id, domain_id, item_type, status)
select '00000000-0000-0000-0000-000000000712', id, 'service', 'active'
from catalog.domains where code = 'health_diagnostics';
insert into catalog.items(id, domain_id, item_type, status)
select '00000000-0000-0000-0000-000000000713', id, 'service', 'active'
from catalog.domains where code = 'health_diagnostics';
insert into health.services(catalog_item_id, service_type)
values
  ('00000000-0000-0000-0000-000000000712', 'other'),
  ('00000000-0000-0000-0000-000000000713', 'other');
insert into health.service_components(parent_service_id, child_service_id)
values ('00000000-0000-0000-0000-000000000712', '00000000-0000-0000-0000-000000000713');

select extensions.throws_ok(
  $$insert into health.service_components(parent_service_id, child_service_id)
    values ('00000000-0000-0000-0000-000000000713', '00000000-0000-0000-0000-000000000712')$$,
  'P0001',
  'Service component relation would create a cycle',
  'service component cycles are rejected'
);

insert into catalog.items(id, domain_id, item_type, status)
select '00000000-0000-0000-0000-000000000714', id, 'service', 'active'
from catalog.domains where code = 'fixture_other';
select extensions.throws_ok(
  $$insert into health.services(catalog_item_id, service_type)
    values ('00000000-0000-0000-0000-000000000714', 'other')$$,
  'P0001',
  'health.services can only reference health_diagnostics catalog items',
  'health services cannot reference another catalog domain'
);

insert into core.provider_brands(id, name, normalized_name, slug)
values ('00000000-0000-0000-0000-000000000705', 'Other Invariant Brand', 'other invariant brand', 'other-invariant-brand');
insert into core.provider_locations(id, provider_brand_id, name, normalized_name)
values ('00000000-0000-0000-0000-000000000706', '00000000-0000-0000-0000-000000000705', 'Other Invariant Location', 'other invariant location');

select extensions.throws_ok(
  $$insert into supply.offer_scopes(offer_id, scope_type, provider_location_id)
    values ('00000000-0000-0000-0000-000000000721', 'location', '00000000-0000-0000-0000-000000000706')$$,
  'P0001',
  'Offer scope belongs to a different provider brand',
  'offer scope cannot reference a different brand'
);

select * from extensions.finish();
rollback;
