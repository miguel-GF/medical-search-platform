-- Deterministic clinical resolver: structured attributes, lexical evidence and abstention.

begin;

create table if not exists catalog.item_descriptions (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references catalog.items(id) on delete cascade,
  locale text not null default 'es-MX',
  description text not null,
  normalized_description text not null,
  description_type text not null default 'clinical'
    check (description_type in ('clinical','provider','technical','preparation','other')),
  status text not null default 'approved'
    check (status in ('candidate','approved','rejected','deprecated')),
  source_note text,
  created_at timestamptz not null default now(),
  unique (item_id, locale, description_type)
);

create index if not exists catalog_item_descriptions_trgm_idx
  on catalog.item_descriptions using gin (normalized_description extensions.gin_trgm_ops);

create table if not exists health.lab_service_definitions (
  service_id uuid primary key references health.services(catalog_item_id) on delete cascade,
  component text,
  property text,
  time_aspect text,
  system text,
  scale_type text,
  method text,
  order_observation text not null default 'both'
    check (order_observation in ('order','observation','both','unknown')),
  loinc_version text,
  verified boolean not null default false,
  source_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists health.service_methods (
  service_id uuid not null references health.services(catalog_item_id) on delete cascade,
  method_code text not null,
  method_name text not null,
  normalized_method_name text not null,
  is_primary boolean not null default false,
  status text not null default 'approved'
    check (status in ('candidate','approved','rejected','deprecated')),
  source_note text,
  created_at timestamptz not null default now(),
  primary key (service_id, method_code)
);

create unique index if not exists health_service_methods_one_primary_idx
  on health.service_methods(service_id) where is_primary;
create index if not exists health_service_methods_name_trgm_idx
  on health.service_methods using gin (normalized_method_name extensions.gin_trgm_ops);

create table if not exists health.query_lexicon (
  id uuid primary key default gen_random_uuid(),
  locale text not null default 'es-MX',
  phrase text not null,
  normalized_phrase text not null,
  attribute_type text not null check (attribute_type in (
    'service_type','method','modality','anatomical_site','laterality','contrast_mode',
    'specimen','component','panel','other'
  )),
  attribute_value text not null,
  status text not null default 'approved'
    check (status in ('candidate','approved','rejected','deprecated')),
  source_note text,
  created_at timestamptz not null default now(),
  unique (locale, normalized_phrase, attribute_type, attribute_value)
);

create index if not exists health_query_lexicon_phrase_idx
  on health.query_lexicon(locale, normalized_phrase);

create table if not exists catalog.disambiguation_terms (
  id uuid primary key default gen_random_uuid(),
  locale text not null default 'es-MX',
  term text not null,
  normalized_term text not null,
  status text not null default 'approved'
    check (status in ('candidate','approved','rejected','deprecated')),
  source_note text,
  created_at timestamptz not null default now(),
  unique (locale, normalized_term)
);

create table if not exists catalog.disambiguation_candidates (
  term_id uuid not null references catalog.disambiguation_terms(id) on delete cascade,
  item_id uuid not null references catalog.items(id) on delete restrict,
  priority integer not null default 0,
  reason text,
  created_at timestamptz not null default now(),
  primary key (term_id, item_id)
);

create index if not exists catalog_disambiguation_candidates_item_idx
  on catalog.disambiguation_candidates(item_id);

create trigger trg_health_lab_service_definitions_touch_updated_at
before update on health.lab_service_definitions
for each row execute function core.touch_updated_at();

-- Canonical concepts required for the first resolver gate. They are deliberately
-- independent from provider offers; an unresolved commercial mapping must not
-- prevent the engine from identifying the clinical concept.
insert into catalog.items(id, domain_id, item_type, status)
select x.id, d.id, 'service', 'active'
from (values
  ('00000000-0000-0000-0000-000000001101'::uuid),
  ('00000000-0000-0000-0000-000000001102'::uuid),
  ('00000000-0000-0000-0000-000000001103'::uuid),
  ('00000000-0000-0000-0000-000000001104'::uuid),
  ('00000000-0000-0000-0000-000000001105'::uuid),
  ('00000000-0000-0000-0000-000000001106'::uuid),
  ('00000000-0000-0000-0000-000000001107'::uuid),
  ('00000000-0000-0000-0000-000000001108'::uuid),
  ('00000000-0000-0000-0000-000000001109'::uuid),
  ('00000000-0000-0000-0000-000000001110'::uuid),
  ('00000000-0000-0000-0000-000000001111'::uuid),
  ('00000000-0000-0000-0000-000000001112'::uuid),
  ('00000000-0000-0000-0000-000000001113'::uuid)
) as x(id)
cross join catalog.domains d
where d.code = 'health_diagnostics'
on conflict (id) do update set status = 'active', item_type = 'service';

insert into catalog.item_names(item_id, locale, name, normalized_name, name_type, is_primary)
values
  ('00000000-0000-0000-0000-000000001101','es-MX','Electromiografía de extremidades inferiores','electromiografia de extremidades inferiores','canonical',true),
  ('00000000-0000-0000-0000-000000001102','es-MX','Electromiografía de extremidades superiores','electromiografia de extremidades superiores','canonical',true),
  ('00000000-0000-0000-0000-000000001103','es-MX','Biometría hemática','biometria hematica','canonical',true),
  ('00000000-0000-0000-0000-000000001104','es-MX','Examen general de orina','examen general de orina','canonical',true),
  ('00000000-0000-0000-0000-000000001105','es-MX','Química sanguínea básica','quimica sanguinea basica','canonical',true),
  ('00000000-0000-0000-0000-000000001106','es-MX','Química sanguínea ampliada','quimica sanguinea ampliada','canonical',true),
  ('00000000-0000-0000-0000-000000001107','es-MX','Perfil tiroideo básico','perfil tiroideo basico','canonical',true),
  ('00000000-0000-0000-0000-000000001108','es-MX','Perfil tiroideo ampliado','perfil tiroideo ampliado','canonical',true),
  ('00000000-0000-0000-0000-000000001109','es-MX','Glucosa','glucosa','canonical',true),
  ('00000000-0000-0000-0000-000000001110','es-MX','Creatinina','creatinina','canonical',true),
  ('00000000-0000-0000-0000-000000001111','es-MX','TSH','tsh','canonical',true),
  ('00000000-0000-0000-0000-000000001112','es-MX','T4 libre','t4 libre','canonical',true),
  ('00000000-0000-0000-0000-000000001113','es-MX','T3','t3','canonical',true)
on conflict (item_id, locale, normalized_name) do update
set name = excluded.name, is_primary = excluded.is_primary;

insert into health.services(catalog_item_id, service_type, clinical_equivalence_policy, modality)
values
  ('00000000-0000-0000-0000-000000001101','neurophysiology','strict',null),
  ('00000000-0000-0000-0000-000000001102','neurophysiology','strict',null),
  ('00000000-0000-0000-0000-000000001103','lab_test','terminology_backed',null),
  ('00000000-0000-0000-0000-000000001104','lab_test','terminology_backed',null),
  ('00000000-0000-0000-0000-000000001105','lab_panel','manual_if_ambiguous',null),
  ('00000000-0000-0000-0000-000000001106','lab_panel','manual_if_ambiguous',null),
  ('00000000-0000-0000-0000-000000001107','lab_panel','manual_if_ambiguous',null),
  ('00000000-0000-0000-0000-000000001108','lab_panel','manual_if_ambiguous',null),
  ('00000000-0000-0000-0000-000000001109','lab_test','terminology_backed',null),
  ('00000000-0000-0000-0000-000000001110','lab_test','terminology_backed',null),
  ('00000000-0000-0000-0000-000000001111','lab_test','terminology_backed',null),
  ('00000000-0000-0000-0000-000000001112','lab_test','terminology_backed',null),
  ('00000000-0000-0000-0000-000000001113','lab_test','terminology_backed',null)
on conflict (catalog_item_id) do update
set service_type = excluded.service_type,
    clinical_equivalence_policy = excluded.clinical_equivalence_policy;

insert into catalog.item_aliases(item_id, alias, normalized_alias, alias_type, confidence, status, source_note, approved_at)
values
  ('00000000-0000-0000-0000-000000001101','EMG de miembros inferiores','emg de miembros inferiores','abbreviation',1,'approved','Resolver Gate B curated alias',now()),
  ('00000000-0000-0000-0000-000000001103','BH','bh','abbreviation',1,'approved','Resolver Gate B curated abbreviation',now()),
  ('00000000-0000-0000-0000-000000001103','Hemograma','hemograma','synonym',1,'approved','Resolver Gate B curated synonym',now()),
  ('00000000-0000-0000-0000-000000001104','EGO','ego','abbreviation',1,'approved','Resolver Gate B curated abbreviation',now()),
  ('00000000-0000-0000-0000-000000001104','Uroanálisis','uroanalisis','synonym',1,'approved','Resolver Gate B curated synonym',now())
on conflict do nothing;

insert into health.service_methods(service_id, method_code, method_name, normalized_method_name, is_primary, source_note)
values
  ('00000000-0000-0000-0000-000000001101','electromyography','Electromiografía','electromiografia',true,'Resolver Gate B curated method'),
  ('00000000-0000-0000-0000-000000001102','electromyography','Electromiografía','electromiografia',true,'Resolver Gate B curated method')
on conflict (service_id, method_code) do update
set method_name = excluded.method_name,
    normalized_method_name = excluded.normalized_method_name,
    is_primary = excluded.is_primary;

insert into health.lab_service_definitions(service_id, component, property, time_aspect, system, scale_type, method, order_observation, loinc_version, verified, source_note)
values
  ('00000000-0000-0000-0000-000000001103','complete blood count','number concentration','point in time','blood','quantitative',null,'both','2.82',false,'Pending terminology review'),
  ('00000000-0000-0000-0000-000000001104','urinalysis','finding','point in time','urine','nominal',null,'both','2.82',false,'Pending terminology review'),
  ('00000000-0000-0000-0000-000000001109','glucose','substance concentration','point in time','serum/plasma','quantitative',null,'both','2.82',false,'Pending terminology review'),
  ('00000000-0000-0000-0000-000000001110','creatinine','substance concentration','point in time','serum/plasma','quantitative',null,'both','2.82',false,'Pending terminology review'),
  ('00000000-0000-0000-0000-000000001111','thyrotropin','mass concentration','point in time','serum/plasma','quantitative',null,'both','2.82',false,'Pending terminology review'),
  ('00000000-0000-0000-0000-000000001112','thyroxine free','mass concentration','point in time','serum/plasma','quantitative',null,'both','2.82',false,'Pending terminology review'),
  ('00000000-0000-0000-0000-000000001113','triiodothyronine','mass concentration','point in time','serum/plasma','quantitative',null,'both','2.82',false,'Pending terminology review')
on conflict (service_id) do update
set component = excluded.component, property = excluded.property, system = excluded.system,
    order_observation = excluded.order_observation, loinc_version = excluded.loinc_version;

insert into health.anatomical_sites(code, name, normalized_name, laterality_applicable)
values
  ('lower_extremity','Extremidad inferior','extremidad inferior',false),
  ('upper_extremity','Extremidad superior','extremidad superior',false)
on conflict do nothing;

update health.anatomical_sites
set name = case code when 'lower_extremity' then 'Extremidad inferior' else 'Extremidad superior' end,
    normalized_name = case code when 'lower_extremity' then 'extremidad inferior' else 'extremidad superior' end
where code in ('lower_extremity','upper_extremity');

insert into health.service_anatomy(service_id, anatomical_site_id, role)
select x.service_id, a.id, 'region'
from (values
  ('00000000-0000-0000-0000-000000001101'::uuid,'lower_extremity'),
  ('00000000-0000-0000-0000-000000001102'::uuid,'upper_extremity')
) x(service_id, code)
join health.anatomical_sites a on a.code = x.code
on conflict do nothing;

insert into health.query_lexicon(phrase, normalized_phrase, attribute_type, attribute_value, source_note)
values
  ('electromiografía','electromiografia','service_type','neurophysiology','Resolver Gate B curated phrase'),
  ('electromiografía','electromiografia','method','electromyography','Resolver Gate B curated phrase'),
  ('electrodiagnóstico','electrodiagnostico','service_type','neurophysiology','Resolver Gate B curated phrase'),
  ('electrodiagnóstico','electrodiagnostico','method','electromyography','Resolver Gate B curated phrase'),
  ('extremidades inferiores','extremidades inferiores','anatomical_site','lower_extremity','Resolver Gate B curated phrase'),
  ('miembros inferiores','miembros inferiores','anatomical_site','lower_extremity','Resolver Gate B curated phrase'),
  ('extremidades superiores','extremidades superiores','anatomical_site','upper_extremity','Resolver Gate B curated phrase'),
  ('miembros superiores','miembros superiores','anatomical_site','upper_extremity','Resolver Gate B curated phrase'),
  ('sin contraste','sin contraste','contrast_mode','none','Resolver Gate B curated phrase'),
  ('con contraste','con contraste','contrast_mode','with','Resolver Gate B curated phrase')
on conflict do nothing;

insert into catalog.disambiguation_terms(term, normalized_term, source_note)
values
  ('QS completa','qs completa','La composición de química sanguínea completa depende del proveedor.'),
  ('Perfil tiroideo','perfil tiroideo','Los proveedores pueden ofrecer perfiles tiroideos con componentes distintos.')
on conflict (locale, normalized_term) do update set term = excluded.term, source_note = excluded.source_note;

insert into catalog.disambiguation_candidates(term_id, item_id, priority, reason)
select t.id, x.item_id, x.priority, x.reason
from catalog.disambiguation_terms t
join (values
  ('qs completa','00000000-0000-0000-0000-000000001105'::uuid,1,'Panel básico; confirmar componentes.'),
  ('qs completa','00000000-0000-0000-0000-000000001106'::uuid,2,'Panel ampliado; confirmar componentes.'),
  ('perfil tiroideo','00000000-0000-0000-0000-000000001107'::uuid,1,'Perfil básico; confirmar componentes.'),
  ('perfil tiroideo','00000000-0000-0000-0000-000000001108'::uuid,2,'Perfil ampliado; confirmar componentes.')
) x(normalized_term,item_id,priority,reason) on x.normalized_term = t.normalized_term
on conflict (term_id, item_id) do update set priority = excluded.priority, reason = excluded.reason;

insert into health.service_components(parent_service_id, child_service_id, is_required, component_order, notes)
values
  ('00000000-0000-0000-0000-000000001105','00000000-0000-0000-0000-000000001109',true,1,'QS básica'),
  ('00000000-0000-0000-0000-000000001106','00000000-0000-0000-0000-000000001109',true,1,'QS ampliada'),
  ('00000000-0000-0000-0000-000000001106','00000000-0000-0000-0000-000000001110',true,2,'QS ampliada'),
  ('00000000-0000-0000-0000-000000001107','00000000-0000-0000-0000-000000001111',true,1,'Perfil tiroideo básico'),
  ('00000000-0000-0000-0000-000000001107','00000000-0000-0000-0000-000000001112',true,2,'Perfil tiroideo básico'),
  ('00000000-0000-0000-0000-000000001108','00000000-0000-0000-0000-000000001111',true,1,'Perfil tiroideo ampliado'),
  ('00000000-0000-0000-0000-000000001108','00000000-0000-0000-0000-000000001112',true,2,'Perfil tiroideo ampliado'),
  ('00000000-0000-0000-0000-000000001108','00000000-0000-0000-0000-000000001113',true,3,'Perfil tiroideo ampliado')
on conflict (parent_service_id, child_service_id) do update
set is_required = excluded.is_required, component_order = excluded.component_order, notes = excluded.notes;

create or replace function catalog.resolve_items(
  p_query text,
  p_domain_code text default 'health_diagnostics',
  p_provider_brand_id uuid default null,
  p_limit integer default 10
)
returns table (
  item_id uuid,
  display_name text,
  matched_term text,
  term_source text,
  provider_brand_id uuid,
  confidence numeric,
  resolution_status text,
  match_method text,
  explanation_data jsonb,
  result_rank bigint
)
language sql
stable
parallel safe
as $$
with q as (
  select core.normalized_text(p_query) as normalized_query
), qattrs as (
  select distinct l.attribute_type, l.attribute_value
  from health.query_lexicon l
  cross join q
  where l.status = 'approved'
    and q.normalized_query like '%' || l.normalized_phrase || '%'
), disambiguation as (
  select distinct t.id as term_id, t.normalized_term
  from catalog.disambiguation_terms t
  cross join q
  where t.status = 'approved'
    and (q.normalized_query = t.normalized_term
      or extensions.word_similarity(t.normalized_term, q.normalized_query) >= 0.70)
), terms as (
  select n.item_id, n.locale, n.name as term, n.normalized_name as normalized_term,
         'name'::text as term_source, null::uuid as provider_brand_id,
         case when n.is_primary then 1.00::numeric else 0.98::numeric end as weight
  from catalog.item_names n
  join catalog.items i on i.id = n.item_id and i.status = 'active'
  join catalog.domains d on d.id = i.domain_id and d.code = p_domain_code
  union all
  select a.item_id, a.locale, a.alias, a.normalized_alias, 'alias'::text,
         a.provider_brand_id, a.confidence
  from catalog.item_aliases a
  join catalog.items i on i.id = a.item_id and i.status = 'active'
  join catalog.domains d on d.id = i.domain_id and d.code = p_domain_code
  where a.status = 'approved'
    and (a.provider_brand_id is null or a.provider_brand_id = p_provider_brand_id)
  union all
  select d.item_id, d.locale, d.description, d.normalized_description, 'description'::text,
         null::uuid, 0.90::numeric
  from catalog.item_descriptions d
  join catalog.items i on i.id = d.item_id and i.status = 'active'
  join catalog.domains dm on dm.id = i.domain_id and dm.code = p_domain_code
  where d.status = 'approved'
  union all
  select dc.item_id, t.locale, t.term, t.normalized_term, 'disambiguation'::text,
         null::uuid, 0.90::numeric
  from disambiguation dx
  join catalog.disambiguation_terms t on t.id = dx.term_id
  join catalog.disambiguation_candidates dc on dc.term_id = t.id
  join catalog.items i on i.id = dc.item_id and i.status = 'active'
), scored as (
  select
    t.item_id,
    coalesce((select n.name from catalog.item_names n where n.item_id = t.item_id and n.is_primary order by n.locale = 'es-MX' desc limit 1), t.term) as display_name,
    t.term as matched_term,
    t.term_source,
    t.provider_brand_id,
    extensions.similarity(t.normalized_term, q.normalized_query)::numeric as similarity_score,
    extensions.word_similarity(t.normalized_term, q.normalized_query)::numeric as word_score,
    case when t.normalized_term = q.normalized_query then 1.00::numeric
         when t.term_source = 'disambiguation' then 0.92::numeric
         when q.normalized_query like '%' || t.normalized_term || '%' then 0.88::numeric
         else greatest(extensions.similarity(t.normalized_term, q.normalized_query)::numeric * t.weight,
                       extensions.word_similarity(t.normalized_term, q.normalized_query)::numeric * t.weight)
    end as lexical_score,
    t.weight,
    row_number() over (partition by t.item_id order by
      case when t.normalized_term = q.normalized_query then 0 else 1 end,
      t.weight desc,
      extensions.word_similarity(t.normalized_term, q.normalized_query) desc,
      extensions.similarity(t.normalized_term, q.normalized_query) desc
    ) as term_rank
  from terms t
  cross join q
  where q.normalized_query <> ''
    and (t.normalized_term = q.normalized_query
      or t.term_source = 'disambiguation'
      or q.normalized_query like '%' || t.normalized_term || '%'
      or t.normalized_term like '%' || q.normalized_query || '%'
      or extensions.similarity(t.normalized_term, q.normalized_query) >= 0.35
      or extensions.word_similarity(t.normalized_term, q.normalized_query) >= 0.45)
), best as (
  select * from scored where term_rank = 1
), enriched as (
  select
    b.*,
    coalesce((select count(*) from qattrs),0)::integer as attribute_count,
    coalesce((select count(*) from qattrs qa where
      (qa.attribute_type = 'service_type' and exists (
        select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.service_type = qa.attribute_value
      )) or (qa.attribute_type = 'method' and exists (
        select 1 from health.service_methods sm where sm.service_id = b.item_id and sm.status = 'approved' and sm.method_code = qa.attribute_value
      )) or (qa.attribute_type = 'modality' and exists (
        select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.modality = qa.attribute_value
      )) or (qa.attribute_type = 'anatomical_site' and exists (
        select 1 from health.service_anatomy sa join health.anatomical_sites an on an.id = sa.anatomical_site_id where sa.service_id = b.item_id and an.code = qa.attribute_value
      )) or (qa.attribute_type = 'laterality' and exists (
        select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.laterality = qa.attribute_value
      )) or (qa.attribute_type = 'contrast_mode' and exists (
        select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.contrast_mode = qa.attribute_value
      )) or (qa.attribute_type = 'specimen' and exists (
        select 1 from health.service_specimens ss join health.specimen_types sp on sp.id = ss.specimen_type_id where ss.service_id = b.item_id and (sp.code = qa.attribute_value or sp.normalized_name = qa.attribute_value)
      ))
    ),0)::integer as attribute_matches,
    exists (select 1 from qattrs qa where
      (qa.attribute_type = 'service_type' and not exists (select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.service_type = qa.attribute_value))
      or (qa.attribute_type = 'method' and not exists (select 1 from health.service_methods sm where sm.service_id = b.item_id and sm.status = 'approved' and sm.method_code = qa.attribute_value))
      or (qa.attribute_type = 'modality' and not exists (select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.modality = qa.attribute_value))
      or (qa.attribute_type = 'anatomical_site' and not exists (select 1 from health.service_anatomy sa join health.anatomical_sites an on an.id = sa.anatomical_site_id where sa.service_id = b.item_id and an.code = qa.attribute_value))
      or (qa.attribute_type = 'laterality' and not exists (select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.laterality = qa.attribute_value))
      or (qa.attribute_type = 'contrast_mode' and not exists (select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.contrast_mode = qa.attribute_value))
    ) as hard_conflict
  from best b
), accepted as (
  select e.*,
    least(1.00::numeric, greatest(e.lexical_score, 0) + case when e.attribute_count = 0 then 0 else e.attribute_matches::numeric / e.attribute_count::numeric * 0.12 end) as final_score
  from enriched e
  where not e.hard_conflict
    and (e.lexical_score >= 0.45 or e.term_source in ('name','alias','disambiguation'))
    and (e.attribute_count = 0 or e.attribute_matches::numeric / e.attribute_count::numeric >= 0.80)
), ranked as (
  select a.*, row_number() over (order by a.final_score desc, a.display_name) as result_rank,
    lead(a.final_score) over (order by a.final_score desc, a.display_name) as next_score,
    exists (select 1 from disambiguation) as has_disambiguation
  from accepted a
)
select
  r.item_id,
  r.display_name,
  r.matched_term,
  r.term_source,
  r.provider_brand_id,
  r.final_score as confidence,
  case when r.has_disambiguation or (r.next_score is not null and r.final_score - r.next_score < 0.15)
       then 'ambiguous' else 'resolved' end as resolution_status,
  case when r.term_source = 'disambiguation' then 'disambiguation'
       when r.lexical_score >= 0.999 then 'exact'
       when r.term_source = 'alias' then 'alias'
       when r.word_score >= r.similarity_score then 'word_fuzzy'
       else 'trigram' end as match_method,
  jsonb_build_object(
    'lexical_score', r.lexical_score,
    'similarity_score', r.similarity_score,
    'word_score', r.word_score,
    'attribute_count', r.attribute_count,
    'attribute_matches', r.attribute_matches,
    'hard_conflict', r.hard_conflict,
    'next_score', r.next_score
  ) as explanation_data
  ,r.result_rank
from ranked r
where r.result_rank <= greatest(1, least(coalesce(p_limit,10),50))
order by r.result_rank;
$$;

create or replace function catalog.search_items(
  p_query text,
  p_domain_code text default 'health_diagnostics',
  p_provider_brand_id uuid default null,
  p_limit integer default 10
)
returns table (
  item_id uuid,
  display_name text,
  matched_term text,
  term_source text,
  provider_brand_id uuid,
  similarity_score real,
  weighted_score numeric
)
language sql
stable
as $$
select r.item_id, r.display_name, r.matched_term, r.term_source,
       r.provider_brand_id, (r.confidence)::real, r.confidence
from catalog.resolve_items(p_query, p_domain_code, p_provider_brand_id, p_limit) r
where r.resolution_status in ('resolved','ambiguous')
order by r.confidence desc, r.display_name
limit greatest(1, least(coalesce(p_limit,10),50));
$$;

revoke all on function catalog.resolve_items(text,text,uuid,integer) from public;
grant execute on function catalog.resolve_items(text,text,uuid,integer) to anon, authenticated, service_role;

commit;
