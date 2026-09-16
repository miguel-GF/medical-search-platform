-- Keep a small public page useful across providers.  A global price sort can
-- fill the default 20-row page with one large chain and hide smaller verified
-- providers, so reserve the first row for every provider before filling the
-- remaining slots by the existing confidence/distance ordering.

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
  study_url text,
  location_url text,
  booking_url text,
  link_capability text,
  link_handoff jsonb,
  price_type text,
  price_key text,
  amount_minor bigint,
  currency char(3),
  price_last_seen_at timestamptz
)
language sql
stable
parallel safe
security definer
set search_path = public, supply
as $$
with rows as materialized (
  select * from public.api_search_links_legacy_v1(
    p_query, p_domain_code, p_latitude, p_longitude, p_location_id, p_limit * 3
  )
), preferred as (
  select r.*
  from rows r
  where r.provider_location_id is not null
     or not exists (
       select 1
       from supply.offer_scopes concrete
       where concrete.offer_id = r.offer_id
         and concrete.scope_type = 'location'
         and concrete.status = 'active'
     )
), diversified as (
  select r.*,
    row_number() over (
      partition by r.service_id, r.provider_brand_id
      order by r.distance_meters nulls last, r.amount_minor nulls last,
               r.provider_name, r.display_name, r.offer_id
    ) as provider_rank
  from preferred r
)
select
  r.service_id,
  r.display_name,
  r.matched_term,
  r.term_source,
  r.confidence,
  r.offer_id,
  r.provider_brand_id,
  r.provider_name,
  r.provider_location_id,
  r.provider_location_name,
  r.latitude,
  r.longitude,
  r.distance_meters,
  r.source_url,
  lm.study_url,
  lm.location_url,
  lm.booking_url,
  lm.link_capability,
  lm.handoff_data,
  r.price_type,
  r.price_key,
  r.amount_minor,
  r.currency,
  r.price_last_seen_at
from diversified r
left join lateral supply.resolve_offer_link_metadata(r.offer_id, r.provider_location_id) lm on true
order by case when r.provider_rank = 1 then 0 else 1 end,
         r.confidence desc, r.distance_meters nulls last,
         r.provider_name, r.display_name
limit greatest(1, least(coalesce(p_limit, 20), 100));
$$;

revoke all on function public.api_search(text, text, double precision, double precision, uuid, integer) from public, anon, authenticated;
grant execute on function public.api_search(text, text, double precision, double precision, uuid, integer) to service_role;

commit;
