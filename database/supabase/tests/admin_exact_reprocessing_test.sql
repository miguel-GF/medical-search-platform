-- Exact normalization reprocessing must resolve only a unique, approved
-- catalog match and remain safe on retries. Every fixture is rolled back.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(20);

select extensions.has_function(
  'public',
  'api_admin_reprocess_exact_normalizations',
  array['uuid','integer','boolean','text'],
  'exact normalization batch RPC exists with typed controls'
);
select extensions.has_function(
  'ingest',
  'admin_exact_normalization_matches',
  array[]::text[],
  'exact normalization matcher is an internal helper'
);

insert into auth.users(id, aud, role, email, created_at, updated_at, is_sso_user, is_anonymous)
values (
  '00000000-0000-0000-0000-000000009910', 'authenticated', 'authenticated',
  'admin-exact-test@example.invalid', now(), now(), false, false
)
on conflict (id) do nothing;

select extensions.throws_ok(
  $$select public.api_admin_reprocess_exact_normalizations(
    '00000000-0000-0000-0000-000000009910', 0, false, null
  )$$,
  'P0001',
  'Limit must be between 1 and 200',
  'batch limit is bounded'
);
select extensions.throws_ok(
  $$select public.api_admin_reprocess_exact_normalizations(
    null, 1, false, null
  )$$,
  'P0001',
  'Reviewer is required',
  'reviewer identity is mandatory'
);

create temporary table exact_reprocess_baseline as
select
  (select count(*)::bigint
   from ingest.normalization_runs nr
   where nr.status in ('pending', 'ambiguous', 'no_match')
     and not exists (
       select 1 from ingest.normalization_decisions nd
       where nd.normalization_run_id = nr.id
         and nd.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
     )) as backlog,
  (select count(*)::bigint from ingest.admin_exact_normalization_matches()) as eligible;

insert into catalog.items(id, domain_id, item_type, status)
select '00000000-0000-0000-0000-000000009911', id, 'service', 'active'
from catalog.domains where code = 'health_diagnostics';
insert into catalog.item_names(item_id, name, normalized_name, is_primary)
values ('00000000-0000-0000-0000-000000009911', 'Exact Reprocess Fixture', 'exact reprocess fixture', true);
insert into health.services(catalog_item_id, service_type)
values ('00000000-0000-0000-0000-000000009911', 'lab_test');

insert into ingest.normalization_runs(id, input_type, raw_text, normalized_input, engine_version, status, created_at)
values
  ('00000000-0000-0000-0000-000000009912', 'crawler', 'Exact Reprocess Fixture', 'exact reprocess fixture', 'test', 'no_match', '1970-01-01T00:00:00Z'),
  ('00000000-0000-0000-0000-000000009913', 'search', 'Uncovered Reprocess Fixture', 'uncovered reprocess fixture', 'test', 'ambiguous', '1970-01-01T00:00:01Z'),
  ('00000000-0000-0000-0000-000000009914', 'crawler', 'Closed Reprocess Fixture', 'closed reprocess fixture', 'test', 'no_match', '1970-01-01T00:00:02Z');
insert into ingest.normalization_decisions(normalization_run_id, decision_type, reviewer_user_id, reason)
values (
  '00000000-0000-0000-0000-000000009914', 'no_match',
  '00000000-0000-0000-0000-000000009910', 'Already closed fixture'
);

select extensions.is(
  (public.api_admin_reprocess_exact_normalizations(
    '00000000-0000-0000-0000-000000009910', 1, false, 'exact-preview-9912'
  )->>'backlog_total')::bigint,
  (select backlog + 2 from exact_reprocess_baseline),
  'preview counts only open normalization runs'
);
select extensions.is(
  (public.api_admin_reprocess_exact_normalizations(
    '00000000-0000-0000-0000-000000009910', 1, false, 'exact-preview-9912'
  )->>'eligible_total')::bigint,
  (select eligible + 1 from exact_reprocess_baseline),
  'preview selects only a unique exact catalog match'
);
select extensions.is(
  (public.api_admin_reprocess_exact_normalizations(
    '00000000-0000-0000-0000-000000009910', 1, false, 'exact-preview-9912'
  )->>'processed')::bigint,
  0::bigint,
  'preview does not write data'
);

select extensions.is(
  (public.api_admin_reprocess_exact_normalizations(
    '00000000-0000-0000-0000-000000009910', 1, true, 'exact-apply-9912'
  )->>'processed')::bigint,
  1::bigint,
  'apply resolves the selected exact match'
);
select extensions.is(
  (select status from ingest.normalization_runs where id = '00000000-0000-0000-0000-000000009912'),
  'resolved',
  'exact match marks the run resolved'
);
select extensions.is(
  (select decision_type from ingest.normalization_decisions where normalization_run_id = '00000000-0000-0000-0000-000000009912'),
  'automatic',
  'exact match records an automatic decision'
);
select extensions.is(
  (select method from ingest.normalization_candidates where normalization_run_id = '00000000-0000-0000-0000-000000009912'),
  'exact',
  'exact match records its non-fuzzy method'
);
select extensions.is(
  (select score from ingest.normalization_candidates where normalization_run_id = '00000000-0000-0000-0000-000000009912'),
  1.00000::numeric,
  'exact match records full confidence'
);
select extensions.is(
  (select status from ingest.normalization_runs where id = '00000000-0000-0000-0000-000000009913'),
  'ambiguous',
  'uncovered ambiguous input remains open'
);
select extensions.is(
  (select status from ingest.normalization_runs where id = '00000000-0000-0000-0000-000000009914'),
  'no_match',
  'previously closed no_match remains unchanged'
);
select extensions.is(
  (select count(*)::bigint from ingest.normalization_decisions where normalization_run_id = '00000000-0000-0000-0000-000000009914'),
  1::bigint,
  'previously closed decision is not duplicated'
);

select extensions.is(
  (public.api_admin_reprocess_exact_normalizations(
    '00000000-0000-0000-0000-000000009910', 1, true, 'exact-apply-9912'
  )->>'replayed')::boolean,
  true,
  'repeating an apply request returns the original result'
);
select extensions.is(
  (select count(*)::bigint from ingest.normalization_decisions where normalization_run_id = '00000000-0000-0000-0000-000000009912'),
  1::bigint,
  'replaying an apply request does not duplicate the decision'
);
select extensions.is(
  (select count(*)::bigint from audit.events where action = 'normalization.exact_reprocess' and entity_id = '00000000-0000-0000-0000-000000009912'),
  1::bigint,
  'exact resolution writes one per-run audit event'
);
select extensions.is(
  (select count(*)::bigint from audit.events where action = 'normalization.exact_reprocess_batch' and request_id = 'exact-apply-9912'),
  1::bigint,
  'exact batch writes one idempotency audit event'
);
select extensions.is(
  (public.api_admin_reprocess_exact_normalizations(
    '00000000-0000-0000-0000-000000009910', 200, false, null
  )->>'remaining_eligible')::bigint,
  (select eligible from exact_reprocess_baseline),
  'after apply no exact eligible rows remain'
);

select * from extensions.finish();
rollback;
