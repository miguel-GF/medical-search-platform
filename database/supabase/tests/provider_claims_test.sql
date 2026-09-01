-- Provider claim, organization/sucursal scope and membership invariants.
-- Run against the linked project with:
-- npx.cmd supabase@latest db query --linked --file supabase/tests/provider_claims_test.sql

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(24);

select extensions.has_table('identity', 'provider_claims', 'provider claims table exists');
select extensions.has_table('identity', 'provider_memberships', 'provider memberships table exists');
select extensions.has_table('identity', 'provider_verifications', 'provider verifications table exists');
select extensions.has_table('identity', 'verification_documents', 'verification documents table exists');
select extensions.has_table('core', 'provider_location_organizations', 'location organization relation exists');

insert into core.organizations(id, legal_name, trade_name, tax_country, tax_identifier)
values ('00000000-0000-0000-0000-000000000801', 'Provider Claims Test S.A. de C.V.', 'Claims Test', 'MX', 'CLAIMS801')
on conflict (id) do nothing;
insert into core.provider_brands(id, name, normalized_name, slug)
values ('00000000-0000-0000-0000-000000000802', 'Provider Claims Test', 'provider claims test', 'provider-claims-test')
on conflict (id) do nothing;
insert into core.provider_locations(id, provider_brand_id, name, normalized_name, status)
values ('00000000-0000-0000-0000-000000000803', '00000000-0000-0000-0000-000000000802', 'Claims Test Puebla', 'claims test puebla', 'active')
on conflict (id) do nothing;

insert into auth.users(id, aud, role, email, created_at, updated_at, is_sso_user, is_anonymous)
values ('00000000-0000-0000-0000-000000000899', 'authenticated', 'authenticated', 'provider-claims-test@example.invalid', now(), now(), false, false)
on conflict (id) do nothing;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000899', true);

select extensions.is(
  public.api_provider_create_claim(
    'location',
    '00000000-0000-0000-0000-000000000802',
    '00000000-0000-0000-0000-000000000803',
    '00000000-0000-0000-0000-000000000801',
    'location_manager',
    'operator',
    'Test claim',
    jsonb_build_object('source', 'pgtap')
  )->>'status',
  'pending',
  'location claim starts pending'
);

select extensions.throws_ok(
  $$select public.api_provider_create_claim(
    'location',
    '00000000-0000-0000-0000-000000000802',
    '00000000-0000-0000-0000-000000000899',
    '00000000-0000-0000-0000-000000000801',
    'location_manager',
    'operator'
  )$$,
  'P0001',
  'Provider location does not exist',
  'location claim cannot reference an unknown location'
);

select extensions.is(
  (select count(*)::integer from identity.provider_claims where provider_location_id = '00000000-0000-0000-0000-000000000803'),
  1,
  'claim is stored once'
);

select extensions.is(
  (select count(*)::integer from public.api_provider_my_claims()),
  1,
  'claimant can list own claims'
);

select extensions.is(
  (public.api_provider_add_claim_document(
    (select id from identity.provider_claims where provider_location_id = '00000000-0000-0000-0000-000000000803'),
    'rfc', 'provider-claims/801/rfc.pdf', repeat('a', 64), '{}'::jsonb
  )->>'status'),
  'pending',
  'claimant can attach a document reference'
);

select extensions.throws_ok(
  $$select public.api_provider_add_claim_document(
    (select id from identity.provider_claims where provider_location_id = '00000000-0000-0000-0000-000000000803'),
    'rfc', '../escape.pdf', repeat('b', 64), '{}'::jsonb
  )$$,
  'P0001',
  'Invalid document object key',
  'document references cannot escape their storage prefix'
);

select extensions.is(
  (public.api_admin_review_provider_claim(
    (select id from identity.provider_claims where provider_location_id = '00000000-0000-0000-0000-000000000803'),
    'approved',
    '00000000-0000-0000-0000-000000000899',
    'Approved in test'
  )->>'status'),
  'approved',
  'admin approval changes claim status'
);

