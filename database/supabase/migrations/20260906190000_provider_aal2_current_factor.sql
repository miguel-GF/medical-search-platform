-- Defense in depth for the service-only provider wrappers.  The Worker checks
-- the same condition through Auth's REST API, but the database must also
-- reject an actor whose factor was removed between those two requests.
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
  if auth.uid() is null then
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
  if p_actor_user_id is null or not exists (select 1 from auth.users where id = p_actor_user_id) then
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

commit;
