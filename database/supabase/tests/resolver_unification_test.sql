-- The public search and resolution contracts must use the same resolver.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(25);

select extensions.has_function(
  'catalog',
  'resolve_items_v6',
  array['text','text','uuid','integer'],
  'unified clinical resolver exists'
);
select extensions.has_function(
  'public',
  'api_resolve_search_v4',
  array['text','text','double precision','double precision','uuid','integer'],
  'unified resolution API exists'
);
select extensions.ok(
  pg_get_functiondef('catalog.search_items(text,text,uuid,integer)'::regprocedure) like '%resolve_items_v6%'
    and pg_get_functiondef('catalog.search_items(text,text,uuid,integer)'::regprocedure) not like '%resolve_items_v5%'
    and pg_get_functiondef('catalog.search_items(text,text,uuid,integer)'::regprocedure) not like '%resolve_items_v4%'
    and pg_get_functiondef('catalog.search_items(text,text,uuid,integer)'::regprocedure) not like '%resolve_items_v3%'
    and pg_get_functiondef('catalog.search_items(text,text,uuid,integer)'::regprocedure) not like '%resolve_items_v2%',
  'tabular search delegates only to the unified resolver'
);
select extensions.ok(
  pg_get_functiondef('public.api_resolve_search(text,text,double precision,double precision,uuid,integer)'::regprocedure) like '%api_resolve_search_v4%',
  'public resolver wrapper delegates to the unified API'
);
select extensions.ok(
  pg_get_functiondef('public.api_search_scoped_v1(text,text,double precision,double precision,uuid,integer)'::regprocedure) like '%catalog.search_items%',
  'scoped tabular API delegates to the catalog search contract'
);
select extensions.ok(
  not has_function_privilege('anon', 'catalog.resolve_items_v2(text,text,uuid,integer)', 'execute')
    and not has_function_privilege('authenticated', 'catalog.resolve_items_v2(text,text,uuid,integer)', 'execute')
    and not has_function_privilege('anon', 'catalog.resolve_items_v3(text,text,uuid,integer)', 'execute')
    and not has_function_privilege('authenticated', 'catalog.resolve_items_v3(text,text,uuid,integer)', 'execute')
    and not has_function_privilege('anon', 'catalog.resolve_items_v5(text,text,uuid,integer)', 'execute')
    and not has_function_privilege('authenticated', 'catalog.resolve_items_v5(text,text,uuid,integer)', 'execute')
    and not has_function_privilege('anon', 'public.api_resolve_search_v2(text,text,double precision,double precision,uuid,integer)', 'execute')
    and not has_function_privilege('authenticated', 'public.api_resolve_search_v2(text,text,double precision,double precision,uuid,integer)', 'execute')
    and not has_function_privilege('anon', 'public.api_resolve_search_v3(text,text,double precision,double precision,uuid,integer)', 'execute')
    and not has_function_privilege('authenticated', 'public.api_resolve_search_v3(text,text,double precision,double precision,uuid,integer)', 'execute'),
  'legacy resolver versions are not public entry points'
);
insert into catalog.item_identifiers(item_id, system, code, version, mapping_type, status, source_note, verified, approved_at)
values (
  '00000000-0000-0000-0000-000000001103',
  'http://loinc.org',
  '99998-1',
  'test',
  'exact',
  'active',
  'transactional resolver test',
  true,
  now()
);
insert into catalog.item_identifiers(item_id, system, code, version, mapping_type, status, source_note, verified, approved_at)
values (
  '00000000-0000-0000-0000-000000001103',
  'http://loinc.org',
  '99998-1',
  'old',
  'exact',
  'active',
  'transactional older-version test',
  true,
  now()
);
select extensions.is(
  (select item_id from catalog.resolve_items_v6('99998-1', 'health_diagnostics', null, 10) limit 1),
  '00000000-0000-0000-0000-000000001103'::uuid,
  'active exact LOINC identifiers resolve to their canonical item'
);
select extensions.is(
  (select public.api_resolve_search('99998-1')->'candidates'->0->>'match_method'),
  'loinc_exact',
  'public resolution preserves the LOINC exact match method'
);
select extensions.is(
  (select count(*)::bigint from catalog.resolve_items_v6('99998-1', 'health_diagnostics', null, 10)),
  1::bigint,
  'multiple reviewed releases for one item do not create duplicate candidates'
);
select extensions.is(
  (select item_id from catalog.search_items('99998-1', 'health_diagnostics', null, 10) limit 1),
  '00000000-0000-0000-0000-000000001103'::uuid,
  'tabular catalog search resolves an active exact LOINC identifier'
);
select extensions.is(
  (select service_id from public.api_search('99998-1', 'health_diagnostics', null, null, null, 10) limit 1),
  '00000000-0000-0000-0000-000000001103'::uuid,
  'public search exposes offers for an exact LOINC identifier'
);
insert into catalog.item_identifiers(item_id, system, code, version, mapping_type, status, source_note)
values (
  '00000000-0000-0000-0000-000000001104',
  'http://loinc.org',
  '99997-0',
  'test',
  'related',
  'active',
  'transactional non-equivalence test'
);
select extensions.is(
  (select count(*)::bigint from catalog.resolve_items_v6('99997-0', 'health_diagnostics', null, 10)),
  0::bigint,
  'non-exact LOINC mappings never resolve as identifiers'
);
insert into catalog.item_identifiers(item_id, system, code, version, mapping_type, status, source_note)
values (
  '00000000-0000-0000-0000-000000001104',
  'http://loinc.org',
  '99996-9',
  'test',
  'exact',
  'active',
  'transactional unverified test'
);
select extensions.is(
  (select count(*)::bigint from catalog.resolve_items_v6('99996-9', 'health_diagnostics', null, 10)),
  0::bigint,
  'unverified exact LOINC mappings never resolve'
);
select extensions.ok(
  to_regclass('catalog.catalog_item_identifiers_loinc_verified_active_idx') is not null,
  'exact active LOINC identifiers have a focused lookup index'
);

