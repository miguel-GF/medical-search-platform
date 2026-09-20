-- A measurable Android test cohort and privacy-preserving outbound offer clicks.
-- This migration prepares the capability but does not enable intake, start a
-- cohort, send invitations, or publish any external destination.

begin;

alter table research.pilot_settings
  add column recruitment_target integer not null default 20
    check (recruitment_target between 12 and 100),
  add column test_duration_days integer not null default 21
    check (test_duration_days between 14 and 90),
  add column invitations_released_at timestamptz,
  add column test_started_at timestamptz,
  add column test_ends_at timestamptz,
  add constraint pilot_test_window_check check (
    test_ends_at is null or (test_started_at is not null and test_ends_at > test_started_at)
  );

create schema if not exists analytics;

create table analytics.offer_click_events (
  id bigint generated always as identity primary key,
  anonymous_id uuid not null,
  offer_id uuid not null references supply.offers(id) on delete restrict,
  catalog_item_id uuid not null references catalog.items(id) on delete restrict,
  provider_brand_id uuid not null references core.provider_brands(id) on delete restrict,
  provider_location_id uuid references core.provider_locations(id) on delete restrict,
  link_type text not null check (link_type in ('booking', 'study', 'location', 'provider')),
  surface text not null check (surface in ('web', 'pwa', 'android', 'ios')),
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  retention_until timestamptz not null default (now() + interval '400 days'),
  check (retention_until > occurred_at)
);

create index offer_click_events_time_idx
  on analytics.offer_click_events(occurred_at desc);
create index offer_click_events_provider_time_idx
  on analytics.offer_click_events(provider_brand_id, provider_location_id, occurred_at desc);
create index offer_click_events_service_time_idx
  on analytics.offer_click_events(catalog_item_id, occurred_at desc);
create index offer_click_events_retention_idx
  on analytics.offer_click_events(retention_until);

alter table analytics.offer_click_events enable row level security;
revoke all on table analytics.offer_click_events from public, anon, authenticated;
revoke all on sequence analytics.offer_click_events_id_seq from public, anon, authenticated;

create or replace function public.api_android_pilot_info()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, research
as $$
declare
  v research.pilot_settings;
  v_registered integer;
  v_active integer;
  v_phase text;
  v_day integer;
begin
  select * into v from research.pilot_settings where id;
  select
    count(*) filter (where status not in ('withdrawn', 'rejected')),
    count(*) filter (where status in ('active', 'completed'))
  into v_registered, v_active
  from research.tester_candidates
  where pilot_key = v.pilot_key;

  v_phase := case
    when v.test_ends_at is not null and now() >= v.test_ends_at then 'completed'
    when v.test_started_at is not null then 'testing'
    when v.invitations_released_at is not null then 'inviting'
    when v_registered >= v.recruitment_target then 'cohort_ready'
    when v.tester_intake_enabled and now() between v.pilot_starts_at and v.pilot_ends_at then 'recruiting'
    else 'closed'
  end;
  v_day := case when v.test_started_at is null then null else
    least(v.test_duration_days, greatest(1, floor(extract(epoch from (now() - v.test_started_at)) / 86400)::integer + 1))
  end;

  return jsonb_build_object(
    'enabled', v_phase = 'recruiting',
    'feedback_enabled', v.feedback_enabled and now() between v.pilot_starts_at and v.pilot_ends_at,
    'notice_version', v.notice_version,
    'target_audience', '18_plus',
    'restrict_minor_access', false,
    'patient_accounts', false,
    'minimum_tester_age', 18,
    'pilot_ends_at', v.pilot_ends_at,
    'phase', v_phase,
    'registered_count', least(v_registered, v.recruitment_target),
    'active_count', least(v_active, v.recruitment_target),
    'target_count', v.recruitment_target,
    'places_remaining', greatest(0, v.recruitment_target - v_registered),
    'recruitment_complete', v_registered >= v.recruitment_target,
    'test_duration_days', v.test_duration_days,
    'test_started_at', v.test_started_at,
    'test_ends_at', v.test_ends_at,
    'test_day', v_day,
    'municipalities', jsonb_build_array(
      'Puebla', 'San Andrés Cholula', 'San Pedro Cholula',
      'Cuautlancingo', 'Coronango', 'Amozoc'
    )
  );
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
  v_registered integer;
  v_existing uuid;
  v_existing_status text;
