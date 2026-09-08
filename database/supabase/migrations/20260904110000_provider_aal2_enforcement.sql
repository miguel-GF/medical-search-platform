-- Provider self-service is privileged: every call must carry a Supabase JWT
-- whose Authenticator Assurance Level is aal2.  Keep the check in PostgreSQL
-- as well as in the Worker so calling PostgREST/RPC directly cannot bypass MFA.

begin;

create or replace function core.require_provider_aal2()
returns void
language plpgsql
stable
security invoker
set search_path = pg_catalog, auth
as $$
declare
  v_claims jsonb := coalesce(auth.jwt(), '{}'::jsonb);
begin
  if auth.uid() is null or not exists (
    select 1
    from auth.users u
    where u.id = auth.uid() and u.is_anonymous is false
  ) then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  if v_claims->>'aal' is distinct from 'aal2' then
    raise exception using errcode = '42501', message = 'MFA with AAL2 is required';
  end if;
  if not exists (
    select 1
    from auth.mfa_factors
    where user_id = auth.uid() and status = 'verified'
  ) then
    raise exception using errcode = '42501', message = 'MFA with AAL2 is required';
  end if;
end;
$$;

revoke all on function core.require_provider_aal2() from public, anon, authenticated, service_role;

-- Preserve the mature lifecycle implementations behind owner-only functions.
-- The public functions below are the sole authenticated entry points and run
-- the AAL2 guard before touching any provider state or returning private data.
alter function public.api_provider_create_claim(text, uuid, uuid, uuid, text, text, text, jsonb)
  rename to provider_create_claim_aal2_impl;
alter function public.provider_create_claim_aal2_impl(text, uuid, uuid, uuid, text, text, text, jsonb)
  set schema identity;

alter function public.api_provider_my_claims(text, integer)
  rename to provider_my_claims_aal2_impl;
alter function public.provider_my_claims_aal2_impl(text, integer)
  set schema identity;

alter function public.api_provider_add_claim_document(uuid, text, text, text, jsonb)
  rename to provider_add_claim_document_aal2_impl;
alter function public.provider_add_claim_document_aal2_impl(uuid, text, text, text, jsonb)
  set schema identity;

alter function public.api_provider_invite_member(uuid, uuid, text, uuid)
  rename to provider_invite_member_aal2_impl;
alter function public.provider_invite_member_aal2_impl(uuid, uuid, text, uuid)
  set schema identity;

alter function public.api_provider_submit_location_change(uuid, uuid, jsonb)
  rename to provider_submit_location_change_aal2_impl;
alter function public.provider_submit_location_change_aal2_impl(uuid, uuid, jsonb)
  set schema identity;

alter function public.api_provider_accept_membership(uuid)
  rename to provider_accept_membership_aal2_impl;
alter function public.provider_accept_membership_aal2_impl(uuid)
  set schema identity;

alter function public.api_provider_my_memberships(text, integer)
  rename to provider_my_memberships_aal2_impl;
alter function public.provider_my_memberships_aal2_impl(text, integer)
  set schema identity;

revoke all on function identity.provider_create_claim_aal2_impl(text, uuid, uuid, uuid, text, text, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function identity.provider_my_claims_aal2_impl(text, integer) from public, anon, authenticated, service_role;
revoke all on function identity.provider_add_claim_document_aal2_impl(uuid, text, text, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function identity.provider_invite_member_aal2_impl(uuid, uuid, text, uuid) from public, anon, authenticated, service_role;
revoke all on function identity.provider_submit_location_change_aal2_impl(uuid, uuid, jsonb) from public, anon, authenticated, service_role;
revoke all on function identity.provider_accept_membership_aal2_impl(uuid) from public, anon, authenticated, service_role;
revoke all on function identity.provider_my_memberships_aal2_impl(text, integer) from public, anon, authenticated, service_role;

create function public.api_provider_create_claim(
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
  perform core.require_provider_aal2();
  return identity.provider_create_claim_aal2_impl(
    p_scope_type, p_provider_brand_id, p_provider_location_id, p_organization_id,
    p_requested_role, p_relationship_type, p_reason, p_evidence_metadata
  );
end;
$$;

create function public.api_provider_my_claims(
  p_status text default null,
  p_limit integer default 50
)
returns table (
  claim_id uuid,
  claim_scope_type text,
  provider_brand_id uuid,
  provider_name text,
  provider_location_id uuid,
  provider_location_name text,
  organization_id uuid,
  organization_name text,
  requested_role text,
  relationship_type text,
  status text,
  reason text,
  created_at timestamptz,
  reviewed_at timestamptz,
  review_reason text
)
language plpgsql
stable
security definer
set search_path = pg_catalog, core, identity
as $$
begin
  perform core.require_provider_aal2();
  return query select * from identity.provider_my_claims_aal2_impl(p_status, p_limit);
end;
$$;

create function public.api_provider_add_claim_document(
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
  perform core.require_provider_aal2();
  return identity.provider_add_claim_document_aal2_impl(
    p_claim_id, p_document_type, p_object_key, p_sha256, p_metadata
  );
end;
$$;

create function public.api_provider_invite_member(
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
  perform core.require_provider_aal2();
  return identity.provider_invite_member_aal2_impl(
    p_claim_id, p_user_id, p_role, p_provider_location_id
  );
end;
$$;

create function public.api_provider_submit_location_change(
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
  perform core.require_provider_aal2();
  return identity.provider_submit_location_change_aal2_impl(
    p_claim_id, p_provider_location_id, p_changes
  );
end;
$$;

create function public.api_provider_accept_membership(p_membership_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, core, identity
as $$
begin
  perform core.require_provider_aal2();
  return identity.provider_accept_membership_aal2_impl(p_membership_id);
end;
$$;

create function public.api_provider_my_memberships(
  p_status text default null,
  p_limit integer default 100
)
returns table (
  membership_id uuid,
  organization_id uuid,
  organization_name text,
  scope_type text,
  provider_brand_id uuid,
  provider_name text,
  provider_location_id uuid,
  provider_location_name text,
  role text,
  status text,
  invited_by uuid,
  activated_at timestamptz,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog, core, identity
as $$
begin
  perform core.require_provider_aal2();
  return query select * from identity.provider_my_memberships_aal2_impl(p_status, p_limit);
end;
$$;

revoke all on function public.api_provider_create_claim(text, uuid, uuid, uuid, text, text, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.api_provider_my_claims(text, integer) from public, anon, authenticated, service_role;
revoke all on function public.api_provider_add_claim_document(uuid, text, text, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.api_provider_invite_member(uuid, uuid, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.api_provider_submit_location_change(uuid, uuid, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.api_provider_accept_membership(uuid) from public, anon, authenticated, service_role;
revoke all on function public.api_provider_my_memberships(text, integer) from public, anon, authenticated, service_role;

grant execute on function public.api_provider_create_claim(text, uuid, uuid, uuid, text, text, text, jsonb) to authenticated;
grant execute on function public.api_provider_my_claims(text, integer) to authenticated;
grant execute on function public.api_provider_add_claim_document(uuid, text, text, text, jsonb) to authenticated;
grant execute on function public.api_provider_invite_member(uuid, uuid, text, uuid) to authenticated;
grant execute on function public.api_provider_submit_location_change(uuid, uuid, jsonb) to authenticated;
grant execute on function public.api_provider_accept_membership(uuid) to authenticated;
grant execute on function public.api_provider_my_memberships(text, integer) to authenticated;

commit;
