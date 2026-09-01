-- Internal/admin RPCs must not be callable by Data API roles.
-- Run with:
-- npx.cmd supabase@latest db query --linked --file supabase/tests/security_privileges_test.sql

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(8);

select extensions.is(
  (select count(*)::integer
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'api_admin_%'),
  16,
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
  16,
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

select * from extensions.finish();
rollback;
