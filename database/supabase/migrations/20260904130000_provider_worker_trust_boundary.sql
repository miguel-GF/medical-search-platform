-- Provider RPCs also pass through the Worker. The Worker validates the real
-- Supabase session, enforces AAL2 and rate limits, then calls these service-only
-- wrappers with the verified actor. Direct publishable-key RPC access is gone.

begin;

create or replace function core.set_verified_provider_actor(
  p_actor_user_id uuid,
  p_actor_aal text
)
returns void
language plpgsql
security invoker
set search_path = pg_catalog, auth
as $$
declare
  v_claims jsonb := coalesce(auth.jwt(), '{}'::jsonb);
begin
  if p_actor_aal is distinct from 'aal2' then
    raise exception using errcode = '42501', message = 'MFA with AAL2 is required';
  end if;
  if p_actor_user_id is null or not exists (
    select 1
    from auth.users u
    where u.id = p_actor_user_id and u.is_anonymous is false
  ) then
    raise exception using errcode = '42501', message = 'Verified provider actor is required';
  end if;
  if not exists (
    select 1
    from auth.mfa_factors
    where user_id = p_actor_user_id and status = 'verified'
  ) then
    raise exception using errcode = '42501', message = 'MFA with AAL2 is required';
  end if;
  perform set_config('request.jwt.claim.sub', p_actor_user_id::text, true);
  perform set_config(
    'request.jwt.claims',
    (v_claims || jsonb_build_object('sub', p_actor_user_id::text, 'role', 'authenticated', 'aal', 'aal2'))::text,
    true
  );
end;
$$;

revoke all on function core.set_verified_provider_actor(uuid, text) from public, anon, authenticated, service_role;

create or replace function public.api_server_provider_create_claim(
  p_actor_user_id uuid,
  p_actor_aal text,
  p_scope_type text,
  p_provider_brand_id uuid,
  p_provider_location_id uuid,
  p_organization_id uuid,
  p_requested_role text,
  p_relationship_type text,
  p_reason text default null,
  p_evidence_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, core, identity
as $$
begin
  perform core.set_verified_provider_actor(p_actor_user_id, p_actor_aal);
  return identity.provider_create_claim_aal2_impl(
    p_scope_type, p_provider_brand_id, p_provider_location_id, p_organization_id,
    p_requested_role, p_relationship_type, p_reason, p_evidence_metadata
  );
end;
$$;

create or replace function public.api_server_provider_my_claims(
  p_actor_user_id uuid,
  p_actor_aal text,
  p_status text default null,
  p_limit integer default 50
)
returns table (
  claim_id uuid, claim_scope_type text, provider_brand_id uuid, provider_name text,
  provider_location_id uuid, provider_location_name text, organization_id uuid,
  organization_name text, requested_role text, relationship_type text, status text,
  reason text, created_at timestamptz, reviewed_at timestamptz, review_reason text
)
language plpgsql
stable
security definer
set search_path = pg_catalog, core, identity
as $$
begin
  perform core.set_verified_provider_actor(p_actor_user_id, p_actor_aal);
  return query select * from identity.provider_my_claims_aal2_impl(p_status, p_limit);
end;
$$;

create or replace function public.api_server_provider_add_claim_document(
  p_actor_user_id uuid,
  p_actor_aal text,
  p_claim_id uuid,
  p_document_type text,
  p_object_key text,
  p_sha256 text,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, core, identity
as $$
begin
  perform core.set_verified_provider_actor(p_actor_user_id, p_actor_aal);
  return identity.provider_add_claim_document_aal2_impl(p_claim_id, p_document_type, p_object_key, p_sha256, p_metadata);
end;
$$;

create or replace function public.api_server_provider_invite_member(
  p_actor_user_id uuid,
  p_actor_aal text,
  p_claim_id uuid,
  p_user_id uuid,
  p_role text,
  p_provider_location_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, core, identity
as $$
begin
  perform core.set_verified_provider_actor(p_actor_user_id, p_actor_aal);
  return identity.provider_invite_member_aal2_impl(p_claim_id, p_user_id, p_role, p_provider_location_id);
end;
$$;

create or replace function public.api_server_provider_submit_location_change(
  p_actor_user_id uuid,
  p_actor_aal text,
  p_claim_id uuid,
  p_provider_location_id uuid,
  p_changes jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, core, identity
as $$
begin
  perform core.set_verified_provider_actor(p_actor_user_id, p_actor_aal);
  return identity.provider_submit_location_change_aal2_impl(p_claim_id, p_provider_location_id, p_changes);
end;
$$;

create or replace function public.api_server_provider_accept_membership(
  p_actor_user_id uuid,
  p_actor_aal text,
  p_membership_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, core, identity
as $$
begin
  perform core.set_verified_provider_actor(p_actor_user_id, p_actor_aal);
  return identity.provider_accept_membership_aal2_impl(p_membership_id);
end;
$$;

create or replace function public.api_server_provider_my_memberships(
  p_actor_user_id uuid,
  p_actor_aal text,
  p_status text default null,
  p_limit integer default 100
)
returns table (
  membership_id uuid, organization_id uuid, organization_name text, scope_type text,
  provider_brand_id uuid, provider_name text, provider_location_id uuid,
  provider_location_name text, role text, status text, invited_by uuid,
  activated_at timestamptz, created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog, core, identity
as $$
begin
  perform core.set_verified_provider_actor(p_actor_user_id, p_actor_aal);
  return query select * from identity.provider_my_memberships_aal2_impl(p_status, p_limit);
end;
$$;

-- The user-scoped compatibility functions remain owner-callable for database
-- regression tests, but no Data API role can execute them.
revoke all on function public.api_provider_create_claim(text, uuid, uuid, uuid, text, text, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.api_provider_my_claims(text, integer) from public, anon, authenticated, service_role;
revoke all on function public.api_provider_add_claim_document(uuid, text, text, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.api_provider_invite_member(uuid, uuid, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.api_provider_submit_location_change(uuid, uuid, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.api_provider_accept_membership(uuid) from public, anon, authenticated, service_role;
revoke all on function public.api_provider_my_memberships(text, integer) from public, anon, authenticated, service_role;

revoke all on function public.api_server_provider_create_claim(uuid, text, text, uuid, uuid, uuid, text, text, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.api_server_provider_my_claims(uuid, text, text, integer) from public, anon, authenticated, service_role;
revoke all on function public.api_server_provider_add_claim_document(uuid, text, uuid, text, text, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.api_server_provider_invite_member(uuid, text, uuid, uuid, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.api_server_provider_submit_location_change(uuid, text, uuid, uuid, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.api_server_provider_accept_membership(uuid, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.api_server_provider_my_memberships(uuid, text, text, integer) from public, anon, authenticated, service_role;

grant execute on function public.api_server_provider_create_claim(uuid, text, text, uuid, uuid, uuid, text, text, text, jsonb) to service_role;
grant execute on function public.api_server_provider_my_claims(uuid, text, text, integer) to service_role;
grant execute on function public.api_server_provider_add_claim_document(uuid, text, uuid, text, text, text, jsonb) to service_role;
grant execute on function public.api_server_provider_invite_member(uuid, text, uuid, uuid, text, uuid) to service_role;
grant execute on function public.api_server_provider_submit_location_change(uuid, text, uuid, uuid, jsonb) to service_role;
grant execute on function public.api_server_provider_accept_membership(uuid, text, uuid) to service_role;
grant execute on function public.api_server_provider_my_memberships(uuid, text, text, integer) to service_role;

commit;
