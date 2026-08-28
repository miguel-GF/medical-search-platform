-- Do not expose a second, price-less brand-scope row when a market/location
-- offer already has a commercial price. The resolver still returns offers with
-- no price when they have a concrete provider location.

begin;

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
), filtered as (
  select payload,
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
      from jsonb_array_elements(payload->'candidates') with ordinality as c(value, ordinality)
    ), '[]'::jsonb) as candidates
  from original
), candidates_fixed as (
  select payload, candidates,
    case when jsonb_array_length(candidates) = 0 then 'no_match'
         when jsonb_array_length(candidates) > 1 then 'ambiguous'
         else 'resolved' end as status,
    case when jsonb_array_length(candidates) = 1 then (
      select jsonb_agg(c.value || jsonb_build_object('resolution_status','resolved'))
      from jsonb_array_elements(candidates) as c(value)
    ) else candidates end as fixed_candidates
  from filtered
)
select payload
  || jsonb_build_object('status', status, 'candidates', coalesce(fixed_candidates, '[]'::jsonb))
from candidates_fixed;
$$;

revoke all on function public.api_resolve_search(text,text,double precision,double precision,uuid,integer) from public;
grant execute on function public.api_resolve_search(text,text,double precision,double precision,uuid,integer) to anon, authenticated, service_role;

commit;
