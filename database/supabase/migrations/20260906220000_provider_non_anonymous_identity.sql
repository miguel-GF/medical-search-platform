-- AAL2 alone is not a sufficient provider identity if the Auth account is an
-- anonymous session that enrolled its own factor. Provider claims and their
-- evidence require a non-anonymous Auth user in addition to a current factor.
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
    -- Treat an unknown marker as unsafe.  The API makes the same fail-closed
    -- decision for a missing `is_anonymous` field; the database must not turn
    -- a future nullable/legacy Auth row into a privileged identity.
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

create or replace function public.provider_can_access_claim_storage(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = pg_catalog, identity, auth
as $$
declare
  v_claim_id uuid;
begin
  if p_name is null or p_name !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(pdf|jpg|jpeg|png)$' then
    return false;
  end if;
  begin
    v_claim_id := split_part(p_name, '/', 1)::uuid;
  exception when invalid_text_representation then
    return false;
  end;
  return auth.uid() is not null
    and auth.jwt()->>'aal' = 'aal2'
    and exists (
      select 1
      from auth.users u
      where u.id = auth.uid() and u.is_anonymous is false
    )
    and exists (
      select 1
      from auth.mfa_factors f
      where f.user_id = auth.uid() and f.status = 'verified'
    )
    and exists (
      select 1
      from identity.provider_claims c
      where c.id = v_claim_id and c.claimant_user_id = auth.uid()
        and c.status in ('pending','under_review')
    );
end;
$$;

revoke all on function public.provider_can_access_claim_storage(text)
  from public, anon, authenticated, service_role;
grant execute on function public.provider_can_access_claim_storage(text)
  to authenticated;

commit;
