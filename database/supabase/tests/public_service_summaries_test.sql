begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(8);

select extensions.has_column(
  'catalog',
  'item_descriptions',
  'source_url',
  'clinical descriptions retain a public source URL'
);
select extensions.has_function(
  'public',
  'api_service_summaries',
  array['uuid[]', 'text'],
  'bounded service summary RPC exists'
);
select extensions.is(
  (select count(*)::bigint from catalog.item_descriptions
   where description_type = 'clinical' and status = 'approved'
     and item_id between '00000000-0000-0000-0000-000000001101'::uuid
                     and '00000000-0000-0000-0000-000000001113'::uuid),
  13::bigint,
  'the initial reviewed catalog has thirteen summaries'
);
select extensions.ok(
  (select description like 'Mide la cantidad%'
   from public.api_service_summaries(
     array['00000000-0000-0000-0000-000000001103'::uuid],
     'es-MX'
   )),
  'biometria hematica exposes its reviewed summary'
);
select extensions.ok(
  (select source_url ~ '^https://medlineplus\.gov/'
   from public.api_service_summaries(
     array['00000000-0000-0000-0000-000000001103'::uuid],
     'es-MX'
   )),
  'the public summary retains an HTTPS MedlinePlus source'
);
select extensions.is(
  (select count(*)::bigint
   from public.api_service_summaries(
     array_fill('00000000-0000-0000-0000-000000001103'::uuid, array[101]),
     'es-MX'
   )),
  0::bigint,
  'oversized summary requests fail closed with no rows'
);
select extensions.ok(
  not has_function_privilege('anon', 'public.api_service_summaries(uuid[],text)', 'execute'),
  'anonymous clients cannot bypass the Worker summary boundary'
);
select extensions.ok(
  has_function_privilege('service_role', 'public.api_service_summaries(uuid[],text)', 'execute'),
  'the Worker service role can read approved summaries'
);

select * from extensions.finish();
rollback;
