-- Close the already-applied provider boundary before the rest of the
-- Worker/Storage migration chain is rolled out. The later migrations repeat
-- this guard with the same semantics, but a failed/interrupted deployment
-- must not leave an anonymous AAL2 session or a removed-factor session able
-- to call the legacy provider RPCs that still exist in the remote ledger.
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

commit;
