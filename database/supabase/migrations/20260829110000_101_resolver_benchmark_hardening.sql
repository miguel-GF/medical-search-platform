-- Resolver hardening for the reviewed benchmark corpus.
--
-- These aliases are conservative lexical variants of an already reviewed
-- canonical concept. They do not broaden a panel, change a specimen, or
-- infer a provider capability. Broad/panel terms remain disambiguated.

begin;

insert into catalog.item_aliases(
  item_id, alias, normalized_alias, alias_type, confidence, status,
  source_note, approved_at
)
values
  -- Biometría hemática / CBC panel.
  ('00000000-0000-0000-0000-000000001103','Biometría hemática completa','biometria hematica completa','synonym',1.0000,'approved','Resolver benchmark v1: conservative synonym for the reviewed CBC panel.',now()),
  ('00000000-0000-0000-0000-000000001103','Hemograma completo','hemograma completo','synonym',1.0000,'approved','Resolver benchmark v1: conservative synonym for the reviewed CBC panel.',now()),
  ('00000000-0000-0000-0000-000000001103','CBC','cbc','abbreviation',1.0000,'approved','Resolver benchmark v1: standard abbreviation for the reviewed CBC panel.',now()),
  ('00000000-0000-0000-0000-000000001103','Complete blood count','complete blood count','synonym',1.0000,'approved','Resolver benchmark v1: English synonym for the reviewed CBC panel.',now()),
  ('00000000-0000-0000-0000-000000001103','Conteo sanguíneo completo','conteo sanguineo completo','synonym',1.0000,'approved','Resolver benchmark v1: conservative Spanish synonym for the reviewed CBC panel.',now()),
  ('00000000-0000-0000-0000-000000001103','Biometría hemática automatizada','biometria hematica automatizada','synonym',1.0000,'approved','Resolver benchmark v1: label consistent with the reviewed automated CBC panel.',now()),
  -- Complete urinalysis panel.
  ('00000000-0000-0000-0000-000000001104','Análisis general de orina','analisis general de orina','synonym',1.0000,'approved','Resolver benchmark v1: conservative synonym for the reviewed complete urinalysis panel.',now()),
  ('00000000-0000-0000-0000-000000001104','Análisis completo de orina','analisis completo de orina','synonym',1.0000,'approved','Resolver benchmark v1: conservative synonym for the reviewed complete urinalysis panel.',now()),
  ('00000000-0000-0000-0000-000000001104','Examen de orina','examen de orina','synonym',1.0000,'approved','Resolver benchmark v1: common shorthand for the reviewed urinalysis panel.',now()),
  ('00000000-0000-0000-0000-000000001104','Examen de orina completo','examen de orina completo','synonym',1.0000,'approved','Resolver benchmark v1: conservative synonym for the reviewed complete urinalysis panel.',now()),
  ('00000000-0000-0000-0000-000000001104','Urianálisis','urianalisis','synonym',1.0000,'approved','Resolver benchmark v1: Spanish synonym for the reviewed complete urinalysis panel.',now()),
  ('00000000-0000-0000-0000-000000001104','Urinalysis','urinalysis','synonym',1.0000,'approved','Resolver benchmark v1: English synonym for the reviewed complete urinalysis panel.',now()),
  ('00000000-0000-0000-0000-000000001104','EGO completo','ego completo','abbreviation',1.0000,'approved','Resolver benchmark v1: explicit complete-panel abbreviation.',now()),
  ('00000000-0000-0000-0000-000000001104','Orina general','orina general','colloquial',0.9800,'approved','Resolver benchmark v1: common local wording for complete urinalysis; no panel variant inferred.',now()),
  -- LOINC 2345-7: serum/plasma glucose only.
  ('00000000-0000-0000-0000-000000001109','Glucosa sérica','glucosa serica','synonym',1.0000,'approved','Resolver benchmark v1: synonym constrained to the reviewed serum/plasma glucose definition.',now()),
  ('00000000-0000-0000-0000-000000001109','Glucosa en suero','glucosa en suero','synonym',1.0000,'approved','Resolver benchmark v1: synonym constrained to the reviewed serum/plasma glucose definition.',now()),
  ('00000000-0000-0000-0000-000000001109','Glucosa plasmática','glucosa plasmatica','synonym',1.0000,'approved','Resolver benchmark v1: synonym constrained to the reviewed serum/plasma glucose definition.',now()),
  ('00000000-0000-0000-0000-000000001109','Glucosa en plasma','glucosa en plasma','synonym',1.0000,'approved','Resolver benchmark v1: synonym constrained to the reviewed serum/plasma glucose definition.',now()),
  ('00000000-0000-0000-0000-000000001109','Glucose','glucose','synonym',1.0000,'approved','Resolver benchmark v1: English synonym for the reviewed serum/plasma glucose definition.',now()),
  -- LOINC 2160-0: serum/plasma creatinine only.
  ('00000000-0000-0000-0000-000000001110','Creatinina sérica','creatinina serica','synonym',1.0000,'approved','Resolver benchmark v1: synonym constrained to the reviewed serum/plasma creatinine definition.',now()),
  ('00000000-0000-0000-0000-000000001110','Creatinina en suero','creatinina en suero','synonym',1.0000,'approved','Resolver benchmark v1: synonym constrained to the reviewed serum/plasma creatinine definition.',now()),
  ('00000000-0000-0000-0000-000000001110','Creatinina plasmática','creatinina plasmatica','synonym',1.0000,'approved','Resolver benchmark v1: synonym constrained to the reviewed serum/plasma creatinine definition.',now()),
  ('00000000-0000-0000-0000-000000001110','Creatinina en plasma','creatinina en plasma','synonym',1.0000,'approved','Resolver benchmark v1: synonym constrained to the reviewed serum/plasma creatinine definition.',now()),
  ('00000000-0000-0000-0000-000000001110','Creatinine','creatinine','synonym',1.0000,'approved','Resolver benchmark v1: English synonym for the reviewed serum/plasma creatinine definition.',now()),
  -- LOINC 3016-3: serum/plasma thyrotropin.
  ('00000000-0000-0000-0000-000000001111','Hormona estimulante de tiroides','hormona estimulante de tiroides','synonym',1.0000,'approved','Resolver benchmark v1: synonym for the reviewed thyrotropin definition.',now()),
  ('00000000-0000-0000-0000-000000001111','Tirotropina','tirotropina','synonym',1.0000,'approved','Resolver benchmark v1: Spanish synonym for the reviewed thyrotropin definition.',now()),
  ('00000000-0000-0000-0000-000000001111','Thyrotropin','thyrotropin','synonym',1.0000,'approved','Resolver benchmark v1: English synonym for the reviewed thyrotropin definition.',now()),
  ('00000000-0000-0000-0000-000000001111','Thyroid stimulating hormone','thyroid stimulating hormone','synonym',1.0000,'approved','Resolver benchmark v1: English synonym for the reviewed thyrotropin definition.',now()),
  ('00000000-0000-0000-0000-000000001111','TSH sérica','tsh serica','synonym',1.0000,'approved','Resolver benchmark v1: wording constrained to the reviewed serum/plasma thyrotropin definition.',now()),
  -- LOINC 3024-7: free thyroxine in serum/plasma.
  ('00000000-0000-0000-0000-000000001112','Tiroxina libre','tiroxina libre','synonym',1.0000,'approved','Resolver benchmark v1: Spanish synonym for the reviewed free T4 definition.',now()),
  ('00000000-0000-0000-0000-000000001112','T4L','t4l','abbreviation',1.0000,'approved','Resolver benchmark v1: standard abbreviation for the reviewed free T4 definition.',now()),
  ('00000000-0000-0000-0000-000000001112','FT4','ft4','abbreviation',1.0000,'approved','Resolver benchmark v1: standard abbreviation for the reviewed free T4 definition.',now()),
  ('00000000-0000-0000-0000-000000001112','Thyroxine free','thyroxine free','synonym',1.0000,'approved','Resolver benchmark v1: English synonym for the reviewed free T4 definition.',now()),
  ('00000000-0000-0000-0000-000000001112','T4 libre sérica','t4 libre serica','synonym',1.0000,'approved','Resolver benchmark v1: wording constrained to the reviewed serum/plasma free T4 definition.',now()),
  ('00000000-0000-0000-0000-000000001112','T4 libre en suero','t4 libre en suero','synonym',1.0000,'approved','Resolver benchmark v1: wording constrained to the reviewed serum/plasma free T4 definition.',now()),
  -- LOINC 3053-6: total-like T3 in serum/plasma.
  ('00000000-0000-0000-0000-000000001113','Triyodotironina','triyodotironina','synonym',1.0000,'approved','Resolver benchmark v1: Spanish synonym for the reviewed total T3 definition.',now()),
  ('00000000-0000-0000-0000-000000001113','Triiodotironina','triiodotironina','synonym',1.0000,'approved','Resolver benchmark v1: alternate Spanish spelling for the reviewed total T3 definition.',now()),
  ('00000000-0000-0000-0000-000000001113','T3 total','t3 total','synonym',1.0000,'approved','Resolver benchmark v1: explicit total-T3 wording.',now()),
  ('00000000-0000-0000-0000-000000001113','Triyodotironina total','triyodotironina total','synonym',1.0000,'approved','Resolver benchmark v1: explicit total-T3 wording.',now()),
  ('00000000-0000-0000-0000-000000001113','Triiodothyronine','triiodothyronine','synonym',1.0000,'approved','Resolver benchmark v1: English synonym for the reviewed total T3 definition.',now()),
  ('00000000-0000-0000-0000-000000001113','T3 sérica','t3 serica','synonym',1.0000,'approved','Resolver benchmark v1: wording constrained to the reviewed serum/plasma T3 definition.',now()),
  -- EMG with anatomy retained; no generic EMG alias is published.
  ('00000000-0000-0000-0000-000000001101','EMG de miembros inferiores','emg de miembros inferiores','abbreviation',1.0000,'approved','Resolver benchmark v1: EMG abbreviation retains lower-extremity anatomy.',now()),
  ('00000000-0000-0000-0000-000000001101','EMG miembros inferiores','emg miembros inferiores','abbreviation',1.0000,'approved','Resolver benchmark v1: EMG abbreviation retains lower-extremity anatomy.',now()),
  ('00000000-0000-0000-0000-000000001101','Electromiografía de piernas','electromiografia de piernas','synonym',1.0000,'approved','Resolver benchmark v1: colloquial anatomy synonym retains lower extremity.',now()),
  ('00000000-0000-0000-0000-000000001101','EMG de piernas','emg de piernas','abbreviation',1.0000,'approved','Resolver benchmark v1: EMG abbreviation retains lower-extremity anatomy.',now()),
  ('00000000-0000-0000-0000-000000001102','EMG de miembros superiores','emg de miembros superiores','abbreviation',1.0000,'approved','Resolver benchmark v1: EMG abbreviation retains upper-extremity anatomy.',now()),
  ('00000000-0000-0000-0000-000000001102','EMG miembros superiores','emg miembros superiores','abbreviation',1.0000,'approved','Resolver benchmark v1: EMG abbreviation retains upper-extremity anatomy.',now()),
  ('00000000-0000-0000-0000-000000001102','Electromiografía de brazos','electromiografia de brazos','synonym',1.0000,'approved','Resolver benchmark v1: colloquial anatomy synonym retains upper extremity.',now()),
  ('00000000-0000-0000-0000-000000001102','EMG de brazos','emg de brazos','abbreviation',1.0000,'approved','Resolver benchmark v1: EMG abbreviation retains upper-extremity anatomy.',now()),
  -- Imaging aliases preserve laterality/modality/body when present.
  ('a1f81444-4b20-5d82-bdf6-b48c27245fa0','Ecografía abdomen completo','ecografia abdomen completo','synonym',1.0000,'approved','Resolver benchmark v1: modality synonym with complete-abdomen scope preserved.',now()),
  ('a1f81444-4b20-5d82-bdf6-b48c27245fa0','Ecografía abdominal completa','ecografia abdominal completa','synonym',1.0000,'approved','Resolver benchmark v1: modality synonym with complete-abdomen scope preserved.',now()),
  ('82d84811-2542-5f8d-8c2c-01186700c4cb','Ecografía obstétrica','ecografia obstetrica','synonym',1.0000,'approved','Resolver benchmark v1: modality synonym with obstetric scope preserved.',now()),
  ('5e21aef5-5328-5ffc-af37-aef84fb1d6a7','Mamografía bilateral','mamografia bilateral','synonym',1.0000,'approved','Resolver benchmark v1: synonym preserves bilateral mammography scope.',now()),
  ('81aa9f9f-737b-537d-9c18-2b023e3e1139','Mamografía unilateral','mamografia unilateral','synonym',1.0000,'approved','Resolver benchmark v1: synonym preserves unilateral mammography scope.',now()),
  ('5e21aef5-5328-5ffc-af37-aef84fb1d6a7','Mastografía de ambas mamas','mastografia de ambas mamas','synonym',1.0000,'approved','Resolver benchmark v1: wording preserves bilateral mammography scope.',now()),
  ('81aa9f9f-737b-537d-9c18-2b023e3e1139','Mastografía de una mama','mastografia de una mama','synonym',1.0000,'approved','Resolver benchmark v1: wording preserves unilateral mammography scope.',now()),
  ('c9d9a832-8146-5831-94f5-ec653dea2126','ECG en reposo','ecg en reposo','abbreviation',1.0000,'approved','Resolver benchmark v1: abbreviation preserves resting ECG modality.',now()),
  ('c9d9a832-8146-5831-94f5-ec653dea2126','EKG en reposo','ekg en reposo','abbreviation',1.0000,'approved','Resolver benchmark v1: abbreviation preserves resting ECG modality.',now()),
  ('c9d9a832-8146-5831-94f5-ec653dea2126','Electrocardiograma de reposo','electrocardiograma de reposo','synonym',1.0000,'approved','Resolver benchmark v1: synonym preserves resting ECG modality.',now()),
  ('2ae7ac0c-4e14-5aec-96bb-af81d5099e8a','TAC abdomen completo simple','tac abdomen completo simple','abbreviation',1.0000,'approved','Resolver benchmark v1: abbreviation preserves simple complete-abdomen CT scope.',now()),
  ('ed7e83db-f394-5171-ae4d-ca347b648028','TAC abdomen completo con contraste','tac abdomen completo con contraste','abbreviation',1.0000,'approved','Resolver benchmark v1: abbreviation preserves contrast-enhanced complete-abdomen CT scope.',now())
