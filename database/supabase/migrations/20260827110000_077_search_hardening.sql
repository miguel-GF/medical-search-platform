-- Search hardening: bounded RPC input, provider diversity and active-only details.

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
  select *
  from public.api_search_scoped_v1(
    p_query,
    p_domain_code,
    p_latitude,
    p_longitude,
    p_location_id,
    greatest(1, least(coalesce(p_limit, 20), 100)) * 3
  )
  where core.normalized_text(p_query) <> ''
), scoped as (
  select r.*
  from rows r
  where r.provider_location_id is not null
     or not exists (
       select 1 from rows concrete
       where concrete.offer_id = r.offer_id
         and concrete.provider_location_id is not null
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
  p.latitude,
  p.longitude,
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

-- The scoped implementation is an internal helper, not a Data API surface.
revoke all on function public.api_search_scoped_v1(text, text, double precision, double precision, uuid, integer) from public, anon, authenticated;
grant execute on function public.api_search_scoped_v1(text, text, double precision, double precision, uuid, integer) to service_role;

create or replace function public.api_service_detail(p_service_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, catalog, health, supply, core
as $$
select case when i.id is null then null else jsonb_build_object(
  'id', i.id,
  'status', i.status,
  'item_type', i.item_type,
  'names', coalesce((select jsonb_agg(jsonb_build_object('name', n.name, 'type', n.name_type, 'primary', n.is_primary) order by n.is_primary desc, n.name) from catalog.item_names n where n.item_id = i.id), '[]'::jsonb),
  'service', (select to_jsonb(h) from health.services h where h.catalog_item_id = i.id),
  'offers', coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', o.id,
      'provider_brand_id', o.provider_brand_id,
      'provider_name', b.name,
      'provider_display_name', o.provider_display_name,
      'provider_sku', o.provider_sku,
      'status', o.status,
      'scopes', (select coalesce(jsonb_agg(jsonb_build_object('scope_type', os.scope_type, 'market_id', os.provider_market_id, 'location_id', os.provider_location_id)), '[]'::jsonb) from supply.offer_scopes os where os.offer_id = o.id and os.status = 'active'),
      'prices', (select coalesce(jsonb_agg(jsonb_build_object('price_type', pv.price_type, 'price_key', pv.price_key, 'amount_minor', pv.amount_minor, 'currency', pv.currency, 'last_seen_at', pv.last_seen_at)), '[]'::jsonb) from supply.offer_scopes os join supply.current_price_versions pv on pv.offer_scope_id = os.id where os.offer_id = o.id and os.status = 'active')
    ) order by b.name, o.provider_display_name)
    from supply.offers o join core.provider_brands b on b.id = o.provider_brand_id and b.status = 'active'
    where o.catalog_item_id = i.id and o.status = 'active'
  ), '[]'::jsonb)
) end
from catalog.items i
where i.id = p_service_id and i.status = 'active';
$$;

create or replace function public.api_provider_detail(p_provider_brand_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, core, catalog, supply, gis
as $$
select case when b.id is null then null else jsonb_build_object(
  'id', b.id,
  'name', b.name,
  'slug', b.slug,
  'website_url', b.website_url,
  'verification_status', b.verification_status,
  'locations', coalesce((select jsonb_agg(to_jsonb(x)) from (select l.id, l.name, l.address_line_1 as address, l.locality_text as locality, l.postal_code, l.phone, case when l.coordinates is null then null else gis.st_y(l.coordinates::gis.geometry) end as latitude, case when l.coordinates is null then null else gis.st_x(l.coordinates::gis.geometry) end as longitude from core.provider_locations l where l.provider_brand_id = b.id and l.status = 'active' order by l.name) x), '[]'::jsonb),
  'services', coalesce((select jsonb_agg(to_jsonb(x)) from (select distinct i.id, coalesce((select n.name from catalog.item_names n where n.item_id=i.id and n.is_primary limit 1), '') as display_name from supply.offers o join catalog.items i on i.id=o.catalog_item_id where o.provider_brand_id=b.id and o.status='active' and i.status='active' order by i.id) x), '[]'::jsonb)
) end
from core.provider_brands b
where b.id = p_provider_brand_id and b.status = 'active';
$$;

revoke all on function public.api_search(text, text, double precision, double precision, uuid, integer) from public;
grant execute on function public.api_search(text, text, double precision, double precision, uuid, integer) to anon, authenticated, service_role;
revoke all on function public.api_service_detail(uuid) from public;
revoke all on function public.api_provider_detail(uuid) from public;
grant execute on function public.api_service_detail(uuid) to anon, authenticated, service_role;
grant execute on function public.api_provider_detail(uuid) to anon, authenticated, service_role;

commit;
