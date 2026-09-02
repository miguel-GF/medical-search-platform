-- Exact catalog-backed segmentation for free-form prescription lines.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(11);

select extensions.has_function(
  'public',
  'api_segment_package_text',
  array['text', 'text', 'integer'],
  'catalog-backed recipe segmenter exists'
);

select extensions.is(
  (public.api_segment_package_text('BH EGO')->>'status'),
  'segmented',
  'a single line with exact catalog terms is segmented'
);
select extensions.is(
  (select jsonb_array_length(public.api_segment_package_text('BH EGO')->'segments')),
  2,
  'segmentation returns both studies'
);
select extensions.is(
  (public.api_segment_package_text('BH EGO')->'segments'->0->>'method'),
  'catalog_exact',
  'every automatic segment carries exact catalog evidence'
);
select extensions.is(
  (public.api_segment_package_text('BH QS completa EGO Perfil tiroideo')->>'status'),
  'segmented',
  'ambiguous catalog phrases can be separated without selecting a service'
);
select extensions.is(
  (select jsonb_array_length(public.api_segment_package_text('BH QS completa EGO Perfil tiroideo')->'segments')),
  4,
  'the four prescription entries are preserved as four segments'
);
select extensions.is(
  (public.api_segment_package_text('BH QS completa EGO Perfil tiroideo')->'segments'->1->>'method'),
  'catalog_exact_ambiguous',
  'ambiguous segments carry explicit review evidence'
);
select extensions.is(
  (public.api_segment_package_text('BH QS completa EGO Perfil tiroideo')->'segments'->1->>'item_id'),
  null,
  'ambiguous segments never select a canonical service'
);
select extensions.is(
  (public.api_segment_package_text('BH')->>'status'),
  'whole_match',
  'a complete single study is not split'
);
select extensions.is(
  (public.api_segment_package_text('BH EGO texto-no-catalogado')->>'status'),
  'no_match',
  'an incomplete line is not partially split'
);
select extensions.is(
  (public.api_segment_package_text(repeat('x', 4001))->>'status'),
  'invalid_input',
  'direct RPC calls reject oversized text'
);

select * from extensions.finish();
rollback;
