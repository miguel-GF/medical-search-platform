-- Normalize the final status after unsafe fuzzy candidates are removed and
-- recognize the common handwritten/OCR typo used in the acceptance cases.

begin;

insert into catalog.disambiguation_terms(term, normalized_term, source_note)
values ('Perfil toroideo','perfil toroideo','OCR/spelling variant of perfil tiroideo; composition remains provider-specific.')
on conflict (locale, normalized_term) do update set term = excluded.term, source_note = excluded.source_note;

insert into catalog.disambiguation_candidates(term_id, item_id, priority, reason)
select t.id, x.item_id, x.priority, x.reason
from catalog.disambiguation_terms t
join (values
  ('00000000-0000-0000-0000-000000001107'::uuid,1,'Perfil básico; confirmar componentes.'),
  ('00000000-0000-0000-0000-000000001108'::uuid,2,'Perfil ampliado; confirmar componentes.')
) x(item_id,priority,reason) on true
where t.normalized_term = 'perfil toroideo'
on conflict (term_id, item_id) do update set priority = excluded.priority, reason = excluded.reason;

create or replace function catalog.resolve_items_v4(
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
with rows as materialized (
  select * from catalog.resolve_items_v3(p_query, p_domain_code, p_provider_brand_id, p_limit)
), ranked as (
  select rows.*, count(*) over () as safe_count
  from rows
)
select r.item_id, r.display_name, r.matched_term, r.term_source,
       r.provider_brand_id, r.confidence,
       case when r.safe_count > 1 or r.term_source = 'disambiguation' then 'ambiguous' else 'resolved' end,
       r.match_method,
       r.explanation_data,
       r.result_rank
from ranked r
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
       r.provider_brand_id, r.confidence::real, r.confidence
from catalog.resolve_items_v4(p_query, p_domain_code, p_provider_brand_id, p_limit) r
where r.resolution_status in ('resolved','ambiguous')
order by r.confidence desc, r.display_name
limit greatest(1, least(coalesce(p_limit,10),50));
$$;

create or replace function public.api_resolve_search(
  p_query text,
  p_domain_code text default 'health_diagnostics',
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_location_id uuid default null,
  p_limit integer default 20
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
with original as (
  select public.api_resolve_search_v2(p_query, p_domain_code, p_latitude, p_longitude, p_location_id, p_limit) as payload
), normalized as (
  select payload,
    coalesce(payload->'candidates', '[]'::jsonb) as candidates
  from original
), candidates_fixed as (
  select payload, candidates,
    case when jsonb_array_length(candidates) = 0 then 'no_match'
         when jsonb_array_length(candidates) > 1 then 'ambiguous'
         else 'resolved' end as status,
    case when jsonb_array_length(candidates) = 1 then (
      select jsonb_agg(c.value || jsonb_build_object('resolution_status','resolved')) from jsonb_array_elements(candidates) as c(value)
    ) else candidates end as fixed_candidates
  from normalized
)
select payload
  || jsonb_build_object('status', status, 'candidates', coalesce(fixed_candidates, '[]'::jsonb))
from candidates_fixed;
$$;

revoke all on function catalog.resolve_items_v4(text,text,uuid,integer) from public;
grant execute on function catalog.resolve_items_v4(text,text,uuid,integer) to anon, authenticated, service_role;
revoke all on function public.api_resolve_search(text,text,double precision,double precision,uuid,integer) from public;
grant execute on function public.api_resolve_search(text,text,double precision,double precision,uuid,integer) to anon, authenticated, service_role;

commit;
