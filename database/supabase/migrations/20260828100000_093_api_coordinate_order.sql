-- Restore latitude/longitude order at the public API boundary.
-- api_search_scoped_v1 historically exposes ST_X in its latitude slot and
-- ST_Y in its longitude slot. Keep that internal compatibility contract, but
-- swap the two values here so every public consumer receives latitude first.

begin;

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
  select s.*
  from public.api_search_scoped_v1(
    p_query,
    p_domain_code,
    p_latitude,
    p_longitude,
    p_location_id,
    greatest(1, least(coalesce(p_limit, 20), 100)) * 3
  ) s
  where core.normalized_text(p_query) <> ''
), scoped as (
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
), ranked as (
  select s.*,
    row_number() over (
      partition by s.service_id, s.provider_brand_id
      order by s.distance_meters nulls last, s.amount_minor nulls last, s.display_name, s.offer_id
    ) as provider_rank
  from scoped s
), prioritized as (
  select r.*,
    case when r.provider_rank = 1 then 0 else 1 end as diversity_bucket
  from ranked r
)
select
  p.service_id,
  p.display_name,
  p.matched_term,
  p.term_source,
  p.confidence,
  p.offer_id,
  p.provider_brand_id,
  p.provider_name,
  p.provider_location_id,
  p.provider_location_name,
  p.longitude as latitude,
  p.latitude as longitude,
  p.distance_meters,
  p.source_url,
  p.price_type,
  p.price_key,
  p.amount_minor,
  p.currency,
  p.price_last_seen_at
from prioritized p
order by p.diversity_bucket, p.confidence desc, p.distance_meters nulls last, p.provider_name, p.display_name
limit greatest(1, least(coalesce(p_limit, 20), 100));
$$;

revoke all on function public.api_search(text, text, double precision, double precision, uuid, integer) from public;
grant execute on function public.api_search(text, text, double precision, double precision, uuid, integer) to anon, authenticated, service_role;

commit;
