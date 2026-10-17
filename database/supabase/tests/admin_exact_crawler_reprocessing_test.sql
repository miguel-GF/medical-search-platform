-- Scheduled exact reprocessing is limited to approved, successful crawler
-- evidence. Fixtures and writes are rolled back by the SQL contract runner.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(26);

select extensions.has_function(
  'ingest', 'admin_exact_approved_crawler_matches', array[]::text[],
  'approved crawler matcher exists separately from the interactive matcher'
);
select extensions.has_function(
  'public', 'api_admin_reprocess_exact_crawler_normalizations',
  array['uuid', 'integer', 'boolean', 'text'],
  'scheduled crawler batch has bounded typed controls'
);
select extensions.has_function(
  'ingest', 'admin_materialize_approved_crawler_normalizations', array['integer'],
  'approved offer evidence has a bounded normalization queue materializer'
);
select extensions.is(
  has_function_privilege('anon', 'ingest.admin_materialize_approved_crawler_normalizations(integer)', 'execute'),
  false, 'anon cannot materialize crawler normalization rows'
);
select extensions.is(
  has_function_privilege('authenticated', 'ingest.admin_materialize_approved_crawler_normalizations(integer)', 'execute'),
  false, 'authenticated cannot materialize crawler normalization rows'
);
select extensions.is(
  has_function_privilege('service_role', 'ingest.admin_materialize_approved_crawler_normalizations(integer)', 'execute'),
  true, 'only the Worker service role can materialize crawler normalization rows'
);
select extensions.is(
  has_function_privilege('anon', 'public.api_admin_reprocess_exact_crawler_normalizations(uuid,integer,boolean,text)', 'execute'),
  false, 'anon cannot call scheduled crawler batch'
);
select extensions.is(
  has_function_privilege('authenticated', 'public.api_admin_reprocess_exact_crawler_normalizations(uuid,integer,boolean,text)', 'execute'),
  false, 'authenticated cannot call scheduled crawler batch'
);
select extensions.is(
  has_function_privilege('service_role', 'public.api_admin_reprocess_exact_crawler_normalizations(uuid,integer,boolean,text)', 'execute'),
  true, 'only the Worker service role can call scheduled crawler batch'
);

insert into auth.users(id, aud, role, email, created_at, updated_at, is_sso_user, is_anonymous)
values ('00000000-0000-0000-0000-000000009950', 'authenticated', 'authenticated',
        'crawler-exact-test@example.invalid', now(), now(), false, false)
on conflict (id) do nothing;
insert into core.provider_brands(id, name, normalized_name, slug)
values ('00000000-0000-0000-0000-000000009951', 'Crawler Exact Fixture',
        'crawler exact fixture', 'crawler-exact-fixture');
insert into catalog.items(id, domain_id, item_type, status)
select '00000000-0000-0000-0000-000000009952', id, 'service', 'active'
from catalog.domains where code = 'health_diagnostics';
insert into catalog.item_names(item_id, name, normalized_name, is_primary)
values ('00000000-0000-0000-0000-000000009952',
        'Scheduled Exact Fixture', 'scheduled exact fixture', true);
insert into health.services(catalog_item_id, service_type)
values ('00000000-0000-0000-0000-000000009952', 'lab_test');

insert into ingest.sources(id, name, source_type, provider_brand_id, usage_policy_status)
values
  ('00000000-0000-0000-0000-000000009953', 'Approved crawler fixture',
   'provider_official', '00000000-0000-0000-0000-000000009951', 'approved'),
  ('00000000-0000-0000-0000-000000009954', 'Unreviewed crawler fixture',
   'provider_official', '00000000-0000-0000-0000-000000009951', 'review_required'),
  ('00000000-0000-0000-0000-000000009955', 'Public website crawler fixture',
   'public_website', '00000000-0000-0000-0000-000000009951', 'approved');
insert into ingest.source_endpoints(id, source_id, name, endpoint_type, url)
values
  ('00000000-0000-0000-0000-000000009956', '00000000-0000-0000-0000-000000009953',
   'Approved endpoint', 'html', 'https://example.invalid/approved'),
  ('00000000-0000-0000-0000-000000009957', '00000000-0000-0000-0000-000000009954',
   'Unreviewed endpoint', 'html', 'https://example.invalid/unreviewed'),
  ('00000000-0000-0000-0000-000000009958', '00000000-0000-0000-0000-000000009955',
   'Public endpoint', 'html', 'https://example.invalid/public');
