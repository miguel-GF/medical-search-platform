-- RLS contract only: fixture metadata is not an upload or a malware scan.
-- A deliberately broad policy simulates an unrelated bucket misconfiguration.
-- All fixtures, policies and role changes are rolled back.
begin;
-- Exercise the deferred upload workflow only inside this rolled-back test.
-- The internal-release freeze has its own contract and remains on remotely.
drop policy if exists provider_documents_internal_freeze on storage.objects;
create extension if not exists pgtap with schema extensions;
select extensions.plan(25);
-- Match the Storage API session flag so DELETE tests exercise RLS, not the
-- separate protection against direct SQL deletion. Only our fixtures match.
set local storage.allow_delete_query = 'true';

insert into auth.users(id, aud, role, email, created_at, updated_at, is_sso_user, is_anonymous)
values ('00000000-0000-0000-0000-000000000971', 'authenticated', 'authenticated', 'storage-971@example.invalid', now(), now(), false, false),
       ('00000000-0000-0000-0000-000000000972', 'authenticated', 'authenticated', 'storage-972@example.invalid', now(), now(), false, false),
       ('00000000-0000-0000-0000-000000000983', 'authenticated', 'authenticated', null, now(), now(), false, true);
insert into auth.mfa_factors(id, user_id, factor_type, status, created_at, updated_at, secret)
values ('00000000-0000-0000-0000-000000000981', '00000000-0000-0000-0000-000000000971', 'totp', 'verified', now(), now(), 'storage-factor-971'),
       ('00000000-0000-0000-0000-000000000984', '00000000-0000-0000-0000-000000000983', 'totp', 'verified', now(), now(), 'storage-anonymous-factor');
insert into core.organizations(id, legal_name)
values ('00000000-0000-0000-0000-000000000973', 'Storage boundary fixture');
insert into core.provider_brands(id, name, normalized_name, slug)
values ('00000000-0000-0000-0000-000000000974', 'Storage boundary fixture', 'storage boundary fixture', 'storage-boundary-fixture');
insert into identity.provider_claims(id, claim_scope_type, provider_brand_id, organization_id, claimant_user_id, requested_role, relationship_type)
values ('00000000-0000-0000-0000-000000000975', 'brand', '00000000-0000-0000-0000-000000000974',
  '00000000-0000-0000-0000-000000000973', '00000000-0000-0000-0000-000000000971', 'brand_admin', 'owner');
insert into storage.objects(bucket_id, name, owner_id)
values ('provider-claims', '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000976.pdf', '00000000-0000-0000-0000-000000000971');

create policy security_test_overbroad_policy on storage.objects
for all to anon, authenticated using (true) with check (true);

create function pg_temp.storage_call(p_role text, p_user text, p_aal text, p_sql text) returns jsonb
language plpgsql as $$
declare v_result jsonb;
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_user, ''), true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', p_role, 'aal', p_aal)::text, true);
  execute format('set local role %I', p_role);
  execute p_sql into v_result;
  reset role;
  return v_result;
exception when others then
  reset role;
  raise;
end;
$$;

select extensions.is((select public from storage.buckets where id = 'provider-claims'), false, 'evidence bucket is private');
select extensions.is((select file_size_limit from storage.buckets where id = 'provider-claims'), 10485760::bigint, 'bucket caps uploads at 10 MiB');
select extensions.is(
  pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000971', 'aal2',
    $$select to_jsonb(count(*)) from storage.objects where bucket_id = 'provider-claims' and name like '00000000-0000-0000-0000-000000000975/%'$$),
  '1'::jsonb, 'AAL2 claimant can read own evidence');
select extensions.is(
  pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000972', 'aal2',
    $$select to_jsonb(count(*)) from storage.objects where bucket_id = 'provider-claims' and name like '00000000-0000-0000-0000-000000000975/%'$$),
  '0'::jsonb, 'broad policy cannot expose another claimant evidence');
select extensions.is(
  pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000971', 'aal1',
    $$select to_jsonb(count(*)) from storage.objects where bucket_id = 'provider-claims' and name like '00000000-0000-0000-0000-000000000975/%'$$),
  '0'::jsonb, 'AAL1 cannot read even own evidence');
