-- An approved alias is exact evidence only when the complete normalized query
-- is that alias. Extra unmatched tokens must not be silently discarded.

begin;

create or replace function catalog.resolve_items_v5(
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
select r.item_id, r.display_name, r.matched_term, r.term_source,
       r.provider_brand_id, r.confidence, r.resolution_status,
       r.match_method, r.explanation_data, r.result_rank
from catalog.resolve_items_v4(p_query, p_domain_code, p_provider_brand_id, p_limit) r
where r.match_method not in ('exact','alias')
   or core.normalized_text(r.matched_term) = core.normalized_text(p_query)
   or r.term_source = 'disambiguation';
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
from catalog.resolve_items_v5(p_query, p_domain_code, p_provider_brand_id, p_limit) r
where r.resolution_status in ('resolved','ambiguous')
order by r.confidence desc, r.display_name
limit greatest(1, least(coalesce(p_limit,10),50));
$$;

create or replace function public.api_resolve_search_v3(
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
), candidate_filtered as (
  select payload,
    coalesce((
      select jsonb_agg(c.value order by c.ordinality)
      from jsonb_array_elements(payload->'candidates') with ordinality as c(value, ordinality)
      where c.value->>'match_method' not in ('exact','alias')
         or core.normalized_text(c.value->>'matched_term') = core.normalized_text(p_query)
         or c.value->>'term_source' = 'disambiguation'
    ), '[]'::jsonb) as candidates
  from original
), offers_filtered as (
  select payload, candidates,
    coalesce((
      select jsonb_agg(
        c.value || jsonb_build_object(
          'offers', coalesce((
            select jsonb_agg(o.value order by o.value->>'provider_name', o.value->>'price_type', o.value->>'price_key')
            from jsonb_array_elements(c.value->'offers') as o(value)
            where o.value->>'amount_minor' is not null
               or o.value->>'provider_location_id' is not null
          ), '[]'::jsonb)
        ) order by c.ordinality
      )
      from jsonb_array_elements(candidates) with ordinality as c(value, ordinality)
    ), '[]'::jsonb) as candidates_with_offers
  from candidate_filtered
), normalized as (
  select payload, candidates_with_offers,
    case when jsonb_array_length(candidates_with_offers) = 0 then 'no_match'
         when jsonb_array_length(candidates_with_offers) > 1 then 'ambiguous'
         else 'resolved' end as status
  from offers_filtered
), candidates_fixed as (
  select payload, status,
    case when jsonb_array_length(candidates_with_offers) = 1 then (
      select jsonb_agg(c.value || jsonb_build_object('resolution_status','resolved'))
      from jsonb_array_elements(candidates_with_offers) as c(value)
    ) else candidates_with_offers end as candidates
  from normalized
)
select payload || jsonb_build_object(
  'status', status,
  'candidates', coalesce(candidates, '[]'::jsonb)
)
from candidates_fixed;
$$;

revoke all on function catalog.resolve_items_v5(text,text,uuid,integer) from public, anon, authenticated;
grant execute on function catalog.resolve_items_v5(text,text,uuid,integer) to service_role;
revoke all on function public.api_resolve_search_v3(text,text,double precision,double precision,uuid,integer) from public, anon, authenticated;
grant execute on function public.api_resolve_search_v3(text,text,double precision,double precision,uuid,integer) to service_role;

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
select public.api_resolve_search_v3(p_query, p_domain_code, p_latitude, p_longitude, p_location_id, p_limit);
$$;

revoke all on function public.api_resolve_search(text,text,double precision,double precision,uuid,integer) from public;
grant execute on function public.api_resolve_search(text,text,double precision,double precision,uuid,integer) to anon, authenticated, service_role;

commit;
