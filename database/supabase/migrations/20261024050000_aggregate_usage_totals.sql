-- Approved aggregate-only internal request measurement, 23-Oct local.
begin;
set local lock_timeout = '250ms';
set local statement_timeout = '10s';
create table analytics.usage_daily_totals (
  day date not null,
  action text not null check(action in ('study_search','study_selection','order_resolution','order_batch','order_image')),
  requests bigint not null default 0 check(requests >= 0),
  primary key(day,action)
);
alter table analytics.usage_daily_totals enable row level security;
revoke all on analytics.usage_daily_totals from public,anon,authenticated;

create function public.api_increment_usage_total(p_action text)
returns void language plpgsql security definer set search_path = pg_catalog
as $$
begin
  if p_action not in ('study_search','study_selection','order_resolution','order_batch','order_image') or p_action is null then
    raise exception 'Unsupported aggregate action' using errcode='22023';
  end if;
  -- No event rows, event time, visitor key, IP, URL, query or medical identifier.
  insert into analytics.usage_daily_totals(day,action,requests)
  values ((now() at time zone 'UTC')::date,p_action,1)
  on conflict(day,action) do update set requests=analytics.usage_daily_totals.requests+1;
  delete from analytics.usage_daily_totals where day < (now() at time zone 'UTC')::date - 365;
end;
$$;
create function public.api_admin_usage_totals(p_days integer default 30)
returns jsonb language sql stable security definer set search_path = pg_catalog
as $$
select jsonb_build_object(
  'unit','successful_requests','timezone','UTC','retention_days',365,
  'days',greatest(1,least(coalesce(p_days,30),365)),
  'total_requests',coalesce(sum(requests),0),
  'daily',coalesce(jsonb_agg(to_jsonb(t) order by day,action),'[]'::jsonb)
) from (select day,action,requests from analytics.usage_daily_totals
 where day >= (now() at time zone 'UTC')::date - (greatest(1,least(coalesce(p_days,30),365))-1)) t;
$$;
revoke all on function public.api_increment_usage_total(text) from public,anon,authenticated;
revoke all on function public.api_admin_usage_totals(integer) from public,anon,authenticated;
grant execute on function public.api_increment_usage_total(text) to service_role;
grant execute on function public.api_admin_usage_totals(integer) to service_role;
insert into audit.events(actor_type,action,entity_schema,entity_table,request_id,metadata)
values ('system','analytics.aggregate_usage_enabled','analytics','usage_daily_totals','aggregate-usage-20261023',
  '{"approval":"User requested production publication after aggregate-only proposal","visitor_identifiers":false,"clinical_input":false,"retention_days":365,"unit":"successful_requests"}'::jsonb);
commit;