on conflict do nothing;

-- Exact lexical evidence must dominate nearby fuzzy variants.  This prevents
-- an exact query such as "electrocardiograma en reposo" from being marked
-- ambiguous solely because exercise/pediatric variants are lexically close.
create or replace function catalog.resolve_items_v6(
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
with identifier_candidates as materialized (
  select
    i.id as item_id,
    coalesce((
      select n.name
      from catalog.item_names n
      where n.item_id = i.id and n.is_primary
      order by n.created_at desc
      limit 1
    ), i.id::text) as display_name,
    ii.code as matched_term,
    'loinc'::text as term_source,
    null::uuid as provider_brand_id,
    1.0000::numeric as confidence,
    ii.code,
    ii.version,
    ii.mapping_type,
    row_number() over (
      partition by i.id
      order by ii.created_at desc, ii.version desc, ii.id
    ) as item_version_rank
  from catalog.item_identifiers ii
  join catalog.items i on i.id = ii.item_id
  join catalog.domains d on d.id = i.domain_id
  where lower(trim(ii.system)) = 'http://loinc.org'
    and lower(trim(ii.code)) = lower(trim(coalesce(p_query, '')))
    and ii.mapping_type = 'exact'
    and ii.status = 'active'
    and ii.verified = true
    and ii.approved_at is not null
    and i.status = 'active'
    and d.code = p_domain_code
), identifier_matches as materialized (
  select
    c.item_id,
    c.display_name,
    c.matched_term,
    c.term_source,
    c.provider_brand_id,
    c.confidence,
    c.code,
    c.version,
    c.mapping_type,
    count(*) over () as candidate_count,
    row_number() over (order by c.version desc, c.item_id) as result_rank
  from identifier_candidates c
  where c.item_version_rank = 1
), fallback_raw as materialized (
  select r.*
  from catalog.resolve_items_v5(
    p_query,
    p_domain_code,
    p_provider_brand_id,
    greatest(1, least(coalesce(p_limit, 10), 50))
  ) r
), exact_items as materialized (
  select distinct item_id
  from fallback_raw
  where match_method = 'exact'
), fallback_filtered as materialized (
  select r.*
  from fallback_raw r
  where not exists (select 1 from exact_items)
     or r.item_id in (select e.item_id from exact_items e)
), fallback_ranked as (
  select
    f.*,
    count(*) over () as filtered_count,
    count(*) filter (where f.match_method = 'exact') over () as filtered_exact_count,
    row_number() over (order by f.confidence desc, f.display_name) as filtered_rank,
    lead(f.confidence) over (order by f.confidence desc, f.display_name) as next_filtered_confidence
  from fallback_filtered f
)
select
  m.item_id,
  m.display_name,
  m.matched_term,
  m.term_source,
  m.provider_brand_id,
  m.confidence,
  case when m.candidate_count > 1 then 'ambiguous' else 'resolved' end,
  'loinc_exact'::text,
  jsonb_build_object(
    'terminology', 'LOINC',
    'code', m.code,
    'version', m.version,
    'mapping_type', m.mapping_type
  ),
  m.result_rank
from identifier_matches m
union all
select
  f.item_id,
  f.display_name,
  f.matched_term,
  f.term_source,
  f.provider_brand_id,
  f.confidence,
  case
    when f.filtered_exact_count > 1 then 'ambiguous'
    when f.filtered_exact_count = 1 then 'resolved'
    else f.resolution_status
  end,
  f.match_method,
  f.explanation_data || jsonb_build_object(
    'exact_dominance', f.filtered_exact_count = 1,
    'candidate_count_after_exact_filter', f.filtered_count
  ),
  f.filtered_rank
from fallback_ranked f
where not exists (select 1 from identifier_matches)
  and f.filtered_rank <= greatest(1, least(coalesce(p_limit, 10), 50))
order by result_rank
limit greatest(1, least(coalesce(p_limit, 10), 50));
$$;

revoke all on function catalog.resolve_items_v6(text,text,uuid,integer) from public, anon, authenticated;
grant execute on function catalog.resolve_items_v6(text,text,uuid,integer) to service_role;

commit;
