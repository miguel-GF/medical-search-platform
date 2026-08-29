-- Resolve an arbitrary list of clinical studies and expose the concrete offers
-- needed by the API package solver.  The SQL layer only resolves terminology
-- and expands provider scopes; set-cover selection remains deterministic code.

begin;

create or replace function public.api_resolve_package(
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
set search_path = public, catalog, core, supply, geo, gis, extensions
as $$
with input_items as materialized (
  select
    x.ordinality::integer as item_index,
    trim(x.value) as input,
    core.normalized_text(trim(x.value)) as normalized_query
  from jsonb_array_elements_text(
    case when jsonb_typeof(coalesce(p_items, '[]'::jsonb)) = 'array'
      then coalesce(p_items, '[]'::jsonb)
      else '[]'::jsonb
    end
  ) with ordinality as x(value, ordinality)
  where trim(x.value) <> ''
), resolved_rows as materialized (
  select
    i.item_index,
    i.input,
    i.normalized_query,
    r.item_id,
    r.display_name,
    r.matched_term,
    r.term_source,
    r.confidence,
    r.resolution_status,
    r.match_method,
    r.explanation_data,
    r.result_rank
  from input_items i
  left join lateral catalog.resolve_items_v6(
    i.input,
    p_domain_code,
    null,
    greatest(1, least(coalesce(p_limit, 10), 50))
  ) r on true
), item_payload as (
  select
    rr.item_index,
    rr.input,
    rr.normalized_query,
    case
      when count(rr.item_id) = 0 then 'no_match'
      when count(rr.item_id) > 1 or bool_or(rr.resolution_status = 'ambiguous') then 'ambiguous'
      else 'resolved'
    end as status,
    case
      when count(rr.item_id) = 0 then 'service_not_found'
      when count(rr.item_id) > 1 or bool_or(rr.resolution_status = 'ambiguous') then 'ambiguous_service'
      else null
    end as reason_code,
    coalesce(jsonb_agg(jsonb_build_object(
      'service_id', rr.item_id,
      'display_name', rr.display_name,
      'matched_term', rr.matched_term,
      'term_source', rr.term_source,
      'confidence', rr.confidence,
      'resolution_status', rr.resolution_status,
      'match_method', rr.match_method,
      'explanation', coalesce(rr.explanation_data, '{}'::jsonb)
    ) order by rr.result_rank, rr.display_name)
      filter (where rr.item_id is not null), '[]'::jsonb) as candidates
  from resolved_rows rr
  group by rr.item_index, rr.input, rr.normalized_query
), resolved_items as (
  select
    rr.item_index,
    (array_agg(rr.item_id order by rr.result_rank))[1] as item_id
  from resolved_rows rr
  group by rr.item_index
  having count(rr.item_id) = 1
     and bool_and(rr.resolution_status = 'resolved')
), expanded_offers as (
  select
    ri.item_index,
    o.catalog_item_id as item_id,
    o.id as offer_id,
    o.provider_brand_id,
    b.name as provider_name,
    o.requires_quote as offer_requires_quote,
    os.id as offer_scope_id,
    os.scope_type,
    case os.scope_type when 'location' then 3 when 'market' then 2 else 1 end::smallint as scope_specificity,
    l.id as provider_location_id,
    l.name as provider_location_name,
    l.coordinates,
    price.price_type,
    price.price_key,
    price.amount_minor,
    price.currency,
    price.last_seen_at as price_last_seen_at,
    coalesce(link.url, link_parent.url) as source_url
  from resolved_items ri
  join supply.offers o
    on o.catalog_item_id = ri.item_id
   and o.status = 'active'
  join core.provider_brands b
    on b.id = o.provider_brand_id
   and b.status = 'active'
  join supply.offer_scopes os
    on os.offer_id = o.id
   and os.status = 'active'
  join lateral (
    select pl.id, pl.name, pl.coordinates
    from core.provider_locations pl
    where pl.status = 'active'
      and (p_location_id is null or pl.id = p_location_id)
      and (
        (os.scope_type = 'location' and pl.id = os.provider_location_id)
        or (os.scope_type = 'market' and exists (
          select 1
          from core.provider_market_locations pml
          where pml.provider_market_id = os.provider_market_id
            and pml.provider_location_id = pl.id
        ))
        or (os.scope_type = 'brand' and pl.provider_brand_id = o.provider_brand_id)
      )
  ) l on true
  left join lateral (
    select rp.price_type, rp.price_key, rp.amount_minor, rp.currency, pv.last_seen_at
    from supply.resolve_prices(o.id, l.id) rp
    left join supply.price_versions pv on pv.id = rp.price_version_id
    order by rp.specificity desc,
      case when rp.price_type = 'regular' then 0 else 1 end,
      rp.amount_minor asc,
      rp.price_key
    limit 1
  ) price on true
  left join lateral (
    select ol.url
    from supply.offer_links ol
    where ol.offer_scope_id = os.id
      and ol.link_type = 'details'
      and ol.status = 'active'
    order by ol.verified_at desc nulls last, ol.created_at desc
    limit 1
  ) link on true
  left join lateral (
    select ol.url
    from supply.offer_links ol
    where ol.offer_scope_id = (
      select parent.id
      from supply.offer_scopes parent
      where parent.offer_id = o.id and parent.scope_type = 'brand' and parent.status = 'active'
      limit 1
    )
      and ol.link_type = 'details'
      and ol.status = 'active'
    order by ol.verified_at desc nulls last, ol.created_at desc
    limit 1
  ) link_parent on true
), ranked_offers as (
  select
    eo.*,
    row_number() over (
      partition by eo.item_index, eo.offer_id, eo.provider_location_id
      order by eo.scope_specificity desc,
        eo.amount_minor nulls last,
        eo.offer_scope_id
    ) as scope_rank
  from expanded_offers eo
), offer_payload as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'item_index', ro.item_index,
    'item_id', ro.item_id,
    'offer_id', ro.offer_id,
    'provider_brand_id', ro.provider_brand_id,
    'provider_name', ro.provider_name,
    'provider_location_id', ro.provider_location_id,
    'provider_location_name', ro.provider_location_name,
    'latitude', case when ro.coordinates is null then null else gis.st_y(ro.coordinates::gis.geometry) end,
    'longitude', case when ro.coordinates is null then null else gis.st_x(ro.coordinates::gis.geometry) end,
    'distance_meters', case
      when ro.coordinates is null or p_latitude is null or p_longitude is null then null
      else gis.st_distance(
        ro.coordinates,
        gis.st_setsrid(gis.st_makepoint(p_longitude, p_latitude), 4326)::gis.geography
      )
    end,
    'source_url', ro.source_url,
    'price_type', ro.price_type,
    'price_key', ro.price_key,
    'amount_minor', ro.amount_minor,
    'currency', ro.currency,
    'price_last_seen_at', ro.price_last_seen_at,
    'requires_quote', (ro.offer_requires_quote or ro.amount_minor is null)
  ) order by ro.item_index, ro.provider_name, ro.provider_location_name, ro.amount_minor nulls last)
    filter (where ro.scope_rank = 1), '[]'::jsonb) as offers
  from ranked_offers ro
)
select jsonb_build_object(
  'engine_version', 'clinical-resolver-v6',
  'items', coalesce((
    select jsonb_agg(jsonb_build_object(
      'index', ip.item_index,
      'input', ip.input,
      'normalized_query', ip.normalized_query,
      'status', ip.status,
      'reason_code', ip.reason_code,
      'candidates', ip.candidates
    ) order by ip.item_index)
    from item_payload ip
  ), '[]'::jsonb),
  'offers', coalesce((select offers from offer_payload), '[]'::jsonb)
);
$$;

revoke all on function public.api_resolve_package(jsonb, text, double precision, double precision, uuid, integer) from public;
grant execute on function public.api_resolve_package(jsonb, text, double precision, double precision, uuid, integer) to anon, authenticated, service_role;

commit;