select extensions.is(
  pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000971', null,
    $$select to_jsonb(count(*)) from storage.objects where bucket_id = 'provider-claims' and name like '00000000-0000-0000-0000-000000000975/%'$$),
  '0'::jsonb, 'missing AAL fails closed');
select extensions.is(
  pg_temp.storage_call('anon', null, null,
    $$select to_jsonb(count(*)) from storage.objects where bucket_id = 'provider-claims' and name like '00000000-0000-0000-0000-000000000975/%'$$),
  '0'::jsonb, 'broad policy cannot expose evidence to anon');
select extensions.is(
  pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000971', 'aal2',
    $$insert into storage.objects(bucket_id, name, owner_id) values ('provider-claims', '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000977.png', '00000000-0000-0000-0000-000000000971') returning to_jsonb(owner_id)$$),
  '"00000000-0000-0000-0000-000000000971"'::jsonb, 'AAL2 claimant can create new evidence metadata');
select extensions.throws_ok(
  $$select pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000972', 'aal2',
    $q$insert into storage.objects(bucket_id, name, owner_id) values ('provider-claims', '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000978.pdf', '00000000-0000-0000-0000-000000000972') returning to_jsonb(id)$q$)$$,
  '42501', null, 'broad policy cannot upload into another claimant path');
select extensions.throws_ok(
  $$select pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000971', 'aal2',
    $q$insert into storage.objects(bucket_id, name, owner_id) values ('provider-claims', '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000978.pdf', '00000000-0000-0000-0000-000000000972') returning to_jsonb(id)$q$)$$,
  '42501', null, 'claimant cannot forge object ownership');
select extensions.throws_ok(
  $$select pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000971', 'aal1',
    $q$insert into storage.objects(bucket_id, name, owner_id) values ('provider-claims', '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000978.pdf', '00000000-0000-0000-0000-000000000971') returning to_jsonb(id)$q$)$$,
  '42501', null, 'AAL1 cannot upload evidence');
select extensions.throws_ok(
  $$select pg_temp.storage_call('anon', null, null,
    $q$insert into storage.objects(bucket_id, name) values ('provider-claims', '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000978.pdf') returning to_jsonb(id)$q$)$$,
  '42501', null, 'broad policy cannot allow anonymous uploads');
select extensions.is(
  pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000971', 'aal2',
    $$with changed as (update storage.objects set metadata = '{"replaced":true}' where bucket_id = 'provider-claims' and name like '00000000-0000-0000-0000-000000000975/%' returning id) select to_jsonb(count(*)) from changed$$),
  '0'::jsonb, 'broad policy cannot authorize an evidence overwrite');
select extensions.is(
  pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000971', 'aal2',
    $$with changed as (delete from storage.objects where bucket_id = 'provider-claims' and name like '00000000-0000-0000-0000-000000000975/%' returning id) select to_jsonb(count(*)) from changed$$),
  '0'::jsonb, 'broad policy cannot authorize deleting evidence');
select extensions.is(
  pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000971', 'aal2',
    $$with changed as (update storage.objects set name = '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000979.pdf' where bucket_id = 'provider-claims' and name = '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000976.pdf' returning id) select to_jsonb(count(*)) from changed$$),
  '0'::jsonb, 'broad policy cannot rename evidence');
select extensions.throws_ok(
  $$select pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000971', 'aal2',
    $q$insert into storage.objects(bucket_id, name, owner_id) values ('provider-claims', '../escape.pdf', '00000000-0000-0000-0000-000000000971') returning to_jsonb(id)$q$)$$,
  '42501', null, 'malformed object paths are rejected');
select extensions.throws_ok(
  $$select pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000971', 'aal2',
    $q$insert into storage.objects(bucket_id, name, owner_id) values ('provider-claims', '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-00000000097A.pdf', '00000000-0000-0000-0000-000000000971') returning to_jsonb(id)$q$)$$,
  '42501', null, 'non-canonical mixed-case object paths are rejected');

