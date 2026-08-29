-- Structured attributes and broad-intent guards discovered by resolver
-- benchmark v2.  These values describe observed catalog labels; they do not
-- create clinical equivalence between different studies.

begin;

update health.services
set modality = 'tomography', contrast_mode = 'with'
where catalog_item_id in (
  'bbc0edbc-d4b7-5987-8aa3-5057fc5a864f',
  '5418efe4-d4d0-5cdb-bedf-689a04a518c8'
);

update health.services
set modality = 'tomography', contrast_mode = 'without'
where catalog_item_id in (
  '3b8beb63-d709-541e-941f-83a739dba3ea',
  'a43d2047-89f1-50c5-99e1-c0d006fe13f4',
  '7bca5f0e-f879-5c55-82c6-bdd03543227e',
  '6cf56af2-aa88-5ff9-b627-4507f1476048',
  '6d4175a9-e365-5241-8859-c2f97a70c0d7',
  'fef75fa2-4ca9-558b-b52e-f38a31c7685f',
  'd585766d-3502-5745-b5d6-7f2e2b1d8a65'
);

insert into health.query_lexicon(
  phrase, normalized_phrase, attribute_type, attribute_value, source_note
)
values
  ('pruebas de covid', 'pruebas de covid', 'service_type', '__blocked_broad_family__',
   'Resolver benchmark v2: COVID family is split into PCR, antigen, antibody and panel services.'),
  ('anticuerpos covid', 'anticuerpos covid', 'service_type', '__blocked_broad_family__',
   'Resolver benchmark v2: antibody target/isotype and panel scope must be explicit.'),
  ('estudios de osteoporosis', 'estudios de osteoporosis', 'service_type', '__blocked_broad_family__',
   'Resolver benchmark v2: bone-density study site and protocol must be explicit.'),
  ('tomografia con contraste', 'tomografia con contraste', 'service_type', '__blocked_broad_family__',
   'Resolver benchmark v2: body region is required before selecting a contrast CT.' )
on conflict (locale, normalized_phrase, attribute_type, attribute_value) do nothing;

commit;
