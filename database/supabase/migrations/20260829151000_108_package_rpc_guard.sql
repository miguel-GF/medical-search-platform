-- Keep the public batch RPC bounded even when it is called directly through
-- PostgREST instead of through the Worker request validator.

begin;

alter function public.api_resolve_package(jsonb, text, double precision, double precision, uuid, integer)
  rename to api_resolve_package_internal;

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
with safe_items as (
  select coalesce(jsonb_agg(to_jsonb(trim(value)) order by ordinality), '[]'::jsonb) as items
  from jsonb_array_elements_text(
    case when jsonb_typeof(coalesce(p_items, '[]'::jsonb)) = 'array'
      then coalesce(p_items, '[]'::jsonb)
      else '[]'::jsonb
    end
  ) with ordinality as x(value, ordinality)
  where x.ordinality <= 30
    and char_length(trim(x.value)) between 1 and 200
)
select public.api_resolve_package_internal(
  (select items from safe_items),
  p_domain_code,
  p_latitude,
  p_longitude,
  p_location_id,
  p_limit
);
$$;

revoke all on function public.api_resolve_package_internal(jsonb, text, double precision, double precision, uuid, integer) from public, anon, authenticated;
revoke all on function public.api_resolve_package(jsonb, text, double precision, double precision, uuid, integer) from public;
grant execute on function public.api_resolve_package(jsonb, text, double precision, double precision, uuid, integer) to anon, authenticated, service_role;

commit;
