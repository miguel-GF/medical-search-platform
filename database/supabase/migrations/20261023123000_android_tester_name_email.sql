-- User-authorized Android recruitment: name + Gmail, no invented municipality.
begin;
set local lock_timeout = '250ms';
set local statement_timeout = '10s';

alter table research.tester_candidates add column name text
  check (name is null or (length(trim(name)) between 2 and 120 and name !~ '[[:cntrl:]]'));
alter table research.tester_candidates alter column municipality drop not null;

create function public.api_submit_tester_interest_v2(
  p_email text, p_name text, p_age_confirmed boolean, p_notice_version text
) returns jsonb language plpgsql security definer
set search_path = pg_catalog, research
as $$
declare
  v research.pilot_settings;
  v_email text := lower(trim(coalesce(p_email, '')));
  v_name text := trim(coalesce(p_name, ''));
  v_existing uuid;
  v_existing_status text;
  v_registered integer;
begin
  if length(v_email) > 254 or v_email !~ '^[^[:space:]@]+@gmail\.com$'
     or length(v_name) not between 2 and 120 or v_name ~ '[[:cntrl:]]' then
    return jsonb_build_object('error', 'invalid_tester_interest');
  end if;
  select * into v from research.pilot_settings where id for update;
  if not found or not v.tester_intake_enabled
     or v.pilot_starts_at is null or v.pilot_ends_at is null
     or now() not between v.pilot_starts_at and v.pilot_ends_at
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
  if (v_existing is null or v_existing_status in ('withdrawn','rejected'))
     and v_registered >= v.recruitment_target then
    return jsonb_build_object('error', 'tester_intake_full');
  end if;
  insert into research.tester_candidates (
    pilot_key, email, name, municipality, age_confirmed, notice_version, retention_until
  ) values (
    v.pilot_key, v_email, v_name, null, true, v.notice_version,
    v.pilot_ends_at + make_interval(days => v.retention_days)
  ) on conflict (pilot_key,email) do update set
    name = excluded.name, age_confirmed = true, notice_version = excluded.notice_version,
    notice_accepted_at = now(), updated_at = now(), retention_until = excluded.retention_until,
    status = case when research.tester_candidates.status in ('withdrawn','rejected')
      then 'pending' else research.tester_candidates.status end;
  return jsonb_build_object('accepted',true);
end;
$$;
revoke all on function public.api_submit_tester_interest_v2(text,text,boolean,text) from public,anon,authenticated;
grant execute on function public.api_submit_tester_interest_v2(text,text,boolean,text) to service_role;

-- Add the name to the existing authorized admin projection, retaining its
-- current permission checks, audit actions and other branches verbatim.
do $$
declare v_definition text;
begin
  select pg_get_functiondef(p.oid) into strict v_definition
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'api_admin_research';
  if position('select id, email, municipality, android_version, device_model, status,' in v_definition) = 0 then
    raise exception 'Unexpected admin research projection; review before applying';
  end if;
  execute replace(v_definition,
    'select id, email, municipality, android_version, device_model, status,',
    'select id, email, name, municipality, android_version, device_model, status,');
end;
$$;
commit;
