-- Provider lifecycle calls are service-only and still fail closed on AAL1.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(15);

insert into auth.users(id, aud, role, email, created_at, updated_at, is_sso_user, is_anonymous)
values ('00000000-0000-0000-0000-000000000891', 'authenticated', 'authenticated', 'boundary-891@example.invalid', now(), now(), false, false),
       ('00000000-0000-0000-0000-000000000892', 'authenticated', 'authenticated', 'boundary-892@example.invalid', now(), now(), false, false),
       ('00000000-0000-0000-0000-000000000895', 'authenticated', 'authenticated', 'boundary-895@example.invalid', now(), now(), false, false),
       ('00000000-0000-0000-0000-000000000896', 'authenticated', 'authenticated', null, now(), now(), false, true);
insert into auth.mfa_factors(id, user_id, factor_type, status, created_at, updated_at, secret)
values ('00000000-0000-0000-0000-000000000893', '00000000-0000-0000-0000-000000000891', 'totp', 'verified', now(), now(), 'boundary-secret-891'),
       ('00000000-0000-0000-0000-000000000894', '00000000-0000-0000-0000-000000000892', 'totp', 'verified', now(), now(), 'boundary-secret-892'),
       ('00000000-0000-0000-0000-000000000897', '00000000-0000-0000-0000-000000000896', 'totp', 'verified', now(), now(), 'boundary-secret-896');
insert into core.organizations(id, legal_name, status)
values ('00000000-0000-0000-0000-000000000881', 'Boundary Test', 'active');
insert into core.provider_brands(id, name, normalized_name, slug)
values ('00000000-0000-0000-0000-000000000882', 'Boundary Test', 'boundary test', 'security-boundary-test');

-- Exercise ACLs with actual SET ROLE instead of only reading grant metadata.
-- This helper is transaction-local and has no SECURITY DEFINER privileges.
create function pg_temp.boundary_call(p_role text, p_sql text) returns jsonb
language plpgsql as $$
declare
  v_result jsonb;
begin
  execute format('set local role %I', p_role);
  execute p_sql into v_result;
  reset role;
  return v_result;
exception when others then
  reset role;
  raise;
end;
$$;

select extensions.is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'api_provider_%'
     and has_function_privilege('authenticated', p.oid, 'execute')),
  0,
  'authenticated cannot call provider RPCs directly'
);
select extensions.is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'api_server_provider_%'
     and has_function_privilege('authenticated', p.oid, 'execute')),
  0,
  'authenticated cannot call server provider wrappers'
);
select extensions.is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'api_server_provider_%'
     and has_function_privilege('service_role', p.oid, 'execute')),
  7,
  'service role owns the seven provider entry points'
);
select extensions.throws_ok(
  $$select count(*) from public.api_server_provider_my_claims('00000000-0000-0000-0000-000000000899', 'aal1')$$,
  '42501', 'MFA with AAL2 is required', 'server wrapper rejects an AAL1 assertion'
);
select extensions.throws_ok(
  $$select count(*) from public.api_server_provider_my_claims(null, 'aal2')$$,
  '42501', 'Verified provider actor is required', 'server wrapper rejects a missing actor'
);
select extensions.throws_ok(
  $$select pg_temp.boundary_call('service_role', $q$select to_jsonb(count(*)) from public.api_server_provider_my_claims(
    '00000000-0000-0000-0000-000000000895', 'aal2')$q$)$$,
  '42501', 'MFA with AAL2 is required', 'server wrapper rejects an actor without a current verified factor'
);
select extensions.throws_ok(
  $$select pg_temp.boundary_call('service_role', $q$select to_jsonb(count(*)) from public.api_server_provider_my_claims(
    '00000000-0000-0000-0000-000000000896', 'aal2')$q$)$$,
  '42501', 'Authentication required', 'server wrapper rejects an anonymous actor even with a verified factor'
);

select extensions.is(
  pg_temp.boundary_call('service_role', $$select public.api_server_provider_create_claim(
    '00000000-0000-0000-0000-000000000891', 'aal2', 'brand',
    '00000000-0000-0000-0000-000000000882', null,
    '00000000-0000-0000-0000-000000000881', 'brand_admin', 'owner')$$)->>'status',
  'pending', 'real service role can create a claim for a verified AAL2 actor'
);
select extensions.is(
  pg_temp.boundary_call('service_role', $$select to_jsonb(count(*)) from public.api_server_provider_my_claims(
    '00000000-0000-0000-0000-000000000891', 'aal2')$$),
  '1'::jsonb, 'server read returns the verified actor claim'
);
select extensions.is(
  pg_temp.boundary_call('service_role', $$select to_jsonb(count(*)) from public.api_server_provider_my_claims(
    '00000000-0000-0000-0000-000000000892', 'aal2')$$),
  '0'::jsonb, 'switching verified actor cannot expose another user claims'
);
select extensions.is(
  pg_temp.boundary_call('service_role', $$select to_jsonb(count(*)) from public.api_server_provider_my_memberships(
    '00000000-0000-0000-0000-000000000891', 'aal2')$$),
  '0'::jsonb, 'server membership read works for a real AAL2 actor'
);
select extensions.throws_ok(
  $$select pg_temp.boundary_call('authenticated', 'select to_jsonb(count(*)) from public.api_provider_my_claims()')$$,
  '42501', null, 'actual authenticated role cannot invoke legacy RPC'
);
select extensions.throws_ok(
  $$select pg_temp.boundary_call('service_role', 'select to_jsonb(count(*)) from public.api_provider_my_claims()')$$,
  '42501', null, 'service role cannot bypass the verified provider wrapper through the legacy RPC'
);
select extensions.throws_ok(
  $$select pg_temp.boundary_call('authenticated', $q$select to_jsonb(count(*)) from public.api_server_provider_my_claims(
    '00000000-0000-0000-0000-000000000891', 'aal2')$q$)$$,
  '42501', null, 'actual authenticated role cannot forge a server actor or AAL2'
);
select extensions.throws_ok(
  $$select pg_temp.boundary_call('service_role', $q$select to_jsonb(count(*)) from public.api_server_provider_my_claims(
    '00000000-0000-0000-0000-000000000891', 'aal1')$q$)$$,
  '42501', 'MFA with AAL2 is required', 'real service role rejects AAL1 even after an AAL2 call'
);

select * from extensions.finish();
rollback;
