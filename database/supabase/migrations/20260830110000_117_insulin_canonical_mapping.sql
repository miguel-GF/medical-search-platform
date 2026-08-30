-- Resolve the generic clinical term "Insulina" without conflating it with
-- anti-insulin antibodies or a fasting/baseline challenge measurement.
-- The exact LOINC concept is the active serum/plasma insulin concentration
-- in units/volume (LOINC 20448-7, release 2.83). Provider coverage remains a
-- separate concern: this migration creates no offer until a provider label is
-- verified by a collector.

begin;

insert into catalog.items(id, domain_id, item_type, status)
select
  '00000000-0000-0000-0000-000000001114'::uuid,
  d.id,
  'service',
  'active'
from catalog.domains d
where d.code = 'health_diagnostics'
on conflict (id) do update
set status = 'active', item_type = 'service';

insert into catalog.item_names(item_id, locale, name, normalized_name, name_type, is_primary)
values
  ('00000000-0000-0000-0000-000000001114','es-MX','Insulina','insulina','canonical',true)
on conflict (item_id, locale, normalized_name) do update
set name = excluded.name, is_primary = excluded.is_primary;

insert into health.services(catalog_item_id, service_type, clinical_equivalence_policy, modality)
values
  ('00000000-0000-0000-0000-000000001114','lab_test','terminology_backed',null)
on conflict (catalog_item_id) do update
set service_type = excluded.service_type,
    clinical_equivalence_policy = excluded.clinical_equivalence_policy;

insert into catalog.item_aliases(
  item_id, alias, normalized_alias, alias_type, confidence, status,
  source_note, approved_at
)
values
  ('00000000-0000-0000-0000-000000001114','Insulina sérica','insulina serica','synonym',1.0000,'approved','LOINC 2.83 exact mapping; serum/plasma insulin concentration. Specimen wording is retained.',now()),
  ('00000000-0000-0000-0000-000000001114','Insulina en suero','insulina en suero','synonym',1.0000,'approved','LOINC 2.83 exact mapping; serum/plasma insulin concentration. Specimen wording is retained.',now()),
  ('00000000-0000-0000-0000-000000001114','Insulina en plasma','insulina en plasma','synonym',1.0000,'approved','LOINC 2.83 exact mapping; serum/plasma insulin concentration. Specimen wording is retained.',now())
on conflict do nothing;

insert into catalog.item_identifiers(
  item_id, system, code, version, mapping_type, status,
  source_note, verified, approved_at
)
values (
  '00000000-0000-0000-0000-000000001114',
  'http://loinc.org',
  '20448-7',
  '2.83',
  'exact',
  'active',
  'LOINC 2.83 exact mapping: Insulin [Units/volume] in Serum or Plasma. Generic term only; baseline/challenge variants are not included.',
  true,
  now()
)
on conflict (item_id, system, code, version) do update
set mapping_type = excluded.mapping_type,
    status = excluded.status,
    source_note = excluded.source_note,
    verified = excluded.verified,
    approved_at = excluded.approved_at;

insert into health.lab_service_definitions(
  service_id, component, property, time_aspect, system, scale_type,
  method, order_observation, loinc_version, verified, source_note
)
values (
  '00000000-0000-0000-0000-000000001114',
  'Insulin',
  'ACnc',
  'Pt',
  'Ser/Plas',
  'Qn',
  null,
  'both',
  '2.83',
  true,
  'LOINC 20448-7: generic serum/plasma insulin concentration. Do not infer fasting, baseline, challenge, antibody, or therapeutic context from the generic label.'
)
on conflict (service_id) do update
set component = excluded.component,
    property = excluded.property,
    time_aspect = excluded.time_aspect,
    system = excluded.system,
    scale_type = excluded.scale_type,
    order_observation = excluded.order_observation,
    loinc_version = excluded.loinc_version,
    verified = excluded.verified,
    source_note = excluded.source_note;

commit;
