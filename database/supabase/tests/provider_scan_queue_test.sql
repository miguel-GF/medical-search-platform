-- The scanner queue is private and bounded. Fixtures are rolled back.
begin;
-- Scanner behavior is tested independently from the internal-release freeze.
-- This test restores the freeze through its final rollback.
drop trigger if exists internal_document_write_freeze on identity.verification_documents;
create extension if not exists pgtap with schema extensions;
select extensions.plan(9);

insert into auth.users(id, aud, role, email, created_at, updated_at, is_sso_user, is_anonymous)
values ('00000000-0000-0000-0000-000000000981', 'authenticated', 'authenticated', 'queue-981@example.invalid', now(), now(), false, false);
insert into core.organizations(id, legal_name)
values ('00000000-0000-0000-0000-000000000982', 'Scan queue fixture');
insert into core.provider_brands(id, name, normalized_name, slug)
values ('00000000-0000-0000-0000-000000000983', 'Scan queue fixture', 'scan queue fixture', 'scan-queue-fixture');
insert into identity.provider_claims(id, claim_scope_type, provider_brand_id, organization_id, claimant_user_id, requested_role, relationship_type)
values ('00000000-0000-0000-0000-000000000984', 'brand', '00000000-0000-0000-0000-000000000983',
  '00000000-0000-0000-0000-000000000982', '00000000-0000-0000-0000-000000000981', 'brand_admin', 'owner');
insert into storage.objects(bucket_id, name, owner_id)
values ('provider-claims', '00000000-0000-0000-0000-000000000984/00000000-0000-0000-0000-000000000985.pdf', '00000000-0000-0000-0000-000000000981');
insert into identity.verification_documents(id, claim_id, submitted_by, document_type, object_key, sha256)
values ('00000000-0000-0000-0000-000000000986', '00000000-0000-0000-0000-000000000984', '00000000-0000-0000-0000-000000000981', 'rfc',
  'provider-claims/00000000-0000-0000-0000-000000000984/00000000-0000-0000-0000-000000000985.pdf', repeat('a', 64));

select extensions.has_function('public', 'api_server_document_scan_queue', array['integer'], 'private scan queue exists');
select extensions.is(has_function_privilege('anon', 'public.api_server_document_scan_queue(integer)', 'execute'), false, 'anon cannot call scan queue');
select extensions.is(has_function_privilege('authenticated', 'public.api_server_document_scan_queue(integer)', 'execute'), false, 'authenticated cannot call scan queue');
select extensions.is(has_function_privilege('service_role', 'public.api_server_document_scan_queue(integer)', 'execute'), true, 'service role can call scan queue');

create function pg_temp.queue_call(p_role text, p_sql text) returns jsonb
language plpgsql as $$
declare v_result jsonb;
begin
  execute format('set local role %I', p_role);
  execute p_sql into v_result;
  reset role;
  return v_result;
exception when others then reset role; raise;
end;
$$;
select extensions.is(pg_temp.queue_call('service_role', $$select to_jsonb(count(*)) from public.api_server_document_scan_queue(10)$$), '1'::jsonb, 'service role receives pending claim document');
select extensions.is((select scan_error_code from identity.verification_documents where id = '00000000-0000-0000-0000-000000000986'), 'scan_in_progress', 'queue atomically leases returned documents');
select extensions.is((select scan_attempts from identity.verification_documents where id = '00000000-0000-0000-0000-000000000986'), 1, 'queue lease consumes a bounded scan attempt');
select extensions.throws_ok($$select public.api_server_document_scan_queue(0)$$, 'P0001', 'Scan batch limit must be between 1 and 25', 'queue rejects an unbounded lower limit');
update identity.verification_documents set scanned_at = now(), scan_status = 'error', scan_attempts = 1 where id = '00000000-0000-0000-0000-000000000986';
select extensions.is(pg_temp.queue_call('service_role', $$select to_jsonb(count(*)) from public.api_server_document_scan_queue(10)$$), '0'::jsonb, 'recently attempted document is backoff protected');
select * from extensions.finish();
rollback;