select extensions.is(
  (select item_id from catalog.resolve_items_v6('BH', 'health_diagnostics', null, 10) limit 1),
  (select item_id from catalog.search_items('BH', 'health_diagnostics', null, 10) limit 1),
  'exact search and resolver return the same item'
);
select extensions.is(
  (select item_id from catalog.resolve_items_v6('EGO', 'health_diagnostics', null, 10) limit 1),
  (select (public.api_resolve_search('EGO')->'candidates'->0->>'service_id')::uuid),
  'public resolution API uses the unified resolver item'
);
select extensions.is(
  (select count(*)::bigint from catalog.search_items('QS completa', 'health_diagnostics', null, 10)),
  (select jsonb_array_length(public.api_resolve_search('QS completa')->'candidates'))::bigint,
  'ambiguous search and resolution expose the same candidate count'
);
select extensions.is(
  (select public.api_resolve_search('QS completa')->>'status'),
  'ambiguous',
  'unified resolution preserves ambiguity'
);
select extensions.is(
  (select public.api_resolve_search('BH')->>'engine_version'),
  'clinical-resolver-v6',
  'public resolution reports the unified engine version'
);
select extensions.is(
  (select public.api_resolve_search('---')->>'status'),
  'no_match',
  'empty normalized candidate set remains no_match'
);
select extensions.is(
  (select count(*)::bigint from catalog.search_items('hemograma api', 'health_diagnostics', null, 10)),
  (select jsonb_array_length(public.api_resolve_search('hemograma api')->'candidates'))::bigint,
  'alias token guard is identical across contracts'
);
select extensions.is(
  (select item_id from catalog.resolve_items_v6('B H', 'health_diagnostics', null, 10) limit 1),
  (select item_id from catalog.search_items('B H', 'health_diagnostics', null, 10) limit 1),
  'OCR-spaced aliases use the same resolver path'
);
select extensions.is(
  (select count(*)::bigint from catalog.resolve_items_v6('perfil toroideo', 'health_diagnostics', null, 10)),
  (select jsonb_array_length(public.api_resolve_search('perfil toroideo')->'candidates'))::bigint,
  'OCR typo candidate count is consistent'
);
select extensions.ok(
  (select public.api_resolve_search('BH')->'candidates'->0 ? 'match_method'),
  'public candidates keep resolver evidence'
);
select extensions.ok(
  (select public.api_resolve_search('BH')->'candidates'->0 ? 'resolution_status'),
  'public candidates keep resolver status'
);

select * from extensions.finish();
rollback;
