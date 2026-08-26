-- Safe public RPCs for the Search API and internal Admin API.
-- Internal schemas remain unexposed; these functions return only approved data.

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
with matches as materialized (
  select *
  from catalog.search_items(
    p_query,
    p_domain_code,
    null,
    greatest(1, least(coalesce(p_limit, 20), 100))
  )
), offer_rows as (
  select
    m.item_id,
    m.display_name,
    m.matched_term,
    m.term_source,
    m.weighted_score,
    o.id as offer_id,
    o.provider_brand_id,
    b.name as provider_name,
    os.id as offer_scope_id,
    os.scope_type,
    os.provider_market_id,
    os.provider_location_id,
    pv.price_type,
    pv.price_key,
    pv.amount_minor,
    pv.currency,
    pv.last_seen_at,
    ol.url as source_url
  from matches m
  join supply.offers o on o.catalog_item_id = m.item_id and o.status = 'active'
  join core.provider_brands b on b.id = o.provider_brand_id and b.status = 'active'
  join supply.offer_scopes os on os.offer_id = o.id and os.status = 'active'
  left join supply.current_price_versions pv on pv.offer_scope_id = os.id
  left join lateral (
    select l.url
    from supply.offer_links l
    where l.offer_scope_id = os.id and l.link_type = 'details' and l.status = 'active'
    order by l.verified_at desc nulls last, l.created_at desc
    limit 1
  ) ol on true
  where (
    p_location_id is null
    or os.scope_type = 'brand'
    or (os.scope_type = 'location' and os.provider_location_id = p_location_id)
    or (os.scope_type = 'market' and exists (
      select 1 from core.provider_market_locations pml
      where pml.provider_market_id = os.provider_market_id
        and pml.provider_location_id = p_location_id
    ))
  )
), expanded as (
  select
    r.*,
    l.id as location_id,
    l.name as location_name,
    l.coordinates,
    case
      when r.scope_type = 'location' then 3
      when r.scope_type = 'market' then 2
      else 1
    end as scope_specificity
  from offer_rows r
  left join lateral (
    select pl.id, pl.name, pl.coordinates
    from core.provider_locations pl
    where (
      r.scope_type = 'location' and pl.id = r.provider_location_id
    ) or (
      r.scope_type = 'market'
      and exists (
        select 1 from core.provider_market_locations pml
        where pml.provider_market_id = r.provider_market_id
          and pml.provider_location_id = pl.id
      )
    ) or (
      r.scope_type = 'brand' and p_location_id is not null and pl.provider_brand_id = r.provider_brand_id
      and pl.id = p_location_id
    )
  ) pl on true
  left join core.provider_locations l on l.id = pl.id
)
select
  e.item_id,
  e.display_name,
  e.matched_term,
  e.term_source,
  e.weighted_score,
  e.offer_id,
  e.provider_brand_id,
  e.provider_name,
  e.location_id,
  e.location_name,
  case when e.coordinates is null then null else gis.st_x(e.coordinates::gis.geometry) end,
  case when e.coordinates is null then null else gis.st_y(e.coordinates::gis.geometry) end,
  case
    when e.coordinates is null or p_latitude is null or p_longitude is null then null
    else gis.st_distance(
      e.coordinates,
      gis.st_setsrid(gis.st_makepoint(p_longitude, p_latitude), 4326)::gis.geography
    )
  end,
  e.source_url,
  e.price_type,
  e.price_key,
  e.amount_minor,
  e.currency,
  e.last_seen_at
from expanded e
order by
  e.weighted_score desc,
  case when e.coordinates is null or p_latitude is null or p_longitude is null then 1 else 0 end,
  case
    when e.coordinates is null or p_latitude is null or p_longitude is null then null
    else gis.st_distance(
      e.coordinates,
      gis.st_setsrid(gis.st_makepoint(p_longitude, p_latitude), 4326)::gis.geography
    )
  end,
  e.provider_name,
  e.display_name
limit greatest(1, least(coalesce(p_limit, 20), 100));
$$;

create or replace function public.api_admin_dashboard()
returns jsonb
language sql
stable
security definer
set search_path = public, ingest, catalog, supply, core
as $$
select jsonb_build_object(
  'sources', (select count(*) from ingest.sources where status = 'active'),
  'crawl_runs', (select count(*) from ingest.crawl_runs),
  'failed_or_quarantined_runs', (select count(*) from ingest.crawl_runs where status in ('failed','quarantined','partial')),
  'normalization_pending', (select count(*) from ingest.normalization_runs where status in ('pending','ambiguous','no_match')),
  'open_quality_issues', (select count(*) from ingest.data_quality_issues where status = 'open'),
  'active_catalog_items', (select count(*) from catalog.items where status = 'active'),
  'active_offers', (select count(*) from supply.offers where status = 'active'),
  'recent_runs', coalesce((
    select jsonb_agg(to_jsonb(r) order by r.started_at desc)
    from (
      select cr.id, s.name as source_name, cr.status, cr.records_received, cr.records_valid,
             cr.records_rejected, cr.records_published, cr.started_at, cr.finished_at
      from ingest.crawl_runs cr
      join ingest.source_endpoints se on se.id = cr.source_endpoint_id
      join ingest.sources s on s.id = se.source_id
      order by cr.started_at desc
      limit 20
    ) r
  ), '[]'::jsonb)
);
$$;

