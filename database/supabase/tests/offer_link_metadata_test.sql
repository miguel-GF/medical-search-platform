-- Contract for typed offer links and provider hand-offs.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(20);

select extensions.has_column('supply', 'offer_links', 'link_target',
  'offer links distinguish study, location, booking and provider targets');
select extensions.has_column('supply', 'offer_links', 'link_capability',
  'offer links retain their preload capability');
select extensions.has_column('supply', 'offer_links', 'handoff_data',
  'offer links retain structured hand-off metadata');
select extensions.has_function(
  'supply',
  'resolve_offer_link_metadata',
  array['uuid', 'uuid'],
  'link metadata helper resolves links for a concrete location'
);
select extensions.ok(
  position('study_url text' in pg_get_function_result(
    'public.api_search(text,text,double precision,double precision,uuid,integer)'::regprocedure
  )) > 0,
  'api_search exposes a study URL field'
);
select extensions.ok(
  position('location_url text' in pg_get_function_result(
    'public.api_search(text,text,double precision,double precision,uuid,integer)'::regprocedure
  )) > 0,
  'api_search exposes a location URL field'
);
select extensions.ok(
  position('booking_url text' in pg_get_function_result(
    'public.api_search(text,text,double precision,double precision,uuid,integer)'::regprocedure
  )) > 0,
  'api_search exposes a booking URL field'
);
select extensions.ok(
  position('link_capability text' in pg_get_function_result(
    'public.api_search(text,text,double precision,double precision,uuid,integer)'::regprocedure
  )) > 0,
  'api_search exposes link capability'
);
select extensions.ok(
  position('provider_location_id is distinct from' in pg_get_functiondef(
    'public.api_resolve_search_v4(text,text,double precision,double precision,uuid,integer)'::regprocedure
  )) > 0,
  'resolver suppresses a legacy fallback when a concrete branch exists'
);

insert into core.provider_brands(id, name, normalized_name, slug)
values (
  '00000000-0000-0000-0000-00000000b101',
  'Offer Link Fixture',
  'offer link fixture',
  'offer-link-fixture'
);
insert into core.provider_locations(
  id, provider_brand_id, name, normalized_name, location_code, website_url
)
values (
  '00000000-0000-0000-0000-00000000b102',
  '00000000-0000-0000-0000-00000000b101',
  'Offer Link Branch',
  'offer link branch',
  'fixture-branch',
  'https://example.test/fixture-branch'
);
insert into core.provider_markets(
  id, provider_brand_id, name, normalized_name, slug, market_type
)
values (
  '00000000-0000-0000-0000-00000000b103',
  '00000000-0000-0000-0000-00000000b101',
  'Offer Link Market',
  'offer link market',
  'offer-link-market',
  'city'
);
insert into core.provider_market_locations(provider_market_id, provider_location_id)
values (
  '00000000-0000-0000-0000-00000000b103',
  '00000000-0000-0000-0000-00000000b102'
);
insert into catalog.items(id, domain_id, item_type, status)
select '00000000-0000-0000-0000-00000000b104', id, 'service', 'active'
from catalog.domains where code = 'health_diagnostics';
insert into catalog.item_names(item_id, name, normalized_name, is_primary)
values (
  '00000000-0000-0000-0000-00000000b104',
  'Offer Link Study',
  'offer link study',
  true
);
insert into health.services(catalog_item_id, service_type)
values ('00000000-0000-0000-0000-00000000b104', 'lab_test');
insert into supply.offers(
  id, provider_brand_id, catalog_item_id, provider_display_name, normalized_provider_name
)
values (
  '00000000-0000-0000-0000-00000000b105',
  '00000000-0000-0000-0000-00000000b101',
  '00000000-0000-0000-0000-00000000b104',
  'Offer Link Study',
  'offer link study'
);
insert into supply.offer_scopes(
  id, offer_id, scope_type, provider_market_id
)
values (
  '00000000-0000-0000-0000-00000000b106',
  '00000000-0000-0000-0000-00000000b105',
  'market',
  '00000000-0000-0000-0000-00000000b103'
);
insert into supply.offer_scopes(
  id, offer_id, scope_type, provider_location_id
)
values (
  '00000000-0000-0000-0000-00000000b107',
  '00000000-0000-0000-0000-00000000b105',
  'location',
  '00000000-0000-0000-0000-00000000b102'
);

