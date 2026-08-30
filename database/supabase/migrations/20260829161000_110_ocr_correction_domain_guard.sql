-- OCR rules are clinical-study rules.  Keep the public OCR RPC from applying
-- them if a caller selects another domain.

begin;

alter function public.api_resolve_ocr_package(jsonb, text, double precision, double precision, uuid, integer)
  rename to api_resolve_ocr_package_internal;

create or replace function public.api_resolve_ocr_package(
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
select case
  when p_domain_code = 'health_diagnostics' then public.api_resolve_ocr_package_internal(
    p_items, p_domain_code, p_latitude, p_longitude, p_location_id, p_limit
  )
  else public.api_resolve_package(
    p_items, p_domain_code, p_latitude, p_longitude, p_location_id, p_limit
  )
end;
$$;

revoke all on function public.api_resolve_ocr_package_internal(jsonb, text, double precision, double precision, uuid, integer) from public, anon, authenticated;
revoke all on function public.api_resolve_ocr_package(jsonb, text, double precision, double precision, uuid, integer) from public;
grant execute on function public.api_resolve_ocr_package(jsonb, text, double precision, double precision, uuid, integer) to anon, authenticated, service_role;

commit;
