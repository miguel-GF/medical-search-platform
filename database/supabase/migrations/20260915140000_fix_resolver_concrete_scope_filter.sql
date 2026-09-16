-- A single offer can intentionally have several active concrete location
-- scopes (for example one Salud Digna study across eight branches).  The
-- resolver must suppress only a broad fallback row, never a valid concrete
-- row merely because another location exists for the same offer.

begin;

create or replace function public.api_resolve_search_v4(
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
parallel safe
security definer
set search_path = public, supply
as $$
with base as (
  select public.api_resolve_search_v4_links_legacy(
    p_query, p_domain_code, p_latitude, p_longitude, p_location_id, p_limit
  ) as payload
), candidates as (
  select c.ordinality,
    c.value || jsonb_build_object(
      'offers', coalesce((
        select jsonb_agg(
          o.value || jsonb_build_object(
            'study_url', lm.study_url,
            'location_url', lm.location_url,
            'booking_url', lm.booking_url,
            'link_capability', lm.link_capability,
            'link_handoff', lm.handoff_data
          ) order by o.ordinality
        )
        from jsonb_array_elements(
          case when jsonb_typeof(c.value->'offers') = 'array' then c.value->'offers' else '[]'::jsonb end
        ) with ordinality o(value, ordinality)
        left join lateral supply.resolve_offer_link_metadata(
          (o.value->>'offer_id')::uuid,
          nullif(o.value->>'provider_location_id', '')::uuid
        ) lm on true
        where nullif(o.value->>'provider_location_id', '') is not null
           or not exists (
             select 1
             from supply.offer_scopes concrete
             where concrete.offer_id = (o.value->>'offer_id')::uuid
               and concrete.scope_type = 'location'
               and concrete.status = 'active'
           )
      ), '[]'::jsonb)
    ) as value
  from base b
  cross join jsonb_array_elements(
    case when jsonb_typeof(b.payload->'candidates') = 'array' then b.payload->'candidates' else '[]'::jsonb end
  ) with ordinality c(value, ordinality)
)
select b.payload || jsonb_build_object(
  'candidates', coalesce((select jsonb_agg(c.value order by c.ordinality) from candidates c), '[]'::jsonb)
)
from base b;
$$;

create or replace function public.api_resolve_package_internal(
  p_items jsonb,
  p_domain_code text default 'health_diagnostics',
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_location_id uuid default null,
  p_limit integer default 10
)
returns jsonb
language sql
stable
parallel safe
security definer
set search_path = public, supply
as $$
with base as (
  select public.api_resolve_package_links_legacy(
    p_items, p_domain_code, p_latitude, p_longitude, p_location_id, p_limit
  ) as payload
), offers as (
  select o.ordinality,
    o.value || jsonb_build_object(
      'study_url', lm.study_url,
      'location_url', lm.location_url,
      'booking_url', lm.booking_url,
      'link_capability', lm.link_capability,
      'link_handoff', lm.handoff_data
    ) as value
  from base b
  cross join jsonb_array_elements(
    case when jsonb_typeof(b.payload->'offers') = 'array' then b.payload->'offers' else '[]'::jsonb end
  ) with ordinality o(value, ordinality)
  left join lateral supply.resolve_offer_link_metadata(
    (o.value->>'offer_id')::uuid,
    nullif(o.value->>'provider_location_id', '')::uuid
  ) lm on true
  where nullif(o.value->>'provider_location_id', '') is not null
     or not exists (
       select 1
       from supply.offer_scopes concrete
       where concrete.offer_id = (o.value->>'offer_id')::uuid
         and concrete.scope_type = 'location'
         and concrete.status = 'active'
     )
)
select b.payload || jsonb_build_object(
  'offers', coalesce((select jsonb_agg(o.value order by o.ordinality) from offers o), '[]'::jsonb)
)
from base b;
$$;

revoke all on function public.api_resolve_search_v4(text, text, double precision, double precision, uuid, integer) from public, anon, authenticated;
grant execute on function public.api_resolve_search_v4(text, text, double precision, double precision, uuid, integer) to service_role;
revoke all on function public.api_resolve_package_internal(jsonb, text, double precision, double precision, uuid, integer) from public, anon, authenticated;
grant execute on function public.api_resolve_package_internal(jsonb, text, double precision, double precision, uuid, integer) to service_role;

commit;
