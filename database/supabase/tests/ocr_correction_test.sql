-- Fase 10: curated OCR corrections remain separate from text search and
-- preserve ambiguity for panels.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(15);

select extensions.has_function(
  'public',
  'api_resolve_ocr_package',
  array['jsonb','text','double precision','double precision','uuid','integer'],
  'OCR package resolver RPC exists'
);

select extensions.is(
  (select public.api_resolve_search('OBH')->>'status'),
  'no_match',
  'OCR corrections do not alter ordinary text search'
);

select extensions.is(
  (select public.api_resolve_ocr_package(jsonb_build_array('OBH'))->'items'->0->>'input'),
  'OBH',
  'raw OCR input is preserved'
);

select extensions.is(
  (select public.api_resolve_ocr_package(jsonb_build_array('OBH'))->'items'->0->'ocr_correction'->>'suggested_text'),
  'BH',
  'leading-O OCR confusion maps to BH'
);

select extensions.is(
  (select public.api_resolve_ocr_package(jsonb_build_array('OBH'))->'items'->0->>'status'),
  'resolved',
  'unambiguous BH correction resolves'
);

select extensions.is(
  (select public.api_resolve_ocr_package(jsonb_build_array('OQS completa'))->'items'->0->>'status'),
  'ambiguous',
  'QS panel remains ambiguous after OCR correction'
);

select extensions.is(
  (select public.api_resolve_ocr_package(jsonb_build_array('OQS completa'))->'items'->0->'ocr_correction'->>'suggested_text'),
  'Q S completa',
  'OCR abbreviation spacing correction is auditable'
);

select extensions.is(
  (select public.api_resolve_ocr_package(jsonb_build_array('Pertil firondle'))->'items'->0->>'status'),
  'ambiguous',
  'profile OCR correction does not choose basic or expanded'
);

select extensions.is(
  (select public.api_resolve_ocr_package(jsonb_build_array('Pertil firondle'))->'items'->0->'ocr_correction'->>'suggested_text'),
  'Perfil tiroideo',
  'profile OCR variant maps to a reviewed disambiguation term'
);

select extensions.is(
  (select public.api_resolve_ocr_package(jsonb_build_array('GlurOsO e INUliUA'))->'items'->0->'ocr_correction'->>'suggested_text'),
  'Glucosa e Insulina',
  'human-confirmed compound OCR transcription is auditable'
);

select extensions.is(
  (select public.api_resolve_ocr_package(jsonb_build_array('GlurOsO e INUliUA'))->'items'->0->>'status'),
  'no_match',
  'compound line does not invent a generic Insulina catalog equivalence'
);

select extensions.is(
  (select jsonb_array_length(public.api_resolve_ocr_package(jsonb_build_array('GlurOsO e INUliUA'))->'ocr_corrections')),
  1,
  'compound OCR correction is returned for user confirmation'
);

select extensions.is(
  (select jsonb_array_length(public.api_resolve_ocr_package(jsonb_build_array('EGO'))->'ocr_corrections')),
  0,
  'already readable EGO receives no correction'
);

select extensions.is(
  (select jsonb_array_length(public.api_resolve_ocr_package((select jsonb_agg('OBH'::text) from generate_series(1, 31)))->'items')),
  30,
  'OCR package input remains bounded to 30 entries'
);

select extensions.is(
  (select jsonb_array_length(public.api_resolve_ocr_package(jsonb_build_array('OBH'), 'other_domain')->'ocr_corrections')),
  0,
  'OCR rules are scoped to the health diagnostics domain'
);

select * from extensions.finish();
rollback;
