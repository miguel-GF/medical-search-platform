-- Consent-gated, non-clinical telemetry for the patient web/PWA surface.
-- Raw searches, recipes, images and personal identifiers are intentionally not
-- accepted by this contract.

begin;

create table if not exists analytics.anonymous_events (
  id bigint generated always as identity primary key,
  anonymous_id uuid not null,
  event_name text not null check (event_name in (
    'consent_granted',
    'search_completed',
    'package_resolved',
    'package_resolved_from_image',
    'provider_contact_clicked',
    'pwa_installed'
  )),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists anonymous_events_created_idx
  on analytics.anonymous_events(created_at desc);
create index if not exists anonymous_events_name_created_idx
  on analytics.anonymous_events(event_name, created_at desc);

alter table analytics.anonymous_events enable row level security;
revoke all on table analytics.anonymous_events from public, anon, authenticated;

create or replace function public.api_record_analytics_event(
  p_event_name text,
  p_anonymous_id uuid,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, analytics
as $$
declare
  v_metadata jsonb := coalesce(p_metadata, '{}'::jsonb);
  v_key text;
  v_value jsonb;
begin
  if p_anonymous_id is null then
    raise exception 'anonymous_id is required';
  end if;
  if p_event_name not in (
    'consent_granted',
    'search_completed',
    'package_resolved',
    'package_resolved_from_image',
    'provider_contact_clicked',
    'pwa_installed'
  ) then
    raise exception 'unsupported analytics event';
  end if;
  if jsonb_typeof(v_metadata) <> 'object' or pg_column_size(v_metadata) > 2048 then
    raise exception 'analytics metadata must be a small object';
  end if;

  for v_key, v_value in select key, value from jsonb_each(v_metadata) loop
    if v_key not in ('result_count', 'item_count', 'status', 'review_required', 'surface') then
      raise exception 'unsupported analytics metadata key';
    end if;
    if v_key in ('result_count', 'item_count')
       and (jsonb_typeof(v_value) <> 'number' or v_value::text !~ '^-?[0-9]+$' or (v_value #>> '{}')::integer not between 0 and 1000) then
      raise exception 'analytics counts must be integers between 0 and 1000';
    end if;
    if v_key = 'status'
       and (jsonb_typeof(v_value) <> 'string' or v_value #>> '{}' not in ('ready', 'partial', 'needs_clarification', 'no_match')) then
      raise exception 'analytics status is invalid';
    end if;
    if v_key = 'review_required' and jsonb_typeof(v_value) <> 'boolean' then
      raise exception 'analytics review_required must be boolean';
    end if;
    if v_key = 'surface'
       and (jsonb_typeof(v_value) <> 'string' or v_value #>> '{}' not in ('web', 'pwa', 'android', 'ios')) then
      raise exception 'analytics surface is invalid';
    end if;
  end loop;

  insert into analytics.anonymous_events(anonymous_id, event_name, metadata)
  values (p_anonymous_id, p_event_name, v_metadata);

  return jsonb_build_object('accepted', true);
end;
$$;

revoke all on function public.api_record_analytics_event(text, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.api_record_analytics_event(text, uuid, jsonb) to anon, authenticated, service_role;

commit;
