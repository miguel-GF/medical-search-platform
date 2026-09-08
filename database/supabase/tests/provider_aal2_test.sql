-- Provider RPCs must reject direct AAL1 calls at the database boundary.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(11);

insert into auth.users(id, aud, role, email, created_at, updated_at, is_sso_user, is_anonymous)
values ('00000000-0000-0000-0000-000000000899', 'authenticated', 'authenticated', 'aal2-899@example.invalid', now(), now(), false, false),
       ('00000000-0000-0000-0000-000000000900', 'authenticated', 'authenticated', 'aal2-900@example.invalid', now(), now(), false, false),
       ('00000000-0000-0000-0000-000000000902', 'authenticated', 'authenticated', null, now(), now(), false, true);
insert into auth.mfa_factors(id, user_id, factor_type, status, created_at, updated_at, secret)
values ('00000000-0000-0000-0000-000000000901', '00000000-0000-0000-0000-000000000899', 'totp', 'verified', now(), now(), 'aal2-test-secret'),
       ('00000000-0000-0000-0000-000000000903', '00000000-0000-0000-0000-000000000902', 'totp', 'verified', now(), now(), 'aal2-anonymous-secret');

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000899', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000899","role":"authenticated","aal":"aal1"}',
  true
);
select extensions.throws_ok(
  $$select public.api_provider_create_claim('brand', null, null, null, 'read_only', 'owner')$$,
  '42501', 'MFA with AAL2 is required', 'AAL1 cannot create a provider claim'
);
select extensions.throws_ok(
  $$select count(*) from public.api_provider_my_claims()$$,
  '42501', 'MFA with AAL2 is required', 'AAL1 cannot read provider claims'
);
select extensions.throws_ok(
  $$select public.api_provider_add_claim_document(null, 'other', 'provider-claims/x/y', repeat('a', 64))$$,
  '42501', 'MFA with AAL2 is required', 'AAL1 cannot add provider evidence'
);
select extensions.throws_ok(
  $$select public.api_provider_invite_member(null, null, 'read_only')$$,
  '42501', 'MFA with AAL2 is required', 'AAL1 cannot invite provider members'
);
select extensions.throws_ok(
  $$select public.api_provider_submit_location_change(null, null, '{}'::jsonb)$$,
  '42501', 'MFA with AAL2 is required', 'AAL1 cannot submit provider changes'
);
select extensions.throws_ok(
  $$select public.api_provider_accept_membership(null)$$,
  '42501', 'MFA with AAL2 is required', 'AAL1 cannot accept memberships'
);
select extensions.throws_ok(
  $$select count(*) from public.api_provider_my_memberships()$$,
  '42501', 'MFA with AAL2 is required', 'AAL1 cannot read provider memberships'
);

-- A missing assurance claim is also only AAL1 and must not become an
-- accidental compatibility path when Auth emits a legacy/malformed token.
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000899","role":"authenticated"}',
  true
);
select extensions.throws_ok(
  $$select count(*) from public.api_provider_my_claims()$$,
  '42501', 'MFA with AAL2 is required', 'AAL claim absence cannot read provider claims'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000899","role":"authenticated","aal":"aal2"}',
  true
);
select extensions.lives_ok(
  $$select count(*) from public.api_provider_my_claims()$$,
  'AAL2 reaches the provider RPC implementation'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000900', true);
select extensions.throws_ok(
  $$select count(*) from public.api_provider_my_claims()$$,
  '42501', 'MFA with AAL2 is required', 'AAL2 claim without a current factor is rejected'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000902', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000902","role":"authenticated","aal":"aal2"}',
  true
);
select extensions.throws_ok(
  $$select count(*) from public.api_provider_my_claims()$$,
  '42501', 'Authentication required', 'anonymous identity cannot use provider AAL2'
);

select * from extensions.finish();
rollback;