insert into ingest.crawl_runs(id, source_endpoint_id, status, started_at, finished_at)
values
  ('00000000-0000-0000-0000-000000009959', '00000000-0000-0000-0000-000000009956',
   'succeeded', '1900-01-01T00:00:00Z', '1900-01-01T00:00:01Z'),
  ('00000000-0000-0000-0000-000000009960', '00000000-0000-0000-0000-000000009957',
   'succeeded', '1900-01-01T00:00:00Z', '1900-01-01T00:00:01Z'),
  ('00000000-0000-0000-0000-000000009961', '00000000-0000-0000-0000-000000009958',
   'succeeded', '1900-01-01T00:00:00Z', '1900-01-01T00:00:01Z');
insert into ingest.raw_records(
  id, crawl_run_id, source_id, external_record_id, record_type,
  payload, record_hash, parse_status
)
values
  ('00000000-0000-0000-0000-000000009962', '00000000-0000-0000-0000-000000009959',
   '00000000-0000-0000-0000-000000009953', 'approved-1', 'catalog_item',
   '{"provider_sku":"approved-1"}'::jsonb, repeat('a', 64), 'parsed'),
  ('00000000-0000-0000-0000-000000009963', '00000000-0000-0000-0000-000000009960',
   '00000000-0000-0000-0000-000000009954', 'unreviewed-1', 'catalog_item',
   '{"provider_sku":"unreviewed-1"}'::jsonb, repeat('b', 64), 'parsed'),
  ('00000000-0000-0000-0000-000000009964', '00000000-0000-0000-0000-000000009961',
   '00000000-0000-0000-0000-000000009955', 'public-1', 'catalog_item',
   '{"provider_sku":"public-1"}'::jsonb, repeat('c', 64), 'parsed'),
  ('00000000-0000-0000-0000-000000009970', '00000000-0000-0000-0000-000000009959',
   '00000000-0000-0000-0000-000000009953', 'approved-offer-1', 'provider_offer_price',
   '{"provider_display_name":"Scheduled Exact Fixture"}'::jsonb, repeat('d', 64), 'parsed'),
  ('00000000-0000-0000-0000-000000009971', '00000000-0000-0000-0000-000000009960',
   '00000000-0000-0000-0000-000000009954', 'unreviewed-offer-1', 'provider_offer_price',
   '{"provider_display_name":"Scheduled Exact Fixture"}'::jsonb, repeat('e', 64), 'parsed'),
  ('00000000-0000-0000-0000-000000009972', '00000000-0000-0000-0000-000000009959',
   '00000000-0000-0000-0000-000000009953', 'location-only-1', 'provider_offer_discovered',
   '{"provider_display_name":"Scheduled Exact Fixture"}'::jsonb, repeat('f', 64), 'parsed');
insert into ingest.source_observations(
  source_id, raw_record_id, entity_type, attribute_name, observed_value, status
)
values
  ('00000000-0000-0000-0000-000000009953', '00000000-0000-0000-0000-000000009970',
   'offer', 'provider_display_name', to_jsonb('Scheduled Exact Fixture'::text), 'candidate'),
  ('00000000-0000-0000-0000-000000009954', '00000000-0000-0000-0000-000000009971',
   'offer', 'provider_display_name', to_jsonb('Scheduled Exact Fixture'::text), 'candidate'),
  ('00000000-0000-0000-0000-000000009953', '00000000-0000-0000-0000-000000009972',
   'provider_location', 'provider_display_name', to_jsonb('Scheduled Exact Fixture'::text), 'candidate');
insert into ingest.normalization_runs(
  id, input_type, raw_record_id, provider_brand_id,
  raw_text, normalized_input, engine_version, status, created_at
)
values
  ('00000000-0000-0000-0000-000000009965', 'crawler', '00000000-0000-0000-0000-000000009962',
   '00000000-0000-0000-0000-000000009951', 'Scheduled Exact Fixture',
   'scheduled exact fixture', 'test', 'no_match', '1900-01-01T00:00:00Z'),
  ('00000000-0000-0000-0000-000000009966', 'crawler', '00000000-0000-0000-0000-000000009963',
   '00000000-0000-0000-0000-000000009951', 'Scheduled Exact Fixture',
   'scheduled exact fixture', 'test', 'no_match', '1900-01-01T00:00:01Z'),
  ('00000000-0000-0000-0000-000000009967', 'crawler', '00000000-0000-0000-0000-000000009964',
   '00000000-0000-0000-0000-000000009951', 'Scheduled Exact Fixture',
   'scheduled exact fixture', 'test', 'no_match', '1900-01-01T00:00:02Z'),
  ('00000000-0000-0000-0000-000000009968', 'search', null,
   '00000000-0000-0000-0000-000000009951', 'Scheduled Exact Fixture',
   'scheduled exact fixture', 'test', 'no_match', '1900-01-01T00:00:03Z'),
  ('00000000-0000-0000-0000-000000009969', 'crawler', null,
   '00000000-0000-0000-0000-000000009951', 'Scheduled Exact Fixture',
   'scheduled exact fixture', 'test', 'no_match', '1900-01-01T00:00:04Z');

