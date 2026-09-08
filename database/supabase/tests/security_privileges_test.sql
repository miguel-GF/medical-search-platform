-- Internal/admin RPCs must not be callable by Data API roles.
-- Run with:
-- npx.cmd supabase@2.116.0 db query --linked --file supabase/tests/security_privileges_test.sql

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(28);

select extensions.is(
  (select count(*)::integer
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'api_admin_%'),
  28,
  'all internal admin RPCs are present in the expected surface'
);

select extensions.is(
  (select count(*)::integer
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'api_admin_%'
     and has_function_privilege('anon', p.oid, 'execute')),
  0,
  'anonymous users cannot execute admin RPCs'
);

select extensions.is(
  (select count(*)::integer
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'api_admin_%'
     and has_function_privilege('authenticated', p.oid, 'execute')),
  0,
  'authenticated users cannot execute admin RPCs directly'
);

select extensions.is(
  (select count(*)::integer
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'api_admin_%'
     and has_function_privilege('service_role', p.oid, 'execute')),
  28,
  'service role can execute all admin RPCs'
);

select extensions.is(
  has_table_privilege('anon', 'identity.provider_claims', 'select'),
  false,
  'anonymous users cannot read provider claims directly'
);
select extensions.is(
  has_table_privilege('authenticated', 'identity.provider_claims', 'select'),
  false,
  'authenticated users cannot read provider claims directly'
);
select extensions.is(
  has_table_privilege('anon', 'ingest.raw_records', 'select'),
  false,
  'anonymous users cannot read raw ingest records directly'
);
select extensions.is(
  has_table_privilege('authenticated', 'ingest.raw_records', 'select'),
  false,
  'authenticated users cannot read raw ingest records directly'
);

select extensions.is(
  (select count(*)::integer
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('geo','core','catalog','health','supply','ingest','identity','audit',
                       'ops','analytics','marketplace','sensitive','billing')
     and p.prokind = 'f'
     and has_function_privilege('anon', p.oid, 'execute')),
  0,
  'anonymous users cannot execute internal helper functions'
);
select extensions.is(
  (select count(*)::integer
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('geo','core','catalog','health','supply','ingest','identity','audit',
                       'ops','analytics','marketplace','sensitive','billing')
     and p.prokind = 'f'
     and has_function_privilege('authenticated', p.oid, 'execute')),
  0,
  'authenticated users cannot execute internal helper functions'
);

select extensions.is(
  has_schema_privilege('anon', 'extensions', 'usage'),
  false,
  'anonymous users cannot use the extension schema directly'
);
select extensions.is(
  has_schema_privilege('authenticated', 'extensions', 'usage'),
  false,
  'authenticated users cannot use the extension schema directly'
);

select extensions.is(
  has_function_privilege('anon', 'public.api_record_analytics_event(text,uuid,jsonb)', 'execute'),
  false,
  'anonymous users cannot bypass Worker analytics abuse controls'
);
select extensions.is(
  has_function_privilege('authenticated', 'public.api_record_analytics_event(text,uuid,jsonb)', 'execute'),
  false,
  'authenticated users cannot bypass Worker analytics abuse controls'
);
select extensions.is(
  has_function_privilege('authenticated', 'public.provider_can_access_claim_storage(text)', 'execute'),
  true,
  'authenticated Storage reads use the provider ownership helper'
);
select extensions.is(
  has_function_privilege('authenticated', 'public.provider_can_upload_claim_storage(text)', 'execute'),
  true,
  'authenticated Storage uploads use the bounded ownership helper'
);
select extensions.is(
  has_function_privilege('anon', 'public.api_record_resolution_review(jsonb,text,text)', 'execute'),
  false,
  'anonymous users cannot submit review captures directly'
);
select extensions.is(
  has_function_privilege('authenticated', 'public.api_record_resolution_review(jsonb,text,text)', 'execute'),
  false,
  'authenticated users cannot submit review captures directly'
);
select extensions.is(
  has_function_privilege('anon', 'public.api_record_resolution_review(jsonb,text)', 'execute'),
  false,
  'anonymous users cannot call the compatibility review wrapper'
);
select extensions.is(
  has_function_privilege('authenticated', 'public.api_record_resolution_review(jsonb,text)', 'execute'),
  false,
  'authenticated users cannot call the compatibility review wrapper'
);
select extensions.is(
  (select count(*)::integer
   from information_schema.role_table_grants
   where table_schema = 'analytics'
     and table_name = 'anonymous_events'
     and grantee in ('anon', 'authenticated')),
  0,
  'analytics events are not directly readable or writable by Data API roles'
);

select extensions.is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('api_search','api_resolve_search','api_resolve_package','api_resolve_ocr_package',
                       'api_segment_package_text','api_record_analytics_event','api_service_detail','api_provider_detail')
     and has_function_privilege('anon', p.oid, 'execute')),
  0,
  'anonymous users cannot execute Worker-owned public RPCs directly'
);
select extensions.is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('api_search','api_resolve_search','api_resolve_package','api_resolve_ocr_package',
                       'api_segment_package_text','api_record_analytics_event','api_service_detail','api_provider_detail')
     and has_function_privilege('authenticated', p.oid, 'execute')),
  0,
  'authenticated users cannot execute Worker-owned public RPCs directly'
);
select extensions.is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('api_search','api_resolve_search','api_resolve_package','api_resolve_ocr_package',
                       'api_segment_package_text','api_record_analytics_event','api_service_detail','api_provider_detail')
     and has_function_privilege('service_role', p.oid, 'execute')),
  8,
  'only the Worker service role can execute all public API RPCs'
);

select extensions.is(
  has_function_privilege('anon', 'public.api_server_document_scan_queue(integer)', 'execute'),
  false,
  'anonymous users cannot obtain the private document scan queue'
);
select extensions.is(
  has_function_privilege('authenticated', 'public.api_server_document_scan_queue(integer)', 'execute'),
  false,
  'authenticated users cannot obtain the private document scan queue'
);
select extensions.is(
  has_function_privilege('service_role', 'public.api_server_document_scan_queue(integer)', 'execute'),
  true,
  'only the scanner service role can obtain the private document scan queue'
);
select extensions.is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'api_server_record_provider_document_scan'
     and pg_get_function_identity_arguments(p.oid) = 'uuid, text, text, integer, text'),
  0,
  'obsolete five-argument scan attestation cannot be called'
);

select * from extensions.finish();
rollback;
