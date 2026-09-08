-- Admin audit events must not be forgeable with a nonexistent reviewer.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(4);

select extensions.throws_ok(
  $$insert into audit.events(actor_type, actor_user_id, action)
    values ('admin', '00000000-0000-0000-0000-000000000997', 'security.test')$$,
  'P0001', 'Admin actor is required',
  'admin audit events reject nonexistent actors'
);
select extensions.throws_ok(
  $$insert into audit.events(actor_type, action)
    values ('admin', 'security.test')$$,
  'P0001', 'Admin actor is required',
  'admin audit events reject a missing actor'
);

insert into auth.users(id, aud, role, email, created_at, updated_at, is_sso_user, is_anonymous)
values ('00000000-0000-0000-0000-000000000996', 'authenticated', 'authenticated',
        'audit-admin-996@example.invalid', now(), now(), false, false)
on conflict (id) do nothing;
select extensions.lives_ok(
  $$insert into audit.events(actor_type, actor_user_id, action)
    values ('admin', '00000000-0000-0000-0000-000000000996', 'security.test')$$,
  'admin audit events accept an existing Auth actor'
);
select extensions.lives_ok(
  $$insert into audit.events(actor_type, action)
    values ('system', 'security.test')$$,
  'non-admin system events retain nullable actors'
);

select * from extensions.finish();
rollback;