select extensions.is(
  (select count(*)::integer from core.provider_location_organizations
   where provider_location_id = '00000000-0000-0000-0000-000000000803'
     and organization_id = '00000000-0000-0000-0000-000000000801'
     and relationship_type = 'operator'),
  1,
  'approved location claim creates the legal relationship'
);

select extensions.is(
  (select count(*)::integer from identity.provider_memberships
   where provider_location_id = '00000000-0000-0000-0000-000000000803'
     and organization_id = '00000000-0000-0000-0000-000000000801'
     and role = 'location_manager' and status = 'active'),
  1,
  'approved location claim activates scoped membership'
);

select extensions.is(
  (select status from identity.provider_verifications
   where claim_id = (select id from identity.provider_claims where provider_location_id = '00000000-0000-0000-0000-000000000803')
   order by created_at desc limit 1),
  'passed',
  'approval records a passed verification'
);

select extensions.is(
  (public.api_provider_invite_member(
    (select id from identity.provider_claims where provider_location_id = '00000000-0000-0000-0000-000000000803'),
    '00000000-0000-0000-0000-000000000899',
    'editor',
    null
  )->>'status'),
  'invited',
  'location manager can invite an editor in the same branch'
);

select extensions.throws_ok(
  $$insert into identity.provider_memberships(user_id, organization_id, scope_type, provider_brand_id, provider_location_id, role)
    values ('00000000-0000-0000-0000-000000000899', '00000000-0000-0000-0000-000000000801', 'location', '00000000-0000-0000-0000-000000000899', '00000000-0000-0000-0000-000000000803', 'editor')$$,
  'P0001',
  'Provider membership brand and location must match',
  'membership cannot cross provider brands'
);

select extensions.throws_ok(
  $$insert into core.provider_location_organizations(provider_location_id, organization_id, relationship_type)
    values ('00000000-0000-0000-0000-000000000803', '00000000-0000-0000-0000-000000000801', 'operator')$$,
  '23505',
  'duplicate key value violates unique constraint "provider_location_organizatio_provider_location_id_organiza_key"',
  'the same active legal relationship cannot be duplicated'
);

select extensions.is(
  (public.api_provider_submit_location_change(
    (select id from identity.provider_claims where provider_location_id = '00000000-0000-0000-0000-000000000803'),
    '00000000-0000-0000-0000-000000000803',
    jsonb_build_object('name', 'Claims Test Puebla Updated', 'phone', '2220000000')
  )->>'status'),
  'pending',
  'approved provider can submit a scoped profile change'
);

select extensions.throws_ok(
  $$select public.api_provider_submit_location_change(
    (select id from identity.provider_claims where provider_location_id = '00000000-0000-0000-0000-000000000803'),
    '00000000-0000-0000-0000-000000000803',
    jsonb_build_object('status', 'closed')
  )$$,
  'P0001',
  null,
  'profile changes cannot alter canonical status'
);

select extensions.is(
  (public.api_admin_review_provider_change(
    (select id from identity.provider_change_requests order by created_at desc limit 1),
    'approved',
    '00000000-0000-0000-0000-000000000899',
    'Profile evidence accepted'
  )->>'status'),
  'approved',
  'admin approval applies a profile change'
);

select extensions.is(
  (select name from core.provider_locations where id = '00000000-0000-0000-0000-000000000803'),
  'Claims Test Puebla Updated',
  'approved profile change updates only the selected location'
);

select extensions.is(
  (select count(*)::integer from ingest.source_observations
   where entity_type = 'provider_location' and entity_id = '00000000-0000-0000-0000-000000000803'
     and attribute_name = 'provider_profile' and status = 'accepted'),
  1,
  'approved profile change records source provenance'
);

select extensions.is(
  (select count(*)::integer from audit.events where action in ('provider.claim_created', 'provider.claim_document_added', 'provider.claim_reviewed', 'provider.member_invited', 'provider.profile_change_submitted', 'provider.profile_change_reviewed')),
  6,
  'claim lifecycle actions are audited'
);

select * from extensions.finish();
rollback;
