-- Regression tests for the reviewed LOINC 2.83 mappings published by migration 100.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(16);

select extensions.is(
  (select count(*)::integer
   from catalog.item_identifiers
   where lower(trim(system)) = 'http://loinc.org'
     and version = '2.83'
     and mapping_type = 'exact'
     and status = 'active'
     and verified
     and approved_at is not null),
  7,
  'seven reviewed LOINC 2.83 mappings are published'
);

select extensions.ok(
  not exists (
    select 1
    from catalog.item_identifiers ii
    left join catalog.items i on i.id = ii.item_id
    left join health.services s on s.catalog_item_id = ii.item_id
    where lower(trim(ii.system)) = 'http://loinc.org'
      and ii.version = '2.83'
      and (i.id is null or i.status <> 'active' or s.service_type not in ('lab_test', 'lab_panel'))
  ),
  'published LOINC mappings target active laboratory services only'
);

select extensions.is(
  (select count(*)::integer
   from health.lab_service_definitions
   where loinc_version = '2.83' and verified),
  7,
  'all published LOINC mappings have verified laboratory definitions'
);

select extensions.ok(
  to_regclass('catalog.catalog_item_identifiers_loinc_verified_active_idx') is not null,
  'verified active LOINC lookup index exists'
);

select extensions.is(
  (select count(*)::integer
   from catalog.item_identifiers
   where lower(trim(system)) = 'http://loinc.org'
     and version = '2.83'
     and code in ('58410-2','24356-8','2345-7','2160-0','3016-3','3024-7','3053-6')),
  7,
  'the reviewed code set is complete and unique by code'
);

select extensions.is(
  (select count(*)::integer
   from catalog.item_identifiers ii
   where lower(trim(ii.system)) = 'http://loinc.org'
     and ii.version = '2.83'
     and ii.code = '58410-2'
     and ii.item_id = '00000000-0000-0000-0000-000000001103'::uuid),
  1,
  'CBC maps to the canonical hematology service'
);

select extensions.is(
  (select count(*)::integer
   from catalog.item_identifiers ii
   where lower(trim(ii.system)) = 'http://loinc.org'
     and ii.version = '2.83'
     and ii.code = '24356-8'
     and ii.item_id = '00000000-0000-0000-0000-000000001104'::uuid),
  1,
  'complete urinalysis maps to the canonical urinalysis service'
);

select extensions.is(
  (select count(*)::integer
   from catalog.item_identifiers ii
   where lower(trim(ii.system)) = 'http://loinc.org'
     and ii.version = '2.83'
     and ii.code in ('2345-7','2160-0','3016-3','3024-7','3053-6')
     and ii.mapping_type = 'exact'
     and ii.verified
     and ii.approved_at is not null),
  5,
  'five individual chemistry and thyroid mappings are exact and approved'
);

select extensions.ok(
  not exists (
    select 1
    from catalog.item_identifiers
    where lower(trim(system)) = 'http://loinc.org'
      and version = '2.83'
      and (source_note is null or btrim(source_note) = '')
  ),
  'every published LOINC mapping has evidence text'
);

select extensions.is(
  (select count(*)::integer
   from unnest(array['58410-2','24356-8','2345-7','2160-0','3016-3','3024-7','3053-6']) as q(code)
   cross join lateral catalog.resolve_items_v6(q.code, 'health_diagnostics', null, 10) r
   where r.match_method = 'loinc_exact'
     and r.resolution_status = 'resolved'),
  7,
  'every reviewed code resolves exactly in the canonical resolver'
);

select extensions.is(
  (select count(*)::integer
   from unnest(array['58410-2','24356-8','2345-7','2160-0','3016-3','3024-7','3053-6']) as q(code)
   cross join lateral public.api_resolve_search(q.code) payload
   where payload->>'engine_version' = 'clinical-resolver-v6'
     and payload->>'status' = 'resolved'
     and payload->'candidates'->0->>'match_method' = 'loinc_exact'),
  7,
  'public resolution exposes the same exact LOINC evidence'
);

select extensions.is(
  (select count(*)::integer
   from unnest(array['58410-2','24356-8','2345-7','2160-0','3016-3','3024-7','3053-6']) as q(code)
   cross join lateral catalog.search_items(q.code, 'health_diagnostics', null, 10) s
   where s.term_source = 'loinc'),
  7,
  'tabular search exposes the same seven LOINC candidates'
);

select extensions.ok(
  (select count(distinct s.service_id)::integer >= 5
   from unnest(array['58410-2','24356-8','2345-7','2160-0','3016-3','3024-7','3053-6']) as q(code)
   cross join lateral public.api_search(q.code, 'health_diagnostics', null, null, null, 10) s),
  'public offer search preserves the five services with current offers'
);

select extensions.ok(
  not exists (
    select 1
    from catalog.item_identifiers ii
    join health.services s on s.catalog_item_id = ii.item_id
    where lower(trim(ii.system)) = 'http://loinc.org'
      and ii.version = '2.83'
      and s.service_type = 'neurophysiology'
  ),
  'non-laboratory services do not receive LOINC mappings'
);

select extensions.is(
  (select count(*)::integer
   from catalog.item_identifiers
   where lower(trim(system)) = 'http://loinc.org'
     and version = '2.83'
     and code in ('58410-2','24356-8','2345-7','2160-0','3016-3','3024-7','3053-6')
     and mapping_type <> 'exact'),
  0,
  'no non-exact LOINC relationship is publicly active in this release'
);

select extensions.ok(
  (select bool_and(verified and approved_at is not null)
   from catalog.item_identifiers
   where lower(trim(system)) = 'http://loinc.org' and version = '2.83'),
  'the release gate requires verification and approval evidence'
);

select * from extensions.finish();
rollback;
