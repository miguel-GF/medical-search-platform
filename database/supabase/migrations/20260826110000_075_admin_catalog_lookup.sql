-- Catalog lookup for manual normalization review; service_role only.

begin;

create or replace function public.api_admin_catalog_items(
  p_query text default null,
  p_limit integer default 25
)
returns table (
  item_id uuid,
  display_name text,
  service_type text,
  status text
)
language sql
stable
security definer
set search_path = public, catalog, health, core
as $$
with query as (
  select nullif(core.normalized_text(trim(coalesce(p_query, ''))), '') as normalized_query
)
select
  i.id,
  coalesce((select n.name from catalog.item_names n where n.item_id = i.id and n.is_primary order by n.locale = 'es-MX' desc limit 1), i.id::text),
  s.service_type,
  i.status
from catalog.items i
join health.services s on s.catalog_item_id = i.id
cross join query q
where i.status = 'active'
  and (
    q.normalized_query is null
    or core.normalized_text(coalesce((select n.name from catalog.item_names n where n.item_id = i.id and n.is_primary order by n.locale = 'es-MX' desc limit 1), '')) like '%' || q.normalized_query || '%'
    or exists (
      select 1 from catalog.item_names n
      where n.item_id = i.id
        and (n.normalized_name = q.normalized_query or n.normalized_name like '%' || q.normalized_query || '%')
    )
  )
order by 2
limit greatest(1, least(coalesce(p_limit, 25), 100));
$$;

revoke all on function public.api_admin_catalog_items(text, integer) from public;
grant execute on function public.api_admin_catalog_items(text, integer) to service_role;

commit;
