-- The first admin migrations revoked PUBLIC but did not explicitly revoke the
-- Data API roles. Keep every internal/admin RPC behind service_role.

begin;

revoke all on function public.api_admin_dashboard() from public, anon, authenticated;
revoke all on function public.api_admin_normalization_queue(text, integer) from public, anon, authenticated;
revoke all on function public.api_admin_raw_records(integer) from public, anon, authenticated;
revoke all on function public.api_admin_catalog_items(text, integer) from public, anon, authenticated;
revoke all on function public.api_admin_update_alias(uuid, uuid, text, uuid, text, uuid) from public, anon, authenticated;
revoke all on function public.api_admin_providers(integer) from public, anon, authenticated;
revoke all on function public.api_admin_locations(integer) from public, anon, authenticated;
revoke all on function public.api_admin_offers(integer) from public, anon, authenticated;
revoke all on function public.api_admin_prices(integer) from public, anon, authenticated;
revoke all on function public.api_admin_quality_issues(text, integer) from public, anon, authenticated;
revoke all on function public.api_admin_alerts(text, integer) from public, anon, authenticated;

grant execute on function public.api_admin_dashboard() to service_role;
grant execute on function public.api_admin_normalization_queue(text, integer) to service_role;
grant execute on function public.api_admin_raw_records(integer) to service_role;
grant execute on function public.api_admin_catalog_items(text, integer) to service_role;
grant execute on function public.api_admin_update_alias(uuid, uuid, text, uuid, text, uuid) to service_role;
grant execute on function public.api_admin_providers(integer) to service_role;
grant execute on function public.api_admin_locations(integer) to service_role;
grant execute on function public.api_admin_offers(integer) to service_role;
grant execute on function public.api_admin_prices(integer) to service_role;
grant execute on function public.api_admin_quality_issues(text, integer) to service_role;
grant execute on function public.api_admin_alerts(text, integer) to service_role;

commit;