insert into supply.offer_links(offer_scope_id, link_type, url)
values (
  '00000000-0000-0000-0000-00000000b106',
  'details',
  'https://example.test/offer-link-study'
);
select extensions.is(
  (select link_target from supply.offer_links where offer_scope_id = '00000000-0000-0000-0000-00000000b106'),
  'study',
  'legacy details links default to study target'
);
select extensions.is(
  (select link_capability from supply.offer_links where offer_scope_id = '00000000-0000-0000-0000-00000000b106'),
  'study_only',
  'legacy details links default to study-only capability'
);
select extensions.is(
  (select study_url from supply.resolve_offer_link_metadata(
    '00000000-0000-0000-0000-00000000b105',
    '00000000-0000-0000-0000-00000000b102'
  )),
  'https://example.test/offer-link-study',
  'study link is resolved through the market scope'
);

insert into supply.offer_links(
  offer_scope_id, link_type, link_target, link_capability, url
)
values (
  '00000000-0000-0000-0000-00000000b107',
  'details',
  'location',
  'location_only',
  'https://example.test/fixture-branch'
);
select extensions.is(
  (select location_url from supply.resolve_offer_link_metadata(
    '00000000-0000-0000-0000-00000000b105',
    '00000000-0000-0000-0000-00000000b102'
  )),
  'https://example.test/fixture-branch',
  'location link is resolved only for its concrete branch'
);
select extensions.is(
  (select link_capability from supply.resolve_offer_link_metadata(
    '00000000-0000-0000-0000-00000000b105',
    '00000000-0000-0000-0000-00000000b102'
  )),
  'study_and_location',
  'study and location links report a combined capability'
);

insert into supply.offer_links(
  offer_scope_id, link_type, link_target, link_capability, url
)
values (
  '00000000-0000-0000-0000-00000000b107',
  'booking',
  'booking',
  'provider_only',
  'https://example.test/booking'
);
select extensions.is(
  (select booking_url from supply.resolve_offer_link_metadata(
    '00000000-0000-0000-0000-00000000b105',
    '00000000-0000-0000-0000-00000000b102'
  )),
  'https://example.test/booking',
  'booking URL is exposed independently from study and branch URLs'
);

insert into supply.offer_links(
  offer_scope_id, link_type, link_target, link_capability, url, handoff_data
)
values (
  '00000000-0000-0000-0000-00000000b107',
  'other',
  'handoff',
  'none',
  'https://example.test/handoff',
  '{"study_label":"Offer Link Study","location_code":"fixture-branch","reason":"provider requires manual selection"}'::jsonb
);
select extensions.is(
  (select handoff_data->>'location_code' from supply.resolve_offer_link_metadata(
    '00000000-0000-0000-0000-00000000b105',
    '00000000-0000-0000-0000-00000000b102'
  )),
  'fixture-branch',
  'handoff metadata survives without fabricating a deep-link'
);

select extensions.throws_ok(
  $$insert into supply.offer_links(
      offer_scope_id, link_type, link_target, link_capability, url
    ) values (
      '00000000-0000-0000-0000-00000000b106',
      'details', 'location', 'location_only', 'https://example.test/wrong-scope'
    )$$,
  'P0001',
  'Location links require a location offer scope',
  'location links cannot be attached to a market scope'
);

select extensions.is(
  (select count(*)::bigint
   from jsonb_array_elements(
     public.api_resolve_package_internal(
       '["Offer Link Study"]'::jsonb,
       'health_diagnostics',
       null,
       null,
       null,
       100
     )->'offers'
   ) offer
   where offer->>'provider_name' = 'Offer Link Fixture'),
  1::bigint,
  'package resolution does not expand a concrete offer to unrelated branches'
);

select extensions.is(
  (select count(*)::bigint
   from jsonb_array_elements(
     public.api_resolve_search_v4(
       'Offer Link Study',
       'health_diagnostics',
       null,
       null,
       null,
       20
     )->'candidates'
   ) candidate
   cross join jsonb_array_elements(candidate->'offers') offer
   where offer->>'provider_name' = 'Offer Link Fixture'),
  1::bigint,
  'search resolution does not expand a concrete offer to unrelated branches'
);

select extensions.is(
  (select count(*)::bigint
   from supply.offer_scopes os
   join supply.offers o on o.id = os.offer_id
   join core.provider_brands b on b.id = o.provider_brand_id
   where b.slug = 'salud-digna'
     and os.scope_type in ('market', 'brand')
     and os.status = 'active'),
  0::bigint,
  'Salud Digna has no active unreconciled market or brand scopes'
);

select * from extensions.finish();
rollback;
