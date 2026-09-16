-- Patient-facing, sourced summaries for recognized clinical services.

begin;

alter table catalog.item_descriptions
  add column if not exists source_url text;

alter table catalog.item_descriptions
  add constraint catalog_item_descriptions_source_url_https
  check (source_url is null or source_url ~ '^https://[^[:space:]]+$');

insert into catalog.item_descriptions (
  item_id,
  locale,
  description,
  normalized_description,
  description_type,
  status,
  source_note,
  source_url
)
values
  ('00000000-0000-0000-0000-000000001101', 'es-MX', 'Evalúa la actividad eléctrica de los músculos y el funcionamiento de los nervios que los controlan en las extremidades inferiores.', core.normalized_text('Evalúa la actividad eléctrica de los músculos y el funcionamiento de los nervios que los controlan en las extremidades inferiores.'), 'clinical', 'approved', 'MedlinePlus, Biblioteca Nacional de Medicina de EE. UU.; consultado 2026-09-15.', 'https://medlineplus.gov/spanish/pruebas-de-laboratorio/electromiografia-y-estudios-de-conduccion-nerviosa/'),
  ('00000000-0000-0000-0000-000000001102', 'es-MX', 'Evalúa la actividad eléctrica de los músculos y el funcionamiento de los nervios que los controlan en las extremidades superiores.', core.normalized_text('Evalúa la actividad eléctrica de los músculos y el funcionamiento de los nervios que los controlan en las extremidades superiores.'), 'clinical', 'approved', 'MedlinePlus, Biblioteca Nacional de Medicina de EE. UU.; consultado 2026-09-15.', 'https://medlineplus.gov/spanish/pruebas-de-laboratorio/electromiografia-y-estudios-de-conduccion-nerviosa/'),
  ('00000000-0000-0000-0000-000000001103', 'es-MX', 'Mide la cantidad y características de glóbulos rojos, glóbulos blancos y plaquetas, además de hemoglobina y hematocrito, en una muestra de sangre.', core.normalized_text('Mide la cantidad y características de glóbulos rojos, glóbulos blancos y plaquetas, además de hemoglobina y hematocrito, en una muestra de sangre.'), 'clinical', 'approved', 'MedlinePlus, Biblioteca Nacional de Medicina de EE. UU.; consultado 2026-09-15.', 'https://medlineplus.gov/spanish/ency/article/003642.htm'),
  ('00000000-0000-0000-0000-000000001104', 'es-MX', 'Examina características físicas y sustancias presentes en la orina; puede incluir pH, proteínas, glucosa, células y microorganismos.', core.normalized_text('Examina características físicas y sustancias presentes en la orina; puede incluir pH, proteínas, glucosa, células y microorganismos.'), 'clinical', 'approved', 'MedlinePlus, Biblioteca Nacional de Medicina de EE. UU.; consultado 2026-09-15.', 'https://medlineplus.gov/spanish/urinalysis.html'),
  ('00000000-0000-0000-0000-000000001105', 'es-MX', 'Agrupa mediciones en sangre relacionadas con el metabolismo, la glucosa, los electrolitos y la función renal. Los componentes exactos pueden variar por proveedor.', core.normalized_text('Agrupa mediciones en sangre relacionadas con el metabolismo, la glucosa, los electrolitos y la función renal. Los componentes exactos pueden variar por proveedor.'), 'clinical', 'approved', 'Resumen general basado en MedlinePlus; los componentes comerciales deben verificarse con el proveedor.', 'https://medlineplus.gov/spanish/pruebas-de-laboratorio/panel-metabolico-completo-pmc/'),
  ('00000000-0000-0000-0000-000000001106', 'es-MX', 'Agrupa varias mediciones de química sanguínea para ofrecer una vista amplia del metabolismo y del funcionamiento de distintos órganos. Los componentes exactos pueden variar por proveedor.', core.normalized_text('Agrupa varias mediciones de química sanguínea para ofrecer una vista amplia del metabolismo y del funcionamiento de distintos órganos. Los componentes exactos pueden variar por proveedor.'), 'clinical', 'approved', 'Resumen general basado en MedlinePlus; los componentes comerciales deben verificarse con el proveedor.', 'https://medlineplus.gov/spanish/pruebas-de-laboratorio/panel-metabolico-completo-pmc/'),
  ('00000000-0000-0000-0000-000000001107', 'es-MX', 'Agrupa mediciones usadas para revisar el funcionamiento de la tiroides, como TSH, T3 o T4. Los componentes exactos pueden variar por proveedor.', core.normalized_text('Agrupa mediciones usadas para revisar el funcionamiento de la tiroides, como TSH, T3 o T4. Los componentes exactos pueden variar por proveedor.'), 'clinical', 'approved', 'Resumen general basado en MedlinePlus; los componentes comerciales deben verificarse con el proveedor.', 'https://medlineplus.gov/spanish/thyroidtests.html'),
  ('00000000-0000-0000-0000-000000001108', 'es-MX', 'Agrupa varias mediciones de hormonas y otros marcadores tiroideos. Los componentes exactos del perfil ampliado pueden variar por proveedor.', core.normalized_text('Agrupa varias mediciones de hormonas y otros marcadores tiroideos. Los componentes exactos del perfil ampliado pueden variar por proveedor.'), 'clinical', 'approved', 'Resumen general basado en MedlinePlus; los componentes comerciales deben verificarse con el proveedor.', 'https://medlineplus.gov/spanish/thyroidtests.html'),
  ('00000000-0000-0000-0000-000000001109', 'es-MX', 'Mide la cantidad de glucosa, un tipo de azúcar y principal fuente de energía del cuerpo, presente en una muestra de sangre.', core.normalized_text('Mide la cantidad de glucosa, un tipo de azúcar y principal fuente de energía del cuerpo, presente en una muestra de sangre.'), 'clinical', 'approved', 'MedlinePlus, Biblioteca Nacional de Medicina de EE. UU.; consultado 2026-09-15.', 'https://medlineplus.gov/spanish/pruebas-de-laboratorio/prueba-de-glucosa-en-la-sangre/'),
  ('00000000-0000-0000-0000-000000001110', 'es-MX', 'Mide la creatinina en sangre u orina; esta sustancia de desecho suele eliminarse del cuerpo mediante los riñones.', core.normalized_text('Mide la creatinina en sangre u orina; esta sustancia de desecho suele eliminarse del cuerpo mediante los riñones.'), 'clinical', 'approved', 'MedlinePlus, Biblioteca Nacional de Medicina de EE. UU.; consultado 2026-09-15.', 'https://medlineplus.gov/spanish/pruebas-de-laboratorio/prueba-de-creatinina/'),
  ('00000000-0000-0000-0000-000000001111', 'es-MX', 'Mide en sangre la hormona estimulante de la tiroides (TSH), una señal que ayuda a regular cuánta hormona produce la tiroides.', core.normalized_text('Mide en sangre la hormona estimulante de la tiroides (TSH), una señal que ayuda a regular cuánta hormona produce la tiroides.'), 'clinical', 'approved', 'MedlinePlus, Biblioteca Nacional de Medicina de EE. UU.; consultado 2026-09-15.', 'https://medlineplus.gov/spanish/pruebas-de-laboratorio/prueba-de-tsh/'),
  ('00000000-0000-0000-0000-000000001112', 'es-MX', 'Mide la tiroxina libre (T4 libre), la fracción de esta hormona tiroidea disponible para entrar a los tejidos.', core.normalized_text('Mide la tiroxina libre (T4 libre), la fracción de esta hormona tiroidea disponible para entrar a los tejidos.'), 'clinical', 'approved', 'MedlinePlus, Biblioteca Nacional de Medicina de EE. UU.; consultado 2026-09-15.', 'https://medlineplus.gov/spanish/pruebas-de-laboratorio/prueba-de-tiroxina-t4/'),
  ('00000000-0000-0000-0000-000000001113', 'es-MX', 'Mide el nivel de triyodotironina (T3), una hormona producida por la tiroides, en una muestra de sangre.', core.normalized_text('Mide el nivel de triyodotironina (T3), una hormona producida por la tiroides, en una muestra de sangre.'), 'clinical', 'approved', 'MedlinePlus, Biblioteca Nacional de Medicina de EE. UU.; consultado 2026-09-15.', 'https://medlineplus.gov/spanish/pruebas-de-laboratorio/pruebas-de-triyodotironina-t3/')
