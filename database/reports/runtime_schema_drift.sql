-- Read-only detail behind the runtime-schema gate mismatch.
select jsonb_build_object(
  'provider_wrappers', (
    select jsonb_agg(p.oid::regprocedure::text order by p.oid::regprocedure::text)
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'api_server_provider_%'
  ),
  'unexpected_authenticated_functions', (
    select jsonb_agg(p.oid::regprocedure::text order by p.oid::regprocedure::text)
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and has_function_privilege('authenticated', p.oid, 'execute')
      and p.oid not in (
        to_regprocedure('public.provider_can_access_claim_storage(text)'),
        to_regprocedure('public.provider_can_upload_claim_storage(text)')
      )
  ),
  'document_freeze_policies', (
    select jsonb_agg(jsonb_build_object(
      'name', polname, 'permissive', polpermissive, 'command', polcmd,
      'using', pg_get_expr(polqual, polrelid),
      'check', pg_get_expr(polwithcheck, polrelid)
    ))
    from pg_policy where polrelid = 'storage.objects'::regclass
      and polname like '%provider%freeze%'
  )
) as drift;

select enabled, documents_enabled, public.provider_documents_open() as effective_documents_open
from identity.provider_intake_settings;