select extensions.is(
  (select count(*)::bigint from ingest.admin_exact_approved_crawler_matches()
   where normalization_run_id between '00000000-0000-0000-0000-000000009965'::uuid
                                  and '00000000-0000-0000-0000-000000009969'::uuid),
  1::bigint, 'only the approved, sourced crawler row is eligible'
);
select extensions.is(
  (select count(*)::bigint from ingest.admin_exact_normalization_matches()
   where normalization_run_id between '00000000-0000-0000-0000-000000009965'::uuid
                                  and '00000000-0000-0000-0000-000000009969'::uuid),
  5::bigint, 'interactive matcher remains broad; scheduler has a separate gate'
);
select extensions.throws_ok(
  $$select public.api_admin_reprocess_exact_crawler_normalizations(
    '00000000-0000-0000-0000-000000009950', 1, true, null
  )$$,
  'P0001', 'Request id is required for scheduled apply',
  'scheduled apply requires an idempotency key'
);
select extensions.is(
  (public.api_admin_reprocess_exact_crawler_normalizations(
    '00000000-0000-0000-0000-000000009950', 1, false, null
  )->>'processed')::bigint,
  0::bigint, 'preview does not write'
);
select extensions.is(
  (public.api_admin_reprocess_exact_crawler_normalizations(
    '00000000-0000-0000-0000-000000009950', 1, false, null
  )->>'materialized')::bigint,
  0::bigint, 'preview does not materialize new offers'
);
select extensions.is(
  (select count(*)::bigint from ingest.normalization_runs
   where raw_record_id = '00000000-0000-0000-0000-000000009970'),
  0::bigint, 'preview leaves the new offer outside the normalization queue'
);
select extensions.is(
  (public.api_admin_reprocess_exact_crawler_normalizations(
    '00000000-0000-0000-0000-000000009950', 2, true, 'crawler-fixture-apply'
  )->>'materialized')::bigint,
  1::bigint, 'apply enqueues the approved offer evidence'
);
select extensions.is(
  (public.api_admin_reprocess_exact_crawler_normalizations(
    '00000000-0000-0000-0000-000000009950', 2, true, 'crawler-fixture-apply'
  )->>'processed')::bigint,
  2::bigint, 'apply resolves existing and newly materialized exact crawler fixtures'
);
select extensions.is(
  (select status from ingest.normalization_runs where id = '00000000-0000-0000-0000-000000009965'),
  'resolved', 'approved crawler fixture is resolved'
);
select extensions.is(
  (select status from ingest.normalization_runs
   where raw_record_id = '00000000-0000-0000-0000-000000009970'),
  'resolved', 'new approved offer enters and is resolved by exact normalization'
);
select extensions.is(
  (select count(*)::bigint from ingest.normalization_decisions
   where normalization_run_id = '00000000-0000-0000-0000-000000009965'
     and decision_type = 'automatic'),
  1::bigint, 'approved crawler fixture has one automatic decision'
);
select extensions.is(
  (select count(*)::bigint from audit.events
   where action = 'normalization.exact_crawler_reprocess'
     and entity_id = '00000000-0000-0000-0000-000000009965'),
  1::bigint, 'scheduled decision has a per-run audit event'
);
select extensions.is(
  (public.api_admin_reprocess_exact_crawler_normalizations(
    '00000000-0000-0000-0000-000000009950', 2, true, 'crawler-fixture-apply'
  )->>'replayed')::boolean,
  true, 'retry replays the original batch result'
);
select extensions.is(
  (select count(*)::bigint from ingest.normalization_decisions
   where normalization_run_id = '00000000-0000-0000-0000-000000009965'),
  1::bigint, 'retry does not duplicate the decision'
);
select extensions.is(
  (select count(*)::bigint from ingest.normalization_runs
   where id between '00000000-0000-0000-0000-000000009966'::uuid
                and '00000000-0000-0000-0000-000000009969'::uuid
     and status = 'no_match'),
  4::bigint, 'unreviewed, public-site, search and unsourced rows remain open'
);
select extensions.is(
  (select count(*)::bigint from ingest.normalization_runs
   where raw_record_id in (
     '00000000-0000-0000-0000-000000009971',
     '00000000-0000-0000-0000-000000009972'
   )),
  0::bigint, 'unreviewed provider data and location-only labels are not materialized'
);
update ingest.sources set usage_policy_status = 'approved'
where id = '00000000-0000-0000-0000-000000009954';
select extensions.is(
  (select count(*)::bigint from ingest.admin_exact_approved_crawler_matches()
   where normalization_run_id = '00000000-0000-0000-0000-000000009966'),
  1::bigint, 'source policy change is reflected in the preview gate'
);

select * from extensions.finish();
rollback;
