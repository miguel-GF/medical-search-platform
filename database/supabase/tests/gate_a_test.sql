-- Gate A evidence tests for the Puebla data engine.
-- Read-only assertions; run against the linked DEV database after ingestion.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(10);

select extensions.ok(
  (select count(*) between 100 and 200 from catalog.items where status = 'active'),
  'golden catalog contains 100-200 active services'
);
select extensions.ok(
  (select count(*) >= 100 from supply.offers where status = 'active'),
  'commercial catalog has at least 100 active offers'
);
select extensions.ok(
  (select count(*) >= 2 from core.provider_brands where status <> 'closed'),
  'at least two provider brands are represented'
);
select extensions.ok(
  (select count(*) > 0 from supply.price_versions where is_current),
  'current prices are available'
);
select extensions.is(
  (select count(*)::bigint from supply.price_versions where is_current and amount_minor <= 0),
  0::bigint,
  'unavailable zero prices never reach search'
);
select extensions.ok(
  (select count(*) >= 100 from ingest.normalization_runs where status = 'resolved'),
  'at least 100 normalization decisions are resolved'
);
select extensions.ok(
  (select count(*) > 0 from ingest.normalization_runs where status = 'no_match'),
  'unmatched labels remain explicitly reviewable'
);
select extensions.is(
  (select count(distinct provider_name)::bigint from public.api_search('mastografia unilateral', 'health_diagnostics', 19.0433, -98.2011, null, 100)),
  2::bigint,
  'search returns both commercial providers for a shared exact service'
);
select extensions.ok(
  (select exists(select 1 from ingest.crawl_runs cr join ingest.source_endpoints se on se.id = cr.source_endpoint_id join ingest.sources s on s.id = se.source_id where s.name like 'Laboratorios Ruiz%' and cr.status = 'succeeded')),
  'Ruiz Puebla has a successful published crawl'
);
select extensions.ok(
  (select exists(select 1 from ingest.crawl_runs cr join ingest.source_endpoints se on se.id = cr.source_endpoint_id join ingest.sources s on s.id = se.source_id where s.name like 'Laboratorio Médico del Chopo%' and cr.status = 'succeeded')),
  'Chopo Puebla has a successful published crawl'
);

select * from extensions.finish();
rollback;