on conflict (item_id, locale, description_type) do update
set description = excluded.description,
    normalized_description = excluded.normalized_description,
    status = excluded.status,
    source_note = excluded.source_note,
    source_url = excluded.source_url;

create or replace function public.api_service_summaries(
  p_service_ids uuid[],
  p_locale text default 'es-MX'
)
returns table (
  service_id uuid,
  description text,
  source_url text
)
language sql
stable
security definer
set search_path = pg_catalog, catalog, health
as $$
  select requested.service_id, descriptions.description, descriptions.source_url
  from unnest(coalesce(p_service_ids, '{}'::uuid[])) with ordinality requested(service_id, position)
  join catalog.items items
    on items.id = requested.service_id
   and items.status = 'active'
  join health.services services
    on services.catalog_item_id = items.id
  join catalog.item_descriptions descriptions
    on descriptions.item_id = requested.service_id
   and descriptions.locale = p_locale
   and descriptions.description_type = 'clinical'
   and descriptions.status = 'approved'
  where cardinality(coalesce(p_service_ids, '{}'::uuid[])) between 1 and 100
  order by requested.position;
$$;

revoke all on function public.api_service_summaries(uuid[], text) from public, anon, authenticated;
grant execute on function public.api_service_summaries(uuid[], text) to service_role;

commit;
