-- Keep operational alerts bounded before they reach the Admin inspection API.
-- Alert details are diagnostic text, not an unbounded event store.

begin;

create or replace function public.api_admin_alerts(p_status text default null, p_limit integer default 100)
returns table (alert_id uuid, alert_code text, severity text, status text, source text, title text, detail text, created_at timestamptz)
language sql stable security definer
set search_path = public, ops
as $$
select id,
       left(alert_code, 100),
       severity,
       status,
       left(source, 200),
       left(title, 500),
       case when detail is null then null else left(detail, 8192) end,
       created_at
from ops.system_alerts
where p_status is null or status = p_status
order by created_at desc, id desc
limit greatest(1, least(coalesce(p_limit, 100), 200));
$$;

create or replace function ops.enforce_system_alert_limits()
returns trigger
language plpgsql
set search_path = pg_catalog, ops
as $$
begin
  if length(coalesce(new.alert_code, '')) > 100 then
    raise exception 'System alert code exceeds 100 characters';
  end if;
  if length(coalesce(new.source, '')) > 200 then
    raise exception 'System alert source exceeds 200 characters';
  end if;
  if length(coalesce(new.title, '')) > 500 then
    raise exception 'System alert title exceeds 500 characters';
  end if;
  if length(coalesce(new.detail, '')) > 65536 then
    raise exception 'System alert detail exceeds 65536 characters';
  end if;
  if octet_length((to_jsonb(new)->'metadata')::text) > 65536 then
    raise exception 'System alert metadata exceeds 65536 bytes';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_system_alert_limits on ops.system_alerts;
create trigger trg_system_alert_limits
before insert or update on ops.system_alerts
for each row execute function ops.enforce_system_alert_limits();

revoke all on function ops.enforce_system_alert_limits() from public, anon, authenticated;
grant execute on function ops.enforce_system_alert_limits() to service_role;

commit;
