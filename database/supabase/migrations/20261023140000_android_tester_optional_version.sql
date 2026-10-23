-- User requested optional Android version; existing device fields stay nullable.
begin;
set local lock_timeout = '250ms';
set local statement_timeout = '10s';

create function public.api_submit_tester_interest_v3(
  p_email text, p_name text, p_age_confirmed boolean, p_notice_version text,
  p_android_version text default null
) returns jsonb language plpgsql security definer
set search_path = pg_catalog, research
as $$
declare
  v_android text := nullif(trim(p_android_version),'');
  v_result jsonb;
begin
  if v_android is not null and (length(v_android)>80 or v_android ~ '[[:cntrl:]]') then
    return jsonb_build_object('error','invalid_tester_interest');
  end if;
  -- Reuse the existing age/notice, duplicate and cohort-capacity checks. Its
  -- settings lock is held until the surrounding transaction finishes.
  v_result := public.api_submit_tester_interest_v2(p_email,p_name,p_age_confirmed,p_notice_version);
  if v_result->>'accepted' = 'true' and v_android is not null then
    update research.tester_candidates c set android_version=v_android
      where c.email=lower(trim(p_email))
        and c.pilot_key=(select s.pilot_key from research.pilot_settings s where s.id);
  end if;
  -- An empty optional value never clears a previous Android version. The
  -- device_model column and all previous values are untouched in either path.
  return v_result;
end;
$$;
revoke all on function public.api_submit_tester_interest_v3(text,text,boolean,text,text) from public,anon,authenticated;
grant execute on function public.api_submit_tester_interest_v3(text,text,boolean,text,text) to service_role;
commit;
