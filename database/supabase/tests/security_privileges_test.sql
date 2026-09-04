-- Internal/admin RPCs must not be callable by Data API roles.
-- Run with:
-- npx.cmd supabase@latest db query --linked --file supabase/tests/security_privileges_test.sql

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(19);

select extensions.is(
  (select count(*)::integer
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'api_admin_%'),
  26,
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
  26,
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
  true,
  'anonymous users may submit only the constrained analytics RPC'
);
select extensions.is(
  has_function_privilege('authenticated', 'public.api_record_analytics_event(text,uuid,jsonb)', 'execute'),
  true,
  'authenticated users may submit only the constrained analytics RPC'
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

select * from extensions.finish();
rollback;
