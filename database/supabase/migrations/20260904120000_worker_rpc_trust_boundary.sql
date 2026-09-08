-- Public clients use the Cloudflare Worker, which owns validation, response
-- sanitization and abuse controls. Prevent direct PostgREST calls from
-- bypassing that perimeter with the publishable Supabase key.

begin;

revoke all on function public.api_search(text, text, double precision, double precision, uuid, integer) from public, anon, authenticated;
revoke all on function public.api_resolve_search(text, text, double precision, double precision, uuid, integer) from public, anon, authenticated;
revoke all on function public.api_resolve_package(jsonb, text, double precision, double precision, uuid, integer) from public, anon, authenticated;
revoke all on function public.api_resolve_ocr_package(jsonb, text, double precision, double precision, uuid, integer) from public, anon, authenticated;
revoke all on function public.api_segment_package_text(text, text, integer) from public, anon, authenticated;
revoke all on function public.api_record_analytics_event(text, uuid, jsonb) from public, anon, authenticated;
revoke all on function public.api_service_detail(uuid) from public, anon, authenticated;
revoke all on function public.api_provider_detail(uuid) from public, anon, authenticated;

grant execute on function public.api_search(text, text, double precision, double precision, uuid, integer) to service_role;
grant execute on function public.api_resolve_search(text, text, double precision, double precision, uuid, integer) to service_role;
grant execute on function public.api_resolve_package(jsonb, text, double precision, double precision, uuid, integer) to service_role;
grant execute on function public.api_resolve_ocr_package(jsonb, text, double precision, double precision, uuid, integer) to service_role;
grant execute on function public.api_segment_package_text(text, text, integer) to service_role;
grant execute on function public.api_record_analytics_event(text, uuid, jsonb) to service_role;
grant execute on function public.api_service_detail(uuid) to service_role;
grant execute on function public.api_provider_detail(uuid) to service_role;

commit;
