-- Read-only Admin V1 operational lookup RPCs.

begin;

create or replace function public.api_admin_providers(p_limit integer default 100)
returns table (provider_id uuid, provider_name text, status text, verification_status text, locations_count bigint, active_offers_count bigint)
language sql stable security definer
set search_path = public, core, supply
as $$
select b.id, b.name, b.status, b.verification_status,
  (select count(*) from core.provider_locations l where l.provider_brand_id=b.id and l.status='active'),
  (select count(*) from supply.offers o where o.provider_brand_id=b.id and o.status='active')
from core.provider_brands b
order by b.name
limit greatest(1, least(coalesce(p_limit,100),200));
$$;

create or replace function public.api_admin_locations(p_limit integer default 100)
returns table (location_id uuid, provider_name text, location_name text, address text, locality text, status text, latitude double precision, longitude double precision)
language sql stable security definer
set search_path = public, core, gis
as $$
select l.id, b.name, l.name, l.address_line_1, l.locality_text, l.status,
  case when l.coordinates is null then null else gis.st_y(l.coordinates::gis.geometry) end,
  case when l.coordinates is null then null else gis.st_x(l.coordinates::gis.geometry) end
from core.provider_locations l join core.provider_brands b on b.id=l.provider_brand_id
order by b.name,l.name
limit greatest(1, least(coalesce(p_limit,100),200));
$$;

create or replace function public.api_admin_offers(p_limit integer default 100)
returns table (offer_id uuid, provider_name text, service_name text, catalog_item_id uuid, status text, current_price_count bigint, last_seen_at timestamptz)
language sql stable security definer
set search_path = public, core, catalog, supply
as $$
select o.id, b.name,
  coalesce((select n.name from catalog.item_names n where n.item_id=o.catalog_item_id and n.is_primary order by n.locale='es-MX' desc limit 1), o.catalog_item_id::text),
  o.catalog_item_id, o.status,
  (select count(*) from supply.offer_scopes os join supply.current_price_versions pv on pv.offer_scope_id=os.id where os.offer_id=o.id),
  (select max(pv.last_seen_at) from supply.offer_scopes os join supply.current_price_versions pv on pv.offer_scope_id=os.id where os.offer_id=o.id)
from supply.offers o join core.provider_brands b on b.id=o.provider_brand_id
order by b.name, 3
limit greatest(1, least(coalesce(p_limit,100),200));
$$;

create or replace function public.api_admin_prices(p_limit integer default 100)
returns table (price_version_id uuid, provider_name text, service_name text, amount_minor bigint, currency char(3), price_type text, last_seen_at timestamptz, source_url text)
language sql stable security definer
set search_path = public, core, catalog, supply, ingest
as $$
select pv.id, b.name,
  coalesce((select n.name from catalog.item_names n where n.item_id=o.catalog_item_id and n.is_primary order by n.locale='es-MX' desc limit 1), o.catalog_item_id::text),
  pv.amount_minor, pv.currency, pv.price_type, pv.last_seen_at,
  (select ol.url from supply.offer_links ol where ol.offer_scope_id=os.id and ol.link_type='details' and ol.status='active' order by ol.created_at desc limit 1)
from supply.price_versions pv
join supply.offer_scopes os on os.id=pv.offer_scope_id
join supply.offers o on o.id=os.offer_id
join core.provider_brands b on b.id=o.provider_brand_id
where pv.is_current and o.status='active'
order by pv.last_seen_at desc
limit greatest(1, least(coalesce(p_limit,100),200));
$$;

create or replace function public.api_admin_quality_issues(p_status text default null, p_limit integer default 100)
returns table (issue_id uuid, issue_code text, severity text, status text, source_id uuid, crawl_run_id uuid, details jsonb, created_at timestamptz)
language sql stable security definer
set search_path = public, ingest
as $$
select id, issue_code, severity, status, source_id, crawl_run_id, details, created_at
from ingest.data_quality_issues
where p_status is null or status=p_status
order by created_at desc
limit greatest(1, least(coalesce(p_limit,100),200));
$$;

create or replace function public.api_admin_alerts(p_status text default null, p_limit integer default 100)
returns table (alert_id uuid, alert_code text, severity text, status text, source text, title text, detail text, created_at timestamptz)
language sql stable security definer
set search_path = public, ops
as $$
select id, alert_code, severity, status, source, title, detail, created_at
from ops.system_alerts
where p_status is null or status=p_status
order by created_at desc
limit greatest(1, least(coalesce(p_limit,100),200));
$$;

do $$
declare fn text;
begin
  foreach fn in array array['api_admin_providers','api_admin_locations','api_admin_offers','api_admin_prices'] loop
    execute format('revoke all on function public.%I(integer) from public', fn);
    execute format('grant execute on function public.%I(integer) to service_role', fn);
  end loop;
end $$;
revoke all on function public.api_admin_quality_issues(text, integer) from public;
revoke all on function public.api_admin_alerts(text, integer) from public;
grant execute on function public.api_admin_quality_issues(text, integer) to service_role;
grant execute on function public.api_admin_alerts(text, integer) to service_role;

commit;
