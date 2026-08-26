-- Minimal deterministic seed data for Pruevia DEV.

insert into catalog.domains(code, name, description)
values (
  'health_diagnostics',
  'Health diagnostics',
  'Diagnostic studies, laboratory tests, imaging and related medical procedures.'
)
on conflict (code) do nothing;

with d as (select id from catalog.domains where code = 'health_diagnostics')
insert into catalog.categories(domain_id, code, name, slug, sort_order)
select d.id, x.code, x.name, x.slug, x.sort_order
from d
cross join (values
  ('laboratory', 'Laboratorio', 'laboratorio', 10),
  ('imaging', 'Imagen', 'imagen', 20),
  ('neurophysiology', 'Neurofisiología', 'neurofisiologia', 30),
  ('cardiology', 'Cardiología', 'cardiologia', 40),
  ('endoscopy', 'Endoscopia', 'endoscopia', 50),
  ('pathology', 'Patología', 'patologia', 60),
  ('functional_tests', 'Pruebas funcionales', 'pruebas-funcionales', 70),
  ('other', 'Otros', 'otros', 90)
) as x(code, name, slug, sort_order)
on conflict (domain_id, code) do nothing;

insert into health.specimen_types(code, name, normalized_name)
values
  ('blood', 'Sangre', 'sangre'),
  ('serum', 'Suero', 'suero'),
  ('plasma', 'Plasma', 'plasma'),
  ('urine', 'Orina', 'orina'),
  ('stool', 'Heces', 'heces'),
  ('saliva', 'Saliva', 'saliva'),
  ('tissue', 'Tejido', 'tejido'),
  ('swab', 'Hisopo', 'hisopo'),
  ('other', 'Otro', 'otro')
on conflict (code) do nothing;

insert into ops.feature_flags(key, description, enabled)
values
  ('photo_ocr_enabled', 'Enable photo/OCR order intake for patients.', false),
  ('provider_claims_enabled', 'Enable provider profile claiming.', false),
  ('appointments_enabled', 'Enable internal appointment booking.', false),
  ('sponsored_results_enabled', 'Enable clearly marked sponsored results.', false)
on conflict (key) do nothing;
