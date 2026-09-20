-- Anonymous product feedback and an isolated Android closed-test candidate list.
-- Installation does not activate either public intake. Legal/contact settings
-- and pilot dates must be reviewed before enabling them.

begin;

create schema if not exists research;

create table research.pilot_settings (
  id boolean primary key default true check (id),
  feedback_enabled boolean not null default false,
  tester_intake_enabled boolean not null default false,
  pilot_key text not null default 'android-puebla-2026-v1'
    check (pilot_key ~ '^[a-z0-9][a-z0-9-]{2,63}$'),
  pilot_starts_at timestamptz,
  pilot_ends_at timestamptz,
  controller_name text not null default '',
  controller_address text not null default '',
  privacy_email text not null default '',
  notice_version text not null default 'android-testers-2026-09-v1'
    check (length(notice_version) between 3 and 80),
  retention_days integer not null default 90 check (retention_days between 1 and 365),
  updated_at timestamptz not null default now(),
  check (pilot_ends_at is null or pilot_starts_at is null or pilot_ends_at > pilot_starts_at),
  check (
    not (feedback_enabled or tester_intake_enabled)
    or (
      length(trim(controller_name)) > 2
      and length(trim(controller_address)) > 10
      and privacy_email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
      and pilot_starts_at is not null
      and pilot_ends_at is not null
    )
  )
);

insert into research.pilot_settings(id) values (true)
on conflict (id) do nothing;

create table research.product_feedback (
  id uuid primary key default gen_random_uuid(),
  experience text not null check (experience in ('yes', 'partly', 'no')),
  helpful text not null check (helpful in ('yes', 'partly', 'no', 'not_applicable')),
  expected text not null check (expected in ('yes', 'partly', 'no')),
  reasons text[] not null default '{}'::text[]
    check (reasons <@ array[
      'repeated_information', 'missing_price', 'wrong_branch',
      'unrelated_result', 'unclear_information', 'other'
    ]::text[] and cardinality(reasons) <= 6),
  surface text not null check (surface in ('web', 'pwa', 'android', 'ios')),
  channel text not null check (channel in ('public', 'closed_android')),
  result_state text not null check (result_state in ('results', 'no_match', 'ambiguous', 'manual')),
  result_count integer not null default 0 check (result_count between 0 and 1000),
  app_version text check (app_version is null or length(app_version) <= 40),
  comment text check (
    comment is null
    or (channel = 'closed_android' and length(trim(comment)) between 1 and 500)
  ),
  triage_status text not null default 'new'
    check (triage_status in ('new', 'reviewed', 'planned', 'resolved', 'dismissed')),
  internal_note text check (internal_note is null or length(internal_note) <= 1000),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  retention_until timestamptz not null
);

create index product_feedback_queue_idx
  on research.product_feedback(triage_status, created_at desc, id);
create index product_feedback_retention_idx
  on research.product_feedback(retention_until);

create table research.tester_candidates (
  id uuid primary key default gen_random_uuid(),
  pilot_key text not null,
  email text not null check (
    length(email) <= 254
    and email = lower(trim(email))
    and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
  ),
  municipality text not null check (municipality in (
    'Puebla', 'San Andrés Cholula', 'San Pedro Cholula',
    'Cuautlancingo', 'Coronango', 'Amozoc'
  )),
  android_version text check (android_version is null or length(android_version) <= 80),
  device_model text check (device_model is null or length(device_model) <= 120),
  age_confirmed boolean not null check (age_confirmed),
  notice_version text not null check (length(notice_version) between 3 and 80),
  notice_accepted_at timestamptz not null default now(),
  status text not null default 'pending' check (status in (
    'pending', 'selected', 'invited', 'active', 'completed', 'withdrawn', 'rejected'
  )),
  internal_note text check (internal_note is null or length(internal_note) <= 1000),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  retention_until timestamptz not null,
  unique (pilot_key, email)
);

create index tester_candidates_queue_idx
  on research.tester_candidates(status, created_at desc, id);
create index tester_candidates_retention_idx
  on research.tester_candidates(retention_until);

alter table research.pilot_settings enable row level security;
alter table research.product_feedback enable row level security;
alter table research.tester_candidates enable row level security;

revoke all on schema research from public, anon, authenticated;
revoke all on all tables in schema research from public, anon, authenticated;
revoke all on all sequences in schema research from public, anon, authenticated;