insert into storage.objects(bucket_id, name, owner_id)
values ('provider-claims', '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000986.pdf', '00000000-0000-0000-0000-000000000971');
insert into storage.objects(bucket_id, name, owner_id)
values ('provider-claims', '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000987.pdf', '00000000-0000-0000-0000-000000000971');
insert into storage.objects(bucket_id, name, owner_id)
values ('provider-claims', '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000988.pdf', '00000000-0000-0000-0000-000000000971');
insert into storage.objects(bucket_id, name, owner_id)
values ('provider-claims', '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000989.pdf', '00000000-0000-0000-0000-000000000971');
insert into storage.objects(bucket_id, name, owner_id)
values ('provider-claims', '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000990.pdf', '00000000-0000-0000-0000-000000000971');
insert into storage.objects(bucket_id, name, owner_id)
values ('provider-claims', '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000991.pdf', '00000000-0000-0000-0000-000000000971');
insert into storage.objects(bucket_id, name, owner_id)
values ('provider-claims', '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000992.pdf', '00000000-0000-0000-0000-000000000971');
insert into storage.objects(bucket_id, name, owner_id)
values ('provider-claims', '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000993.pdf', '00000000-0000-0000-0000-000000000971');
select extensions.is(
  (select count(*)::integer from storage.objects where bucket_id = 'provider-claims' and name like '00000000-0000-0000-0000-000000000975/%'),
  10,
  'claimant can use at most ten evidence object slots'
);
select extensions.throws_ok(
  $$select pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000971', 'aal2',
    $q$insert into storage.objects(bucket_id, name, owner_id) values ('provider-claims', '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000994.pdf', '00000000-0000-0000-0000-000000000971') returning to_jsonb(id)$q$)$$,
  '42501', null, 'eleventh evidence object is rejected by the per-claim quota');
delete from storage.objects
where bucket_id = 'provider-claims'
  and name like '00000000-0000-0000-0000-000000000975/%'
  and name not in (
    '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000976.pdf',
    '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000977.png'
  );

delete from auth.mfa_factors where user_id = '00000000-0000-0000-0000-000000000971';
select extensions.is(
  pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000971', 'aal2',
    $$select to_jsonb(count(*)) from storage.objects where bucket_id = 'provider-claims' and name like '00000000-0000-0000-0000-000000000975/%'$$),
  '0'::jsonb, 'stale AAL2 without a current factor cannot read evidence');
select extensions.throws_ok(
  $$select pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000971', 'aal2',
    $q$insert into storage.objects(bucket_id, name, owner_id) values ('provider-claims', '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000982.pdf', '00000000-0000-0000-0000-000000000971') returning to_jsonb(id)$q$)$$,
  '42501', null, 'stale AAL2 without a current factor cannot upload evidence');

select extensions.is(
  pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000983', 'aal2',
    $$select to_jsonb(public.provider_can_access_claim_storage('00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000985.pdf'))$$),
  'false'::jsonb, 'anonymous identity cannot use provider Storage even with AAL2');

update identity.provider_claims set status = 'rejected' where id = '00000000-0000-0000-0000-000000000975';
select extensions.is(
  pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000971', 'aal2',
    $$select to_jsonb(count(*)) from storage.objects where bucket_id = 'provider-claims' and name like '00000000-0000-0000-0000-000000000975/%'$$),
  '0'::jsonb, 'closing a claim removes claimant read access');
select extensions.throws_ok(
  $$select pg_temp.storage_call('authenticated', '00000000-0000-0000-0000-000000000971', 'aal2',
    $q$insert into storage.objects(bucket_id, name, owner_id) values ('provider-claims', '00000000-0000-0000-0000-000000000975/00000000-0000-0000-0000-000000000980.pdf', '00000000-0000-0000-0000-000000000971') returning to_jsonb(id)$q$)$$,
  '42501', null, 'closed claims cannot receive new evidence');
select extensions.is(
  (select count(*)::integer from storage.objects where bucket_id = 'provider-claims' and name like '00000000-0000-0000-0000-000000000975/%'),
  2, 'only the two authorized fixture objects remain');

select * from extensions.finish();
rollback;
