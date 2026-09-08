begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(5);

select extensions.throws_ok(
  'insert into identity.verification_documents select * from identity.verification_documents where false',
  '42501', 'provider_documents_disabled', 'document insertion is closed even for trusted SQL callers'
);
select extensions.throws_ok(
  'update identity.verification_documents set status = status where false',
  '42501', 'provider_documents_disabled', 'document approval and scan updates are closed'
);
select extensions.ok(
  exists (select 1 from pg_policy where polrelid = 'storage.objects'::regclass
    and polname = 'provider_documents_internal_freeze' and not polpermissive and polcmd = '*'
    and polroles @> array['anon'::regrole::oid, 'authenticated'::regrole::oid]
    and pg_get_expr(polqual, polrelid) = '(bucket_id <> ''provider-claims''::text)'
    and pg_get_expr(polwithcheck, polrelid) = '(bucket_id <> ''provider-claims''::text)'),
  'direct client Storage access is closed only for the evidence bucket'
);
select extensions.is(
  has_function_privilege('authenticated', 'core.reject_internal_document_write()', 'execute'),
  false, 'authenticated clients cannot execute the trigger function'
);
select extensions.is(
  has_function_privilege('anon', 'core.reject_internal_document_write()', 'execute'),
  false, 'anonymous clients cannot execute the trigger function'
);
select * from extensions.finish();
rollback;
