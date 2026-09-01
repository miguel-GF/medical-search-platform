-- Keep provider lifecycle RPCs callable only through the intended trust boundary.
-- Supabase may preserve or re-apply role grants when functions are replaced, so
-- revoke the Data API roles explicitly instead of relying on PUBLIC revocation.

begin;

-- Provider self-service RPCs require an authenticated user.  service_role is
-- retained for the API/server-side worker path.
revoke all on function public.api_provider_create_claim(text, uuid, uuid, uuid, text, text, text, jsonb) from public, anon, authenticated;
revoke all on function public.api_provider_my_claims(text, integer) from public, anon, authenticated;
revoke all on function public.api_provider_add_claim_document(uuid, text, text, text, jsonb) from public, anon, authenticated;
revoke all on function public.api_provider_invite_member(uuid, uuid, text, uuid) from public, anon, authenticated;
revoke all on function public.api_provider_submit_location_change(uuid, uuid, jsonb) from public, anon, authenticated;
revoke all on function public.api_provider_accept_membership(uuid) from public, anon, authenticated;
revoke all on function public.api_provider_my_memberships(text, integer) from public, anon, authenticated;

grant execute on function public.api_provider_create_claim(text, uuid, uuid, uuid, text, text, text, jsonb) to authenticated, service_role;
grant execute on function public.api_provider_my_claims(text, integer) to authenticated, service_role;
grant execute on function public.api_provider_add_claim_document(uuid, text, text, text, jsonb) to authenticated, service_role;
grant execute on function public.api_provider_invite_member(uuid, uuid, text, uuid) to authenticated, service_role;
grant execute on function public.api_provider_submit_location_change(uuid, uuid, jsonb) to authenticated, service_role;
grant execute on function public.api_provider_accept_membership(uuid) to authenticated, service_role;
grant execute on function public.api_provider_my_memberships(text, integer) to authenticated, service_role;

-- Admin review/list/revocation RPCs are server-side only.  The API verifies
-- the admin session before forwarding the request with the service-role key.
revoke all on function public.api_admin_provider_claims(text, integer) from public, anon, authenticated;
revoke all on function public.api_admin_review_provider_claim(uuid, text, uuid, text) from public, anon, authenticated;
revoke all on function public.api_admin_revoke_provider_claim(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.api_admin_provider_change_requests(text, integer) from public, anon, authenticated;
revoke all on function public.api_admin_review_provider_change(uuid, text, uuid, text) from public, anon, authenticated;

grant execute on function public.api_admin_provider_claims(text, integer) to service_role;
grant execute on function public.api_admin_review_provider_claim(uuid, text, uuid, text) to service_role;
grant execute on function public.api_admin_revoke_provider_claim(uuid, uuid, text) to service_role;
grant execute on function public.api_admin_provider_change_requests(text, integer) to service_role;
grant execute on function public.api_admin_review_provider_change(uuid, text, uuid, text) to service_role;

commit;
