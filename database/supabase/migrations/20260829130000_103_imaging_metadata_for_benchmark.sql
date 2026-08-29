-- Supply the structured imaging attributes that the resolver needs in order
-- to validate words such as "con contraste" instead of rejecting otherwise
-- exact labels.  These values are copied from the observed provider labels;
-- they do not infer a new clinical equivalence.

begin;

update health.services
set modality = 'tomography', contrast_mode = 'without'
where catalog_item_id = '2ae7ac0c-4e14-5aec-96bb-af81d5099e8a';

update health.services
set modality = 'tomography', contrast_mode = 'with'
where catalog_item_id = 'ed7e83db-f394-5171-ae4d-ca347b648028';

update health.services
set modality = 'magnetic_resonance', contrast_mode = 'without'
where catalog_item_id = 'ceff2afb-eada-5095-9e74-ab7ebbfa21e6';

update health.services
set modality = 'magnetic_resonance', contrast_mode = 'with'
where catalog_item_id = 'de354e6e-412d-565f-a5f7-8e6fe27a7680';

update health.services
set modality = 'radiography', contrast_mode = 'not_applicable'
where catalog_item_id = 'b79cede5-4e29-5b58-816e-b1a0a074b433';

update health.services
set modality = 'ultrasound', contrast_mode = 'not_applicable'
where catalog_item_id in (
  'a1f81444-4b20-5d82-bdf6-b48c27245fa0',
  '82d84811-2542-5f8d-8c2c-01186700c4cb'
);

update health.services
set modality = 'mammography', contrast_mode = 'not_applicable'
where catalog_item_id in (
  'b4994aa8-b7c4-52f3-8f46-c74356d62d4a',
  '5e21aef5-5328-5ffc-af37-aef84fb1d6a7',
  '81aa9f9f-737b-537d-9c18-2b023e3e1139'
);

insert into catalog.item_aliases(
  item_id, alias, normalized_alias, alias_type, confidence, status,
  source_note, approved_at
)
values (
  'b79cede5-4e29-5b58-816e-b1a0a074b433',
  'Rayos X abdomen una posición',
  'rayos x abdomen una posicion',
  'synonym',
  1.0000,
  'approved',
  'Resolver benchmark v1: explicit radiography body and one-position scope.',
  now()
)
on conflict do nothing;

commit;
