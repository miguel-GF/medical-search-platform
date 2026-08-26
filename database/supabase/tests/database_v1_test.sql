-- pgTAP smoke/invariant tests for Pruevia DB V1.
-- Run with: supabase test db

begin;
create extension if not exists pgtap with schema extensions;

select extensions.plan(15);

select extensions.has_schema('catalog', 'catalog schema exists');
select extensions.has_schema('supply', 'supply schema exists');
select extensions.has_schema('ingest', 'ingest schema exists');
select extensions.has_table('catalog', 'items', 'catalog.items exists');
select extensions.has_table('supply', 'price_versions', 'supply.price_versions exists');
select extensions.has_table('ingest', 'raw_records', 'ingest.raw_records exists');
select extensions.has_function('catalog', 'search_items', array['text','text','uuid','integer'], 'catalog.search_items exists');
select extensions.has_function('supply', 'resolve_prices', array['uuid','uuid','timestamp with time zone'], 'supply.resolve_prices exists');
select extensions.is((select count(*)::bigint from catalog.domains where code='health_diagnostics'), 1::bigint, 'health_diagnostics domain seeded');
select extensions.is((select count(*)::bigint from health.specimen_types), 9::bigint, 'specimen seed count is stable');
select extensions.is((select count(*)::bigint from ops.feature_flags), 4::bigint, 'feature flags seeded');

-- Deterministic fixture for scope/price inheritance.
insert into core.provider_brands(id,name,normalized_name,slug)
values ('00000000-0000-0000-0000-000000000101','Fixture Brand','fixture brand','fixture-brand');

insert into core.provider_locations(id,provider_brand_id,name,normalized_name,coordinates)
values
 ('00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000101','Location Override','location override',gis.st_geogfromtext('SRID=4326;POINT(-98.2 19.04)')),
 ('00000000-0000-0000-0000-000000000202','00000000-0000-0000-0000-000000000101','Market Fallback','market fallback',gis.st_geogfromtext('SRID=4326;POINT(-98.21 19.05)')),
 ('00000000-0000-0000-0000-000000000203','00000000-0000-0000-0000-000000000101','Brand Fallback','brand fallback',gis.st_geogfromtext('SRID=4326;POINT(-98.22 19.06)'));

insert into core.provider_markets(id,provider_brand_id,name,normalized_name,slug)
values ('00000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000101','Fixture Market','fixture market','fixture-market');

insert into core.provider_market_locations(provider_market_id,provider_location_id)
values
 ('00000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000201'),
 ('00000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000202');

insert into catalog.items(id,domain_id,item_type,status)
select '00000000-0000-0000-0000-000000000401', id, 'service', 'active'
from catalog.domains where code='health_diagnostics';

insert into catalog.item_names(item_id,name,normalized_name,is_primary)
values ('00000000-0000-0000-0000-000000000401','Fixture Study','fixture study',true);

insert into health.services(catalog_item_id,service_type)
values ('00000000-0000-0000-0000-000000000401','other');

insert into supply.offers(id,provider_brand_id,catalog_item_id,provider_display_name,normalized_provider_name)
values ('00000000-0000-0000-0000-000000000501','00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000401','Fixture Study','fixture study');

-- Trigger created the brand scope. Add market/location scopes.
insert into supply.offer_scopes(id,offer_id,scope_type,provider_market_id)
values ('00000000-0000-0000-0000-000000000601','00000000-0000-0000-0000-000000000501','market','00000000-0000-0000-0000-000000000301');
insert into supply.offer_scopes(id,offer_id,scope_type,provider_location_id)
values ('00000000-0000-0000-0000-000000000602','00000000-0000-0000-0000-000000000501','location','00000000-0000-0000-0000-000000000201');

insert into supply.price_versions(offer_scope_id,amount_minor)
select id,50000 from supply.offer_scopes where offer_id='00000000-0000-0000-0000-000000000501' and scope_type='brand';
insert into supply.price_versions(offer_scope_id,amount_minor)
values
 ('00000000-0000-0000-0000-000000000601',45000),
 ('00000000-0000-0000-0000-000000000602',42000);

select extensions.is(
  (select amount_minor from supply.resolve_prices('00000000-0000-0000-0000-000000000501','00000000-0000-0000-0000-000000000201',now()) where price_type='regular' and channel='any' and price_key='default'),
  42000::bigint,
  'location price overrides market and brand'
);
select extensions.is(
  (select amount_minor from supply.resolve_prices('00000000-0000-0000-0000-000000000501','00000000-0000-0000-0000-000000000202',now()) where price_type='regular' and channel='any' and price_key='default'),
  45000::bigint,
  'market price overrides brand'
);
select extensions.is(
  (select amount_minor from supply.resolve_prices('00000000-0000-0000-0000-000000000501','00000000-0000-0000-0000-000000000203',now()) where price_type='regular' and channel='any' and price_key='default'),
  50000::bigint,
  'brand price is fallback outside market'
);

-- Cross-brand market membership must be rejected.
insert into core.provider_brands(id,name,normalized_name,slug)
values ('00000000-0000-0000-0000-000000000102','Other Brand','other brand','other-brand');
insert into core.provider_locations(id,provider_brand_id,name,normalized_name)
values ('00000000-0000-0000-0000-000000000204','00000000-0000-0000-0000-000000000102','Other Location','other location');

select extensions.throws_ok(
  $$insert into core.provider_market_locations(provider_market_id,provider_location_id)
    values ('00000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000204')$$,
  'P0001',
  'Provider market and location must belong to the same brand',
  'cross-brand market/location corruption is blocked'
);

select * from extensions.finish();
rollback;