create or replace function public.api_admin_normalization_queue(
  p_status text default null,
  p_limit integer default 50
)
returns table (
  normalization_run_id uuid,
  raw_text text,
  normalized_input text,
  provider_brand_id uuid,
  provider_brand_name text,
  status text,
  engine_version text,
  created_at timestamptz,
  candidate_count bigint,
  decision_type text,
  decision_reason text
)
language sql
stable
security definer
set search_path = public, ingest, core
as $$
select
  nr.id,
  nr.raw_text,
  nr.normalized_input,
  nr.provider_brand_id,
  b.name,
  nr.status,
  nr.engine_version,
  nr.created_at,
  (select count(*) from ingest.normalization_candidates nc where nc.normalization_run_id = nr.id),
  d.decision_type,
  d.reason
from ingest.normalization_runs nr
left join core.provider_brands b on b.id = nr.provider_brand_id
left join lateral (
  select nd.decision_type, nd.reason
  from ingest.normalization_decisions nd
  where nd.normalization_run_id = nr.id
  order by nd.decided_at desc
  limit 1
) d on true
where p_status is null or nr.status = p_status
order by nr.created_at desc
limit greatest(1, least(coalesce(p_limit, 50), 200));
$$;

create or replace function public.api_admin_raw_records(p_limit integer default 50)
returns table (
  raw_record_id uuid,
  source_name text,
  record_type text,
  external_record_id text,
  payload jsonb,
  parse_status text,
  observed_at timestamptz,
  crawl_run_id uuid
)
language sql
stable
security definer
set search_path = public, ingest
as $$
select rr.id, s.name, rr.record_type, rr.external_record_id, rr.payload,
       rr.parse_status, rr.observed_at, rr.crawl_run_id
from ingest.raw_records rr
join ingest.sources s on s.id = rr.source_id
order by rr.observed_at desc
limit greatest(1, least(coalesce(p_limit, 50), 200));
$$;

create or replace function public.api_admin_update_alias(
  p_normalization_run_id uuid,
  p_selected_item_id uuid,
  p_alias text,
  p_provider_brand_id uuid default null,
  p_reason text default 'Manual admin review'
)
returns jsonb
language plpgsql
security definer
set search_path = public, ingest, catalog, core
as $$
declare
  v_alias text := trim(coalesce(p_alias, ''));
  v_normalized text;
  v_brand_id uuid;
begin
  if p_normalization_run_id is null or p_selected_item_id is null or v_alias = '' then
    raise exception 'normalization run, selected item and alias are required';
  end if;
  select provider_brand_id into v_brand_id
  from ingest.normalization_runs
  where id = p_normalization_run_id;
  v_brand_id := coalesce(p_provider_brand_id, v_brand_id);
  v_normalized := core.normalized_text(v_alias);
  insert into catalog.item_aliases(
    item_id, alias, normalized_alias, alias_type, provider_brand_id,
    confidence, status, source_note, approved_at
  ) values (
    p_selected_item_id, v_alias, v_normalized, 'provider_name', v_brand_id,
    1.0000, 'approved', p_reason, now()
  ) on conflict do nothing;
  update ingest.normalization_runs
  set status = 'resolved', resolved_at = now()
  where id = p_normalization_run_id;
  insert into ingest.normalization_decisions(
    normalization_run_id, selected_item_id, decision_type, reason
  ) values (p_normalization_run_id, p_selected_item_id, 'manual', p_reason);
  return jsonb_build_object(
    'normalization_run_id', p_normalization_run_id,
    'selected_item_id', p_selected_item_id,
    'normalized_alias', v_normalized,
    'status', 'resolved'
  );
end;
$$;

revoke all on function public.api_search(text, text, double precision, double precision, uuid, integer) from public;
revoke all on function public.api_admin_dashboard() from public;
revoke all on function public.api_admin_normalization_queue(text, integer) from public;
revoke all on function public.api_admin_raw_records(integer) from public;
revoke all on function public.api_admin_update_alias(uuid, uuid, text, uuid, text) from public;
grant execute on function public.api_search(text, text, double precision, double precision, uuid, integer) to anon, authenticated, service_role;
grant execute on function public.api_admin_dashboard() to service_role;
grant execute on function public.api_admin_normalization_queue(text, integer) to service_role;
grant execute on function public.api_admin_raw_records(integer) to service_role;
grant execute on function public.api_admin_update_alias(uuid, uuid, text, uuid, text) to service_role;

commit;
