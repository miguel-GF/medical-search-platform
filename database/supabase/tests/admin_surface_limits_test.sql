-- Operational alert payloads must be bounded at write time and at the Admin
-- read boundary. The transaction is rolled back, so fixtures do not persist.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(4);

select extensions.throws_ok(
  $$insert into ops.system_alerts(alert_code, severity, title, detail)
    values ('limit_detail', 'warning', 'bounded', repeat('x', 65537))$$,
  'P0001',
  'System alert detail exceeds 65536 characters',
  'alert detail is bounded at write time'
);
select extensions.throws_ok(
  $$insert into ops.system_alerts(alert_code, severity, title, metadata)
    values ('limit_metadata', 'warning', 'bounded', jsonb_build_object('blob', repeat('x', 65537)))$$,
  'P0001',
  'System alert metadata exceeds 65536 bytes',
  'alert metadata is bounded at write time'
);
select extensions.throws_ok(
  $$insert into ops.system_alerts(alert_code, severity, title)
    values ('limit_title', 'warning', repeat('x', 501))$$,
  'P0001',
  'System alert title exceeds 500 characters',
  'alert title is bounded at write time'
);

insert into ops.system_alerts(id, alert_code, severity, title, detail)
values ('00000000-0000-0000-0000-000000001371', 'bounded_detail', 'warning', 'bounded', repeat('x', 10000));
select extensions.is(
  (select length(detail)::integer from public.api_admin_alerts(null, 200) where alert_id = '00000000-0000-0000-0000-000000001371'),
  8192,
  'Admin alert detail is bounded in the response'
);

select * from extensions.finish();
rollback;
