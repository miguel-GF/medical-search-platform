-- The public search and resolution contracts must use the same resolver.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(13);

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