create or replace function research.purge_expired()
returns void
language plpgsql
security definer
set search_path = pg_catalog, research
as $$
begin
  delete from research.product_feedback where retention_until <= now();
  delete from research.tester_candidates where retention_until <= now();
end;
$$;

revoke all on function research.purge_expired() from public, anon, authenticated, service_role;

create or replace function public.api_android_pilot_info()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, research
as $$
declare
  v research.pilot_settings;
begin
  select * into v from research.pilot_settings where id;
  return jsonb_build_object(
    'enabled', v.tester_intake_enabled and now() between v.pilot_starts_at and v.pilot_ends_at,
    'feedback_enabled', v.feedback_enabled and now() between v.pilot_starts_at and v.pilot_ends_at,
    'notice_version', v.notice_version,
    'target_audience', '18_plus',
    'restrict_minor_access', false,
    'patient_accounts', false,
    'minimum_tester_age', 18,
    'pilot_ends_at', v.pilot_ends_at,
    'municipalities', jsonb_build_array(
      'Puebla', 'San Andrés Cholula', 'San Pedro Cholula',
      'Cuautlancingo', 'Coronango', 'Amozoc'
    )
  );
end;
$$;

create or replace function public.api_submit_product_feedback(
  p_experience text,
  p_helpful text,
  p_expected text,
  p_reasons text[],
  p_surface text,
  p_channel text,
  p_result_state text,
  p_result_count integer,
  p_app_version text default null,
  p_comment text default null,
  p_adult_confirmed boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, research
as $$
declare
  v research.pilot_settings;
  v_retention timestamptz;
begin
  perform research.purge_expired();
  select * into v from research.pilot_settings where id;
  if not v.feedback_enabled or now() not between v.pilot_starts_at and v.pilot_ends_at then
    return jsonb_build_object('error', 'feedback_disabled');
  end if;
  if p_comment is not null and (p_channel <> 'closed_android' or not p_adult_confirmed) then
    return jsonb_build_object('error', 'comment_not_allowed');
  end if;
  v_retention := v.pilot_ends_at + make_interval(days => v.retention_days);
  insert into research.product_feedback(
    experience, helpful, expected, reasons, surface, channel,
    result_state, result_count, app_version, comment, retention_until
  ) values (
    p_experience, p_helpful, p_expected, coalesce(p_reasons, '{}'::text[]),
    p_surface, p_channel, p_result_state, p_result_count,
    nullif(trim(p_app_version), ''), nullif(trim(p_comment), ''), v_retention
  );
  return jsonb_build_object('accepted', true);
exception
  when check_violation then
    return jsonb_build_object('error', 'invalid_feedback');
end;
$$;

create or replace function public.api_submit_tester_interest(
  p_email text,
  p_municipality text,
  p_age_confirmed boolean,
  p_notice_version text,
  p_android_version text default null,
  p_device_model text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, research
as $$
declare
  v research.pilot_settings;
  v_email text := lower(trim(coalesce(p_email, '')));
  v_retention timestamptz;
begin
  perform research.purge_expired();
  select * into v from research.pilot_settings where id;
  if not v.tester_intake_enabled or now() not between v.pilot_starts_at and v.pilot_ends_at then
    return jsonb_build_object('error', 'tester_intake_disabled');
  end if;
  if p_age_confirmed is not true or p_notice_version is distinct from v.notice_version then
    return jsonb_build_object('error', 'notice_required');
  end if;
  v_retention := v.pilot_ends_at + make_interval(days => v.retention_days);
  insert into research.tester_candidates(
    pilot_key, email, municipality, android_version, device_model,
    age_confirmed, notice_version, retention_until
  ) values (
    v.pilot_key, v_email, trim(p_municipality), nullif(trim(p_android_version), ''),
    nullif(trim(p_device_model), ''), true, v.notice_version, v_retention
  )
  on conflict (pilot_key, email) do update set
    municipality = excluded.municipality,
    android_version = excluded.android_version,
    device_model = excluded.device_model,
    age_confirmed = true,
    notice_version = excluded.notice_version,
    notice_accepted_at = now(),
    status = case when research.tester_candidates.status in ('withdrawn', 'rejected') then 'pending'
      else research.tester_candidates.status end,
    updated_at = now(),
    retention_until = excluded.retention_until;
  -- The response is deliberately identical for new and duplicate addresses.
  return jsonb_build_object('accepted', true);
exception
  when check_violation then
    return jsonb_build_object('error', 'invalid_tester_interest');
end;
$$;

create or replace function public.api_admin_research(
  p_actor_user_id uuid,
  p_action text,
  p_id uuid default null,
  p_data jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, research, audit
as $$
declare
  v_status text := trim(coalesce(p_data->>'status', ''));
  v_note text := nullif(trim(coalesce(p_data->>'note', '')), '');
  v_limit integer := least(200, greatest(1, coalesce((p_data->>'limit')::integer, 100)));
begin
  if p_actor_user_id is null or not exists (select 1 from auth.users where id = p_actor_user_id) then
    raise exception 'Admin actor is required';
  end if;
  if p_data is null or jsonb_typeof(p_data) <> 'object' or pg_column_size(p_data) > 4096
     or length(coalesce(v_note, '')) > 1000 then
    return jsonb_build_object('error', 'invalid_request');
  end if;
  perform research.purge_expired();

  if p_action = 'list_feedback' then
    return jsonb_build_object('items', coalesce((select jsonb_agg(to_jsonb(r)) from (
      select id, experience, helpful, expected, reasons, surface, channel,
        result_state, result_count, app_version, comment, triage_status,
        internal_note, reviewed_at, created_at
      from research.product_feedback
      where v_status = '' or triage_status = v_status
      order by created_at desc, id limit v_limit
    ) r), '[]'::jsonb));
  elsif p_action = 'list_testers' then
    return jsonb_build_object('items', coalesce((select jsonb_agg(to_jsonb(r)) from (
      select id, email, municipality, android_version, device_model, status,
        notice_version, notice_accepted_at, internal_note, reviewed_at, created_at, updated_at
      from research.tester_candidates
      where v_status = '' or status = v_status
      order by created_at desc, id limit v_limit
    ) r), '[]'::jsonb));
  elsif p_action = 'update_feedback' then
    if v_status not in ('new', 'reviewed', 'planned', 'resolved', 'dismissed') then
      return jsonb_build_object('error', 'invalid_status');
    end if;
    update research.product_feedback set triage_status = v_status,
      internal_note = v_note, reviewed_by = p_actor_user_id, reviewed_at = now()
      where id = p_id;
    if not found then return jsonb_build_object('error', 'not_found'); end if;
    insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, after_data)
      values (p_actor_user_id, 'admin', 'research.feedback_triaged', 'research', 'product_feedback', p_id,
        jsonb_build_object('status', v_status, 'note_length', length(coalesce(v_note, ''))));
    return jsonb_build_object('updated', true);
  elsif p_action = 'update_tester' then
    if v_status not in ('pending', 'selected', 'invited', 'active', 'completed', 'withdrawn', 'rejected') then
      return jsonb_build_object('error', 'invalid_status');
    end if;
    update research.tester_candidates set status = v_status, internal_note = v_note,
      reviewed_by = p_actor_user_id, reviewed_at = now(), updated_at = now(),
      retention_until = case when v_status = 'withdrawn'
        then least(retention_until, now() + interval '7 days') else retention_until end
      where id = p_id;
    if not found then return jsonb_build_object('error', 'not_found'); end if;
    insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, after_data)
      values (p_actor_user_id, 'admin', 'research.tester_status_changed', 'research', 'tester_candidates', p_id,
        jsonb_build_object('status', v_status, 'note_length', length(coalesce(v_note, ''))));
    return jsonb_build_object('updated', true);
  end if;
  return jsonb_build_object('error', 'invalid_action');
exception
  when invalid_text_representation then
    return jsonb_build_object('error', 'invalid_request');
end;
$$;

revoke all on function public.api_android_pilot_info() from public, anon, authenticated;
revoke all on function public.api_submit_product_feedback(text,text,text,text[],text,text,text,integer,text,text,boolean) from public, anon, authenticated;
revoke all on function public.api_submit_tester_interest(text,text,boolean,text,text,text) from public, anon, authenticated;
revoke all on function public.api_admin_research(uuid,text,uuid,jsonb) from public, anon, authenticated;

grant execute on function public.api_android_pilot_info() to service_role;
grant execute on function public.api_submit_product_feedback(text,text,text,text[],text,text,text,integer,text,text,boolean) to service_role;
grant execute on function public.api_submit_tester_interest(text,text,boolean,text,text,text) to service_role;
grant execute on function public.api_admin_research(uuid,text,uuid,jsonb) to service_role;

commit;
