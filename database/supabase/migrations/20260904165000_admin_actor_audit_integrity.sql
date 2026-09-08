-- Every audit event labelled as an Admin action must identify a real Auth
-- user. This protects the audit trail even when a service-only RPC receives a
-- malformed or stale reviewer UUID from an internal caller.

begin;

create or replace function audit.require_admin_actor()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, auth
as $$
begin
  if new.actor_type = 'admin'
     and (new.actor_user_id is null or not exists (
       select 1 from auth.users where id = new.actor_user_id
     )) then
    raise exception 'Admin actor is required';
  end if;
  return new;
end;
$$;

revoke all on function audit.require_admin_actor() from public, anon, authenticated, service_role;

drop trigger if exists trg_audit_events_require_admin_actor on audit.events;
create trigger trg_audit_events_require_admin_actor
before insert or update of actor_type, actor_user_id on audit.events
for each row execute function audit.require_admin_actor();

commit;
