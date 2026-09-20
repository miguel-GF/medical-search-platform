do $$
declare
  v_result jsonb;
begin
  update research.pilot_settings set
    tester_intake_enabled = true,
    feedback_enabled = false,
    pilot_starts_at = now() - interval '1 day',
    pilot_ends_at = now() + interval '30 days',
    recruitment_target = 20,
    test_duration_days = 21;

  insert into research.tester_candidates(
    pilot_key, email, municipality, age_confirmed, notice_version, retention_until
  ) select 'android-puebla-2026-v1', 'smoke-' || n || '@example.test', 'Puebla', true,
      'android-testers-2026-09-v1', now() + interval '90 days'
    from generate_series(1, 20) n;

  v_result := public.api_android_pilot_info();
  if v_result->>'phase' <> 'cohort_ready' or v_result->>'registered_count' <> '20' then
    raise exception 'cohort summary failed: %', v_result;
  end if;
  if public.api_submit_tester_interest(
    'overflow@example.test', 'Puebla', true, 'android-testers-2026-09-v1', null, null
  )->>'error' <> 'tester_intake_full' then
    raise exception 'cohort cap failed';
  end if;

  insert into auth.users(id) values
    ('00000000-0000-0000-0000-000000000001'),
    ('00000000-0000-0000-0000-000000000002');
  v_result := public.api_admin_pilot_cohort(
    '00000000-0000-0000-0000-000000000001', 'mark_invitations_released'
  );
  if v_result->>'invited_count' <> '20' then raise exception 'invitation release failed: %', v_result; end if;
  if public.api_admin_pilot_cohort(
    '00000000-0000-0000-0000-000000000001', 'start_test'
  )->>'error' <> 'active_cohort_not_ready' then raise exception 'early clock start was accepted'; end if;
  update research.tester_candidates set status = 'active';
  v_result := public.api_admin_pilot_cohort(
    '00000000-0000-0000-0000-000000000001', 'start_test'
  );
  if v_result->>'test_day' <> '1' then raise exception 'day one failed: %', v_result; end if;

  insert into core.organizations(id, legal_name)
    values ('00000000-0000-0000-0000-000000000010', 'Smoke organization');
  insert into core.provider_brands(id, name)
    values ('00000000-0000-0000-0000-000000000011', 'Smoke provider');
  insert into core.provider_locations(id, provider_brand_id, name)
    values ('00000000-0000-0000-0000-000000000012', '00000000-0000-0000-0000-000000000011', 'Smoke location');
  insert into core.provider_brand_organizations(provider_brand_id, organization_id)
    values ('00000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000010');
  insert into catalog.items(id) values ('00000000-0000-0000-0000-000000000013');
  insert into catalog.item_names(item_id, name, is_primary)
    values ('00000000-0000-0000-0000-000000000013', 'Estudio smoke', true);
  insert into supply.offers(id, provider_brand_id, catalog_item_id)
    values ('00000000-0000-0000-0000-000000000014', '00000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000013');
  insert into identity.provider_memberships(user_id, organization_id, scope_type, provider_brand_id)
    values ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000010', 'brand', '00000000-0000-0000-0000-000000000011');

  v_result := public.api_record_offer_click(
    '00000000-0000-0000-0000-000000000020', '00000000-0000-0000-0000-000000000014',
    '00000000-0000-0000-0000-000000000013', '00000000-0000-0000-0000-000000000011',
    '00000000-0000-0000-0000-000000000012', 'booking', 'pwa'
  );
  if v_result->>'accepted' <> 'true' then raise exception 'valid click rejected: %', v_result; end if;
  if public.api_record_offer_click(
    '00000000-0000-0000-0000-000000000021', '00000000-0000-0000-0000-000000000014',
    '00000000-0000-0000-0000-000000000013', '00000000-0000-0000-0000-000000000099',
    null, 'provider', 'pwa'
  )->>'error' <> 'invalid_offer_click' then raise exception 'spoofed brand accepted'; end if;
  if public.api_admin_offer_click_metrics(30)->'summary'->>'total_clicks' <> '1' then
    raise exception 'admin aggregate failed';
  end if;
  if public.api_server_provider_offer_click_metrics(
    '00000000-0000-0000-0000-000000000002', 'aal2', 30
  )->'summary'->>'total_clicks' <> '1' then raise exception 'provider scope failed'; end if;
end;
$$;

select 'PASS pilot cohort and click migration smoke test' as result;
