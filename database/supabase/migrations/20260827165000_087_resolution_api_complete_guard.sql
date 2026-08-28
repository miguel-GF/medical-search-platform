-- Use the complete-token guarded resolver for the public RPC.

begin;

create or replace function public.api_resolve_search_v2(
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
set search_path = public, catalog, health, core, supply, geo, gis, extensions
as $$
with candidates as materialized (
  select r.*
  from catalog.resolve_items_v3(
    p_query,
    p_domain_code,
    null,
    greatest(1, least(coalesce(p_limit,20), 50))
  ) r
), candidate_offers as (
  select c.item_id,
    coalesce(jsonb_agg(jsonb_build_object(
      'offer_id', x.offer_id,
      'provider_brand_id', x.provider_brand_id,
      'provider_name', x.provider_name,
      'provider_location_id', x.provider_location_id,
      'provider_location_name', x.provider_location_name,
      'latitude', x.latitude,
      'longitude', x.longitude,
      'distance_meters', x.distance_meters,
      'source_url', x.source_url,
      'price_type', x.price_type,
      'price_key', x.price_key,
      'amount_minor', x.amount_minor,
      'currency', x.currency,
      'price_last_seen_at', x.price_last_seen_at
    ) order by x.distance_meters nulls last, x.provider_name)
      filter (where x.offer_id is not null), '[]'::jsonb) as offers
  from candidates c
  left join lateral (
    select distinct on (s.offer_id, s.price_type, s.price_key)
      s.offer_id, s.provider_brand_id, s.provider_name,
      s.provider_location_id, s.provider_location_name,
      s.latitude, s.longitude, s.distance_meters, s.source_url,
      s.price_type, s.price_key, s.amount_minor, s.currency,
      s.price_last_seen_at
    from public.api_search(
      c.display_name,
      p_domain_code,
      p_latitude,
      p_longitude,
      p_location_id,
      greatest(1, least(coalesce(p_limit,20), 100))
    ) s
    where s.service_id = c.item_id
    order by s.offer_id, s.price_type, s.price_key,
             s.distance_meters nulls last, s.amount_minor nulls last
  ) x on true
  group by c.item_id
), payload as (
  select c.item_id, c.result_rank, c.display_name, c.matched_term,
         c.term_source, c.provider_brand_id, c.confidence,
         c.resolution_status, c.match_method, c.explanation_data,
         coalesce(o.offers, '[]'::jsonb) as offers
  from candidates c
  left join candidate_offers o on o.item_id = c.item_id
)
select jsonb_build_object(
  'query', p_query,
  'normalized_query', core.normalized_text(p_query),
  'engine_version', 'clinical-resolver-v1',
  'status', case
    when not exists (select 1 from candidates) then 'no_match'
    when (select count(*) from candidates) > 1 then 'ambiguous'
    when exists (select 1 from candidates where resolution_status = 'ambiguous') then 'ambiguous'
    else 'resolved'
  end,
  'candidates', coalesce((
    select jsonb_agg(jsonb_build_object(
      'service_id', p.item_id,
      'display_name', p.display_name,
      'matched_term', p.matched_term,
      'term_source', p.term_source,
      'provider_brand_id', p.provider_brand_id,
      'confidence', p.confidence,
      'resolution_status', case when (select count(*) from candidates) > 1 then 'ambiguous' else p.resolution_status end,
      'match_method', p.match_method,
      'explanation', p.explanation_data,
      'offers', p.offers
    ) order by p.result_rank)
    from payload p
  ), '[]'::jsonb)
);
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
select public.api_resolve_search_v2(p_query, p_domain_code, p_latitude, p_longitude, p_location_id, p_limit);
$$;

revoke all on function public.api_resolve_search_v2(text,text,double precision,double precision,uuid,integer) from public;
grant execute on function public.api_resolve_search_v2(text,text,double precision,double precision,uuid,integer) to anon, authenticated, service_role;
revoke all on function public.api_resolve_search(text,text,double precision,double precision,uuid,integer) from public;
grant execute on function public.api_resolve_search(text,text,double precision,double precision,uuid,integer) to anon, authenticated, service_role;

commit;