begin
  perform research.purge_expired();
  select * into v from research.pilot_settings where id for update;
  if not v.tester_intake_enabled or now() not between v.pilot_starts_at and v.pilot_ends_at
     or v.test_started_at is not null then
    return jsonb_build_object('error', 'tester_intake_disabled');
  end if;
  if p_age_confirmed is not true or p_notice_version is distinct from v.notice_version then
    return jsonb_build_object('error', 'notice_required');
  end if;

  select id, status into v_existing, v_existing_status from research.tester_candidates
  where pilot_key = v.pilot_key and email = v_email;
  select count(*) into v_registered from research.tester_candidates
  where pilot_key = v.pilot_key and status not in ('withdrawn', 'rejected');
  if (v_existing is null or v_existing_status in ('withdrawn', 'rejected'))
     and v_registered >= v.recruitment_target then
    return jsonb_build_object('error', 'tester_intake_full');
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
  return jsonb_build_object('accepted', true);
exception
  when check_violation then
    return jsonb_build_object('error', 'invalid_tester_interest');
end;
$$;

create or replace function public.api_record_offer_click(
  p_anonymous_id uuid,
  p_offer_id uuid,
  p_catalog_item_id uuid,
  p_provider_brand_id uuid,
  p_provider_location_id uuid,
  p_link_type text,
  p_surface text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, analytics, supply, catalog, core
as $$
declare
  v_item_id uuid;
  v_brand_id uuid;
begin
  delete from analytics.offer_click_events where retention_until <= now();
  select catalog_item_id, provider_brand_id into v_item_id, v_brand_id
  from supply.offers where id = p_offer_id and status = 'active';
  if v_item_id is null or v_item_id is distinct from p_catalog_item_id
     or v_brand_id is distinct from p_provider_brand_id then
    return jsonb_build_object('error', 'invalid_offer_click');
  end if;
  if p_provider_location_id is not null and not exists (
    select 1 from core.provider_locations l
    where l.id = p_provider_location_id and l.provider_brand_id = v_brand_id
      and l.status in ('active', 'temporarily_closed')
  ) then
    return jsonb_build_object('error', 'invalid_offer_click');
  end if;
  if p_link_type not in ('booking', 'study', 'location', 'provider')
     or p_surface not in ('web', 'pwa', 'android', 'ios') then
    return jsonb_build_object('error', 'invalid_offer_click');
  end if;
  insert into analytics.offer_click_events(
    anonymous_id, offer_id, catalog_item_id, provider_brand_id,
    provider_location_id, link_type, surface
  ) values (
    p_anonymous_id, p_offer_id, p_catalog_item_id, p_provider_brand_id,
    p_provider_location_id, p_link_type, p_surface
  );
  return jsonb_build_object('accepted', true);
exception
  when not_null_violation or foreign_key_violation or check_violation then
    return jsonb_build_object('error', 'invalid_offer_click');
end;
$$;

create or replace function analytics.offer_click_metrics(
  p_days integer,
  p_actor_user_id uuid default null,
  p_provider_scoped boolean default false
)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, analytics, identity, core, catalog
as $$
  with permitted as (
    select e.*
    from analytics.offer_click_events e
    where e.occurred_at >= now() - make_interval(days => least(365, greatest(1, p_days)))
      and (
        not p_provider_scoped
        or exists (
          select 1 from identity.provider_memberships m
          where m.user_id = p_actor_user_id and m.status = 'active' and (
            (m.scope_type = 'brand' and m.provider_brand_id = e.provider_brand_id)
            or (m.scope_type = 'location' and m.provider_brand_id = e.provider_brand_id
                and m.provider_location_id = e.provider_location_id)
            or (m.scope_type = 'organization' and (
              exists (select 1 from core.provider_brand_organizations bo
                where bo.organization_id = m.organization_id
                  and bo.provider_brand_id = e.provider_brand_id
                  and bo.valid_from <= current_date
                  and (bo.valid_to is null or bo.valid_to >= current_date))
              or exists (select 1 from core.provider_location_organizations lo
                where lo.organization_id = m.organization_id
                  and lo.provider_location_id = e.provider_location_id
                  and lo.status = 'active' and lo.valid_from <= current_date
                  and (lo.valid_to is null or lo.valid_to >= current_date))
            ))
          )
        )
      )
  ), named as (
    select p.*, b.name provider_name, l.name location_name,
      coalesce(n.name, 'Estudio sin nombre publicado') service_name
    from permitted p
    join core.provider_brands b on b.id = p.provider_brand_id
    left join core.provider_locations l on l.id = p.provider_location_id
    left join lateral (
      select name from catalog.item_names n
      where n.item_id = p.catalog_item_id and n.locale = 'es-MX'
      order by n.is_primary desc, n.name_type = 'display' desc, n.created_at asc limit 1
    ) n on true
  )
  select jsonb_build_object(
    'period_days', least(365, greatest(1, p_days)),
    'generated_at', now(),
    'summary', jsonb_build_object(
      'total_clicks', count(*),
      'unique_visitors', count(distinct anonymous_id),
      'booking_clicks', count(*) filter (where link_type = 'booking'),
      'services_with_clicks', count(distinct catalog_item_id),
      'locations_with_clicks', count(distinct provider_location_id)
    ),
    'daily', coalesce((select jsonb_agg(
      jsonb_build_object('day', x.metric_date, 'clicks', x.clicks)
      order by x.metric_date
    ) from (
      select occurred_at::date as metric_date, count(*) as clicks
      from named group by occurred_at::date
    ) x), '[]'::jsonb),
    'by_service', coalesce((select jsonb_agg(to_jsonb(x) order by x.clicks desc, x.service_name) from (
      select catalog_item_id service_id, service_name, provider_brand_id, provider_name,
        count(*) clicks, count(distinct anonymous_id) unique_visitors
      from named group by catalog_item_id, service_name, provider_brand_id, provider_name limit 100
    ) x), '[]'::jsonb),
    'by_location', coalesce((select jsonb_agg(to_jsonb(x) order by x.clicks desc, x.location_name) from (
      select provider_location_id location_id, coalesce(location_name, 'Toda la red') location_name,
        provider_brand_id, provider_name, count(*) clicks,
        count(distinct anonymous_id) unique_visitors
      from named group by provider_location_id, location_name, provider_brand_id, provider_name limit 100
    ) x), '[]'::jsonb),
    'by_link_type', coalesce((select jsonb_agg(to_jsonb(x) order by x.clicks desc) from (
      select link_type, count(*) clicks from named group by link_type
    ) x), '[]'::jsonb)
  ) from named;
$$;

create or replace function public.api_admin_offer_click_metrics(p_days integer default 30)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, analytics
as $$ select analytics.offer_click_metrics(p_days, null, false); $$;

create or replace function public.api_server_provider_offer_click_metrics(
  p_actor_user_id uuid,
  p_actor_aal text,
  p_days integer default 30
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, analytics, core, identity
as $$
begin
  perform core.set_verified_provider_actor(p_actor_user_id, p_actor_aal);
  if not exists (
    select 1 from identity.provider_memberships
    where user_id = p_actor_user_id and status = 'active'
  ) then
    raise exception 'Provider membership is required';
  end if;
  return analytics.offer_click_metrics(p_days, p_actor_user_id, true);
end;
$$;

-- Add cohort summary/start actions while preserving existing queues and audit.
create or replace function public.api_admin_pilot_cohort(
  p_actor_user_id uuid,
  p_action text default 'summary'
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, research, audit
as $$
declare
  v research.pilot_settings;
  v_registered integer;
  v_invited integer;
  v_active integer;
  v_completed integer;
begin
  if p_actor_user_id is null or not exists (select 1 from auth.users where id = p_actor_user_id) then
    raise exception 'Admin actor is required';
  end if;
  select * into v from research.pilot_settings where id for update;
  select
    count(*) filter (where status not in ('withdrawn', 'rejected')),
    count(*) filter (where status in ('invited', 'active', 'completed')),
    count(*) filter (where status in ('active', 'completed')),
    count(*) filter (where status = 'completed')
  into v_registered, v_invited, v_active, v_completed
  from research.tester_candidates where pilot_key = v.pilot_key;

  if p_action = 'mark_invitations_released' then
    if v_registered < v.recruitment_target or v.invitations_released_at is not null then
      return jsonb_build_object('error', 'cohort_not_ready');
    end if;
    update research.pilot_settings set invitations_released_at = now(),
      tester_intake_enabled = false, updated_at = now() where id;
    update research.tester_candidates set status = 'invited', updated_at = now(),
      reviewed_by = p_actor_user_id, reviewed_at = now()
    where pilot_key = v.pilot_key and status in ('pending', 'selected');
    insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, after_data)
      values (p_actor_user_id, 'admin', 'research.pilot_invitations_released',
        'research', 'pilot_settings', jsonb_build_object('pilot_key', v.pilot_key, 'tester_count', v_registered));
    select * into v from research.pilot_settings where id;
    v_invited := v_registered;
  elsif p_action = 'start_test' then
    if v_active < v.recruitment_target or v.test_started_at is not null then
      return jsonb_build_object('error', 'active_cohort_not_ready');
    end if;
    update research.pilot_settings set test_started_at = now(),
      test_ends_at = now() + make_interval(days => test_duration_days),
      tester_intake_enabled = false, updated_at = now() where id;
    insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, after_data)
      values (p_actor_user_id, 'admin', 'research.pilot_test_started',
        'research', 'pilot_settings', jsonb_build_object('pilot_key', v.pilot_key,
          'active_testers', v_active, 'duration_days', v.test_duration_days));
    select * into v from research.pilot_settings where id;
  elsif p_action <> 'summary' then
    return jsonb_build_object('error', 'invalid_action');
  end if;

  return jsonb_build_object(
    'pilot_key', v.pilot_key,
    'target_count', v.recruitment_target,
    'registered_count', v_registered,
    'invited_count', v_invited,
    'active_count', v_active,
    'completed_count', v_completed,
    'test_duration_days', v.test_duration_days,
    'invitations_released_at', v.invitations_released_at,
    'test_started_at', v.test_started_at,
    'test_ends_at', v.test_ends_at,
    'test_day', case when v.test_started_at is null then null else
      least(v.test_duration_days, greatest(1, floor(extract(epoch from (now() - v.test_started_at)) / 86400)::integer + 1)) end,
    'can_release_invitations', v_registered >= v.recruitment_target and v.invitations_released_at is null,
    'can_start_test', v_active >= v.recruitment_target and v.test_started_at is null
  );
end;
$$;

revoke all on function analytics.offer_click_metrics(integer, uuid, boolean) from public, anon, authenticated, service_role;
revoke all on function public.api_record_offer_click(uuid,uuid,uuid,uuid,uuid,text,text) from public, anon, authenticated;
revoke all on function public.api_admin_offer_click_metrics(integer) from public, anon, authenticated;
revoke all on function public.api_server_provider_offer_click_metrics(uuid,text,integer) from public, anon, authenticated;
revoke all on function public.api_admin_pilot_cohort(uuid,text) from public, anon, authenticated;

grant execute on function public.api_record_offer_click(uuid,uuid,uuid,uuid,uuid,text,text) to service_role;
grant execute on function public.api_admin_offer_click_metrics(integer) to service_role;
grant execute on function public.api_server_provider_offer_click_metrics(uuid,text,integer) to service_role;
grant execute on function public.api_admin_pilot_cohort(uuid,text) to service_role;

commit;
