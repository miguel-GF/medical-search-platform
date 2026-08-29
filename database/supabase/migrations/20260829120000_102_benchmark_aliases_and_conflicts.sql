-- Complete the reviewed benchmark corpus with safe aliases and explicit
-- clinical contradiction guards.  These guards prevent a similar but wrong
-- analyte (for example T3 libre -> T4 libre) from being selected by fuzzy
-- retrieval.

begin;

insert into catalog.item_aliases(
  item_id, alias, normalized_alias, alias_type, confidence, status,
  source_note, approved_at
)
values
  ('ed7e83db-f394-5171-ae4d-ca347b648028','Tomografía de abdomen completo con contraste','tomografia de abdomen completo con contraste','synonym',1.0000,'approved','Resolver benchmark v1: explicit CT contrast and body scope.',now()),
  ('ed7e83db-f394-5171-ae4d-ca347b648028','TAC abdomen completo con contraste','tac abdomen completo con contraste','abbreviation',1.0000,'approved','Resolver benchmark v1: CT abbreviation preserves contrast and body scope.',now()),
  ('2ae7ac0c-4e14-5aec-96bb-af81d5099e8a','Tomografía de abdomen completo simple','tomografia de abdomen completo simple','synonym',1.0000,'approved','Resolver benchmark v1: explicit CT simple and body scope.',now()),
  ('b6f15c15-29b4-5dd4-b2a2-944e9d0e1b20','Electrocardiograma de esfuerzo','electrocardiograma de esfuerzo','synonym',1.0000,'approved','Resolver benchmark v1: exercise ECG synonym preserves modality context.',now()),
  ('b4994aa8-b7c4-52f3-8f46-c74356d62d4a','Mastografía general','mastografia general','synonym',0.9800,'approved','Resolver benchmark v1: generic mammography wording; no laterality inferred.',now()),
  ('5e21aef5-5328-5ffc-af37-aef84fb1d6a7','Mamografía de ambas mamas','mamografia de ambas mamas','synonym',1.0000,'approved','Resolver benchmark v1: preserves bilateral mammography scope.',now()),
  ('81aa9f9f-737b-537d-9c18-2b023e3e1139','Mamografía de una mama','mamografia de una mama','synonym',1.0000,'approved','Resolver benchmark v1: preserves unilateral mammography scope.',now()),
  ('ceff2afb-eada-5095-9e74-ab7ebbfa21e6','Resonancia de abdomen completo','resonancia de abdomen completo','synonym',1.0000,'approved','Resolver benchmark v1: MRI modality and complete-abdomen scope.',now()),
  ('de354e6e-412d-565f-a5f7-8e6fe27a7680','Resonancia magnética abdomen completo con contraste gadolinio','resonancia magnetica abdomen completo con contraste gadolinio','synonym',1.0000,'approved','Resolver benchmark v1: MRI contrast and complete-abdomen scope.',now()),
  ('de354e6e-412d-565f-a5f7-8e6fe27a7680','RESONANCIA MAGNETICA ABDOMEN COMPLETO CON CONTRASTE GADOLINIO','resonancia magnetica abdomen completo con contraste gadolinio','synonym',1.0000,'approved','Resolver benchmark v1: provider-style MRI contrast label.',now()),
  ('00000000-0000-0000-0000-000000001113','T.3.','t 3','abbreviation',1.0000,'approved','Resolver benchmark v1: OCR punctuation variant of T3.',now()),
  ('00000000-0000-0000-0000-000000001111','T.S.H.','t s h','abbreviation',1.0000,'approved','Resolver benchmark v1: OCR punctuation variant of TSH.',now()),
  ('a1f81444-4b20-5d82-bdf6-b48c27245fa0','Ultrasonido abdominal completo','ultrasonido abdominal completo','synonym',1.0000,'approved','Resolver benchmark v1: ultrasound modality and complete-abdomen scope.',now()),
  ('82d84811-2542-5f8d-8c2c-01186700c4cb','Ultrasonografía obstétrica','ultrasonografia obstetrica','synonym',1.0000,'approved','Resolver benchmark v1: ultrasound modality and obstetric scope.',now()),
  ('a1f81444-4b20-5d82-bdf6-b48c27245fa0','Ultrasonografía abdomen completo','ultrasonografia abdomen completo','synonym',1.0000,'approved','Resolver benchmark v1: ultrasound modality and complete-abdomen scope.',now()),
  ('82d84811-2542-5f8d-8c2c-01186700c4cb','Ecografía obstétrica','ecografia obstetrica','synonym',1.0000,'approved','Resolver benchmark v1: ultrasound modality and obstetric scope.',now())
on conflict do nothing;

-- A query lexicon entry with an impossible service_type acts as a reviewed
-- negative constraint in the existing resolver: every candidate conflicts
-- and is rejected.  This is intentionally narrower than a generic fuzzy
-- blacklist and is auditable through the lexicon source_note.
insert into health.query_lexicon(
  phrase, normalized_phrase, attribute_type, attribute_value, source_note
)
values
  ('T3 libre','t3 libre','service_type','__blocked_analyte_variant__','Resolver benchmark v1: free T3 must not resolve to the reviewed total T3 or free T4 item.'),
  ('Triyodotironina libre','triyodotironina libre','service_type','__blocked_analyte_variant__','Resolver benchmark v1: free T3 is not the reviewed total T3 mapping.'),
  ('Triiodotironina libre','triiodotironina libre','service_type','__blocked_analyte_variant__','Resolver benchmark v1: free T3 is not the reviewed total T3 mapping.')
on conflict do nothing;

commit;
