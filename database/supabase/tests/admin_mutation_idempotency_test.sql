-- Admin status mutations must be safe when the client retries after a lost
-- response. The transaction is rolled back, so fixtures do not persist.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(6);

insert into auth.users(id, aud, role, email, created_at, updated_at, is_sso_user, is_anonymous)
values ('00000000-0000-0000-0000-000000000999', 'authenticated', 'authenticated', 'admin-review-test@example.invalid', now(), now(), false, false)
on conflict (id) do nothing;

insert into ops.system_alerts(id, alert_code, severity, status, title, detail)
values ('00000000-0000-0000-0000-000000001361', 'test_idempotency', 'warning', 'open', 'Idempotency fixture', 'pgtap');

select extensions.is(
  (public.api_admin_update_alert_status(
    '00000000-0000-0000-0000-000000001361', 'acknowledged', null,
    '00000000-0000-0000-0000-000000000999', 'admin-alert-1361'
  )->>'status'),
  'acknowledged',
  'alert status mutation succeeds'
);
select extensions.is(
  (public.api_admin_update_alert_status(
    '00000000-0000-0000-0000-000000001361', 'acknowledged', null,
    '00000000-0000-0000-0000-000000000999', 'admin-alert-1361'
  )->>'status'),
  'acknowledged',
  'alert status retry returns the committed result'
);
select extensions.throws_ok(
  $$select public.api_admin_update_alert_status(
    '00000000-0000-0000-0000-000000001361', 'resolved', null,
    '00000000-0000-0000-0000-000000000999', 'admin-alert-1361'
  )$$,
  'P0001',
  'Request id was already used for another operation',
  'alert request id cannot be reused for another status'
);

insert into ingest.data_quality_issues(id, issue_code, severity, status, details)
values ('00000000-0000-0000-0000-000000001362', 'test_idempotency', 'warning', 'open', '{}'::jsonb);

select extensions.is(
  (public.api_admin_update_quality_issue_status(
    '00000000-0000-0000-0000-000000001362', 'acknowledged', null,
    '00000000-0000-0000-0000-000000000999', 'admin-quality-1362'
  )->>'status'),
  'acknowledged',
  'quality issue status mutation succeeds'
);
select extensions.is(
  (public.api_admin_update_quality_issue_status(
    '00000000-0000-0000-0000-000000001362', 'acknowledged', null,
    '00000000-0000-0000-0000-000000000999', 'admin-quality-1362'
  )->>'status'),
  'acknowledged',
  'quality issue status retry returns the committed result'
);
select extensions.throws_ok(
  $$select public.api_admin_update_quality_issue_status(
    '00000000-0000-0000-0000-000000001362', 'resolved', null,
    '00000000-0000-0000-0000-000000000999', 'admin-quality-1362'
  )$$,
  'P0001',
  'Request id was already used for another operation',
  'quality request id cannot be reused for another status'
);

select * from extensions.finish();
rollback;
