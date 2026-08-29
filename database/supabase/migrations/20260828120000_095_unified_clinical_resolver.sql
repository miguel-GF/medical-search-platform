-- Use one clinical resolver for both the tabular search API and the
-- explicit resolution API.  Older resolver functions remain available for
-- migration compatibility, but no public path should bypass this adapter.

begin;

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
select r.item_id, r.display_name, r.matched_term, r.term_source,
       r.provider_brand_id, r.confidence, r.resolution_status,
       r.match_method, r.explanation_data, r.result_rank
from catalog.resolve_items_v5(
  p_query,
  p_domain_code,
  p_provider_brand_id,
  greatest(1, least(coalesce(p_limit, 10), 50))
) r;
$$;

-- The public tabular API and the resolver API now share exactly the same
-- candidate set, guards and ranking.
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
from catalog.resolve_items_v6(p_query, p_domain_code, p_provider_brand_id, p_limit) r
where r.resolution_status in ('resolved', 'ambiguous')
order by r.confidence desc, r.display_name
limit greatest(1, least(coalesce(p_limit, 10), 50));
$$;

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
security definer
set search_path = public
as $$
with valid_input as (
  select core.normalized_text(p_query) as normalized_query
  where core.normalized_text(p_query) <> ''
), candidates as materialized (
  select r.*
  from valid_input v
  cross join lateral catalog.resolve_items_v6(
    p_query,
    p_domain_code,
    null,
    greatest(1, least(coalesce(p_limit, 20), 50))
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
      filter (where x.offer_id is not null
        and (x.amount_minor is not null or x.provider_location_id is not null)),
      '[]'::jsonb) as offers
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
      greatest(1, least(coalesce(p_limit, 20), 100))
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
), summary as (
  select count(*)::integer as candidate_count,
         coalesce(bool_or(resolution_status = 'ambiguous'), false) as has_ambiguous
  from payload
), response_status as (
  select case
    when candidate_count = 0 then 'no_match'
    when has_ambiguous or candidate_count > 1 then 'ambiguous'
    else 'resolved'
  end as status
  from summary
)
select jsonb_build_object(
  'query', p_query,
  'normalized_query', coalesce((select normalized_query from valid_input), ''),
  'engine_version', 'clinical-resolver-v6',
  'status', (select status from response_status),
  'candidates', coalesce((
    select jsonb_agg(jsonb_build_object(
      'service_id', p.item_id,
      'display_name', p.display_name,
      'matched_term', p.matched_term,
      'term_source', p.term_source,
      'provider_brand_id', p.provider_brand_id,
      'confidence', p.confidence,
      'resolution_status', p.resolution_status,
      'match_method', p.match_method,
      'explanation', p.explanation_data,
      'offers', p.offers
    ) order by p.result_rank)
    from payload p
  ), '[]'::jsonb)
);
$$;

-- Keep old internal versions for historical migrations, but make the public
-- contract use only the unified implementation.
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
select public.api_resolve_search_v4(
  p_query,
  p_domain_code,
  p_latitude,
  p_longitude,
  p_location_id,
  p_limit
);
$$;

revoke all on function catalog.resolve_items_v6(text,text,uuid,integer) from public, anon, authenticated;
grant execute on function catalog.resolve_items_v6(text,text,uuid,integer) to service_role;
revoke all on function public.api_resolve_search_v4(text,text,double precision,double precision,uuid,integer) from public, anon, authenticated;
grant execute on function public.api_resolve_search_v4(text,text,double precision,double precision,uuid,integer) to service_role;
revoke all on function public.api_resolve_search(text,text,double precision,double precision,uuid,integer) from public;
grant execute on function public.api_resolve_search(text,text,double precision,double precision,uuid,integer) to anon, authenticated, service_role;

commit;
