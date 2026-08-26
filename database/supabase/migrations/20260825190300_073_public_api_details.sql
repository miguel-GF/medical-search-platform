-- Detail RPCs used by the versioned REST API.

begin;

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
    from supply.offers o join core.provider_brands b on b.id = o.provider_brand_id
    where o.catalog_item_id = i.id and o.status = 'active'
  ), '[]'::jsonb)
) end
from catalog.items i
where i.id = p_service_id and i.status <> 'hidden';
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
  'services', coalesce((select jsonb_agg(to_jsonb(x)) from (select i.id, coalesce((select n.name from catalog.item_names n where n.item_id=i.id and n.is_primary limit 1), '') as display_name from supply.offers o join catalog.items i on i.id=o.catalog_item_id where o.provider_brand_id=b.id and o.status='active' order by i.id) x), '[]'::jsonb)
) end
from core.provider_brands b
where b.id = p_provider_brand_id and b.status <> 'closed';
$$;

revoke all on function public.api_service_detail(uuid) from public;
revoke all on function public.api_provider_detail(uuid) from public;
grant execute on function public.api_service_detail(uuid) to anon, authenticated, service_role;
grant execute on function public.api_provider_detail(uuid) to anon, authenticated, service_role;

commit;
