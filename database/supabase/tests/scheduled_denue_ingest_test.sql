-- Contract for the Worker-only, source-gated DENUE RAW ingestion RPC.
begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(13);

select extensions.is(
  has_function_privilege('anon', 'public.api_system_ingest_denue_locations(text,jsonb)', 'execute'),
  false,
  'anonymous callers cannot ingest DENUE data'
);
select extensions.is(
  has_function_privilege('authenticated', 'public.api_system_ingest_denue_locations(text,jsonb)', 'execute'),
  false,
  'authenticated callers cannot ingest DENUE data'
);
select extensions.is(
  has_function_privilege('service_role', 'public.api_system_ingest_denue_locations(text,jsonb)', 'execute'),
  true,
  'only the Worker service role can invoke DENUE ingestion'
);
select extensions.is(
  (select count(*)::integer from ingest.sources s
   join ingest.source_endpoints se on se.source_id=s.id
   where s.name='INEGI DENUE' and s.source_type='government'
     and s.provider_brand_id is null and s.status='active'
     and s.usage_policy_status='approved'
     and se.name='INEGI DENUE collector endpoint' and se.endpoint_type='api'
     and se.url='https://www.inegi.org.mx/app/api/denue/v1/consulta' and se.status='active'),
  1,
  'the reviewed government source has one exact active API endpoint'
);

select extensions.is(
  (public.api_system_ingest_denue_locations(
    'denue-locations-2099-01-v1',
    jsonb_build_array(jsonb_build_object(
      'external_record_id','PRUEVIA_TEST_DENUE_001',
      'source_url','https://www.inegi.org.mx/app/api/denue/v1/consulta/Ficha/PRUEVIA_TEST_DENUE_001',
      'payload',jsonb_build_object('Id','PRUEVIA_TEST_DENUE_001','Nombre','Registro de contrato'),
      'observations',jsonb_build_array(
        jsonb_build_object('entity_type','provider_location','attribute_name','name','observed_value','Registro de contrato','status','candidate'),
        jsonb_build_object('entity_type','provider_location','attribute_name','coordinates','observed_value',jsonb_build_object('latitude',19.04,'longitude',-98.20),'status','candidate')
      )
    ))
  )->>'status'),
  'ingested',
  'one bounded monthly batch is ingested'
);
select extensions.is(
  (select records_published from ingest.crawl_runs cr
   where cr.metadata->>'request_key'='denue-locations-2099-01-v1'),
  0,
  'the scheduled collector publishes no canonical records'
);
select extensions.is(
  (select count(*)::integer from ingest.raw_records rr
   join ingest.crawl_runs cr on cr.id=rr.crawl_run_id
   where cr.metadata->>'request_key'='denue-locations-2099-01-v1'
     and rr.record_type='provider_location_discovered' and rr.parse_status='parsed'),
  1,
  'one parsed provider-location RAW record is retained'
);
select extensions.is(
  (select count(*)::integer from ingest.source_observations so
   join ingest.raw_records rr on rr.id=so.raw_record_id
   join ingest.crawl_runs cr on cr.id=rr.crawl_run_id
   where cr.metadata->>'request_key'='denue-locations-2099-01-v1'
     and so.entity_type='provider_location' and so.status='candidate'),
  2,
  'observations remain candidate location facts'
);
select extensions.is(
  (select count(*)::integer from ingest.normalization_runs nr
   join ingest.raw_records rr on rr.id=nr.raw_record_id
   join ingest.crawl_runs cr on cr.id=rr.crawl_run_id
   where cr.metadata->>'request_key'='denue-locations-2099-01-v1'),
  0,
  'directory locations do not enter clinical normalization'
);
select extensions.is(
  (public.api_system_ingest_denue_locations(
    'denue-locations-2099-01-v1',
    jsonb_build_array(jsonb_build_object(
      'external_record_id','PRUEVIA_TEST_DENUE_002',
      'source_url','https://www.inegi.org.mx/app/api/denue/v1/consulta/Ficha/PRUEVIA_TEST_DENUE_002',
      'payload',jsonb_build_object('Id','PRUEVIA_TEST_DENUE_002'),
      'observations',jsonb_build_array(
        jsonb_build_object('entity_type','provider_location','attribute_name','name','observed_value','No debe insertarse','status','candidate')
      )
    ))
  )->>'replayed')::boolean,
  true,
  'replaying the same request key is idempotent'
);
select extensions.is(
  (select count(*)::integer from ingest.crawl_runs cr
   where cr.metadata->>'request_key'='denue-locations-2099-01-v1'),
  1,
  'a replay does not create a second crawl run'
);
select extensions.is(
  (select count(*)::integer from ingest.raw_records rr
   join ingest.crawl_runs cr on cr.id=rr.crawl_run_id
   where cr.metadata->>'request_key'='denue-locations-2099-01-v1'),
  1,
  'a replay does not append a second raw record'
);
select extensions.throws_ok(
  $$select public.api_system_ingest_denue_locations(
    'denue-locations-2099-02-v1',
    jsonb_build_array(jsonb_build_object(
      'external_record_id','PRUEVIA_TEST_DENUE_BAD',
      'source_url','https://www.inegi.org.mx/app/api/denue/v1/consulta/Ficha/PRUEVIA_TEST_DENUE_BAD',
      'payload',jsonb_build_object('Id','PRUEVIA_TEST_DENUE_BAD'),
      'observations',jsonb_build_array(
        jsonb_build_object('entity_type','offer','attribute_name','price','observed_value',0,'status','accepted')
      )
    )))$$,
  'P0001',
  'DENUE observation failed validation',
  'the RPC rejects offers, prices, and accepted observations'
);

select * from extensions.finish();
rollback;
