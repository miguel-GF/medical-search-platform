-- Gate B regression tests for deterministic clinical resolution.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(16);

select extensions.has_table('catalog', 'item_descriptions', 'clinical descriptions table exists');
select extensions.has_table('health', 'lab_service_definitions', 'lab attributes table exists');
select extensions.has_table('health', 'query_lexicon', 'query lexicon table exists');
select extensions.has_table('catalog', 'disambiguation_terms', 'disambiguation terms table exists');
select extensions.has_function('catalog', 'resolve_items_v4', array['text','text','uuid','integer'], 'guarded resolver exists');
select extensions.has_function('public', 'api_resolve_search', array['text','text','double precision','double precision','uuid','integer'], 'public resolver RPC exists');

select extensions.is(
  (select item_id from catalog.resolve_items_v4('BH', 'health_diagnostics', null, 10) limit 1),
  '00000000-0000-0000-0000-000000001103'::uuid,
  'BH resolves to biometria hematica'
);
select extensions.is(
  (select item_id from catalog.resolve_items_v4('EGO', 'health_diagnostics', null, 10) limit 1),
  '00000000-0000-0000-0000-000000001104'::uuid,
  'EGO resolves to examen general de orina'
);
select extensions.is(
  (select public.api_resolve_search('QS completa')->>'status'),
  'ambiguous',
  'QS completa is explicitly ambiguous'
);
select extensions.is(
  (select jsonb_array_length(public.api_resolve_search('QS completa')->'candidates')),
  2,
  'QS completa returns both panel variants'
);
select extensions.is(
  (select public.api_resolve_search('perfil toroideo')->>'status'),
  'ambiguous',
  'OCR typo perfil toroideo returns ambiguity'
);
select extensions.is(
  (select count(*)::bigint from jsonb_array_elements(public.api_resolve_search('electromiografia de extremidades inferiore')->'candidates') c
   where c->>'display_name' = 'Electromiografía de extremidades inferiores'),
  1::bigint,
  'lower-extremity electromyography is retained'
);
select extensions.is(
  (select count(*)::bigint from jsonb_array_elements(public.api_resolve_search('biometria hematica')->'candidates') c
   where c->>'display_name' like 'AUDIOMETRIA%'),
  0::bigint,
  'biometria hematica does not leak audiometria'
);
select extensions.is(
  (select public.api_resolve_search('amilasa en suero')->>'status'),
  'resolved',
  'amilasa en suero is not confused with aluminio'
);
select extensions.is(
  (select count(*)::bigint
   from jsonb_array_elements(public.api_resolve_search('BH')->'candidates'->0->'offers') offer
   where offer->>'amount_minor' is null
     and offer->>'provider_location_id' is null),
  0::bigint,
  'resolver removes price-less duplicate brand-scope offers'
);
select extensions.is(
  (select count(*)::bigint
   from jsonb_array_elements(public.api_resolve_search('hemograma api')->'candidates') candidate
   where candidate->>'display_name' = 'Biometría hemática'),
  0::bigint,
  'alias does not ignore unmatched query tokens'
);

select * from extensions.finish();
rollback;
