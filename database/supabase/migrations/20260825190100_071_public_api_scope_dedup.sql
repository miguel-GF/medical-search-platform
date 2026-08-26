-- Prefer concrete branch rows over a redundant brand fallback in API responses.

begin;

alter function public.api_search(text, text, double precision, double precision, uuid, integer)
  rename to api_search_scoped_v1;

create or replace function public.api_search(
  p_query text,
  p_domain_code text default 'health_diagnostics',
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_location_id uuid default null,
  p_limit integer default 20
)
returns table (
  service_id uuid,
  display_name text,
  matched_term text,
  term_source text,
  confidence numeric,
  offer_id uuid,
  provider_brand_id uuid,
  provider_name text,
  provider_location_id uuid,
  provider_location_name text,
  latitude double precision,
  longitude double precision,
  distance_meters double precision,
  source_url text,
  price_type text,
  price_key text,
  amount_minor bigint,
  currency char(3),
  price_last_seen_at timestamptz
)
language sql
stable
security definer
set search_path = public, catalog, core, supply, geo, gis, extensions
as $$
with rows as materialized (
  select * from public.api_search_scoped_v1(
    p_query, p_domain_code, p_latitude, p_longitude, p_location_id, p_limit * 3
  )
), preferred as (
  select r.*
  from rows r
  where r.provider_location_id is not null
     or not exists (
       select 1 from rows concrete
       where concrete.offer_id = r.offer_id
         and concrete.provider_location_id is not null
         and concrete.price_type is not distinct from r.price_type
         and concrete.price_key is not distinct from r.price_key
     )
)
select *
from preferred
order by confidence desc, distance_meters nulls last, provider_name, display_name
limit greatest(1, least(coalesce(p_limit, 20), 100));
$$;

revoke all on function public.api_search(text, text, double precision, double precision, uuid, integer) from public;
grant execute on function public.api_search(text, text, double precision, double precision, uuid, integer) to anon, authenticated, service_role;

commit;
