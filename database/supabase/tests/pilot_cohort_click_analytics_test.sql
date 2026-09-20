-- Cohort timing and offer-click attribution remain bounded, private and scoped.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(22);

select extensions.has_table('analytics', 'offer_click_events', 'structured offer click table exists');
select extensions.is(
  has_table_privilege('authenticated', 'analytics.offer_click_events', 'select'), false,
  'authenticated clients cannot read raw anonymous click rows'
);
select extensions.is(
  has_function_privilege('anon', 'public.api_record_offer_click(uuid,uuid,uuid,uuid,uuid,text,text)', 'execute'), false,
  'anonymous clients cannot bypass Worker click validation'
);
select extensions.is(
  has_function_privilege('service_role', 'public.api_server_provider_offer_click_metrics(uuid,text,integer)', 'execute'), true,
  'the Worker can request provider-scoped aggregates'
);

update research.pilot_settings set
  tester_intake_enabled = true,
  pilot_starts_at = now() - interval '1 day',
  pilot_ends_at = now() + interval '30 days',
  controller_name = 'Pruevia Cohort Test',
  controller_address = 'Rollback-only test address in Puebla',
  privacy_email = 'cohort@example.test',
  recruitment_target = 20,
  test_duration_days = 21,
  invitations_released_at = null,
  test_started_at = null,
  test_ends_at = null
where id;

insert into research.tester_candidates(
  pilot_key, email, municipality, age_confirmed, notice_version, retention_until
)
select 'android-puebla-2026-v1', 'cohort-' || n || '@example.test', 'Puebla', true,
  'android-testers-2026-09-v1', now() + interval '120 days'
from generate_series(1, 20) n;

select extensions.is(public.api_android_pilot_info()->>'registered_count', '20', 'public cohort count reaches its target');
select extensions.is(public.api_android_pilot_info()->>'phase', 'cohort_ready', 'a full cohort waits for simultaneous invitation');
select extensions.is(public.api_android_pilot_info()->>'enabled', 'false', 'new registrations close when the target is full');
select extensions.is(
  public.api_submit_tester_interest('extra@example.test', 'Puebla', true, 'android-testers-2026-09-v1', null, null)->>'error',
  'tester_intake_full', 'a twenty-first candidate cannot overfill the cohort'
);
select extensions.is(
  public.api_submit_tester_interest('cohort-1@example.test', 'Puebla', true, 'android-testers-2026-09-v1', 'Android 16', null)->>'accepted',
  'true', 'an existing candidate receives the non-enumerating accepted response'
);

insert into auth.users(id, aud, role, email, created_at, updated_at, is_sso_user, is_anonymous)
values
  ('00000000-0000-0000-0000-000000000941', 'authenticated', 'authenticated', 'cohort-admin@example.invalid', now(), now(), false, false),
  ('00000000-0000-0000-0000-000000000942', 'authenticated', 'authenticated', 'metrics-provider@example.invalid', now(), now(), false, false);
insert into auth.mfa_factors(id, user_id, factor_type, status, created_at, updated_at, secret)
values ('00000000-0000-0000-0000-000000000943', '00000000-0000-0000-0000-000000000942', 'totp', 'verified', now(), now(), 'metrics-factor-secret');

select extensions.is(
  public.api_admin_pilot_cohort('00000000-0000-0000-0000-000000000941', 'summary')->>'can_release_invitations',
  'true', 'Admin can see that the complete cohort is ready for invitation'
);
select extensions.is(
  public.api_admin_pilot_cohort('00000000-0000-0000-0000-000000000941', 'mark_invitations_released')->>'invited_count',
  '20', 'one audited action marks the simultaneous invitation release'
);
select extensions.is(
  public.api_admin_pilot_cohort('00000000-0000-0000-0000-000000000941', 'start_test')->>'error',
  'active_cohort_not_ready', 'the 21-day clock cannot start before every tester is active'
);
update research.tester_candidates set status = 'active' where pilot_key = 'android-puebla-2026-v1';
select extensions.is(
  public.api_admin_pilot_cohort('00000000-0000-0000-0000-000000000941', 'start_test')->>'test_day',
  '1', 'the verified complete cohort starts on day one'
);
select extensions.is(public.api_android_pilot_info()->>'phase', 'testing', 'public status reports a test in progress');
select extensions.is(public.api_android_pilot_info()->>'test_duration_days', '21', 'the public countdown preserves the 21-day duration');

insert into core.organizations(id, legal_name)
values ('00000000-0000-0000-0000-000000000944', 'Click metrics fixture');
insert into core.provider_brands(id, name, normalized_name, slug)
values ('00000000-0000-0000-0000-000000000945', 'Laboratorio Métrica', 'laboratorio metrica', 'laboratorio-metrica-fixture');
insert into core.provider_brand_organizations(provider_brand_id, organization_id, relationship_type)
values ('00000000-0000-0000-0000-000000000945', '00000000-0000-0000-0000-000000000944', 'owner');
insert into core.provider_locations(id, provider_brand_id, name, normalized_name)
values ('00000000-0000-0000-0000-000000000946', '00000000-0000-0000-0000-000000000945', 'Sucursal Centro', 'sucursal centro');
insert into catalog.domains(id, code, name)
values ('00000000-0000-0000-0000-000000000947', 'click_metrics_fixture', 'Click metrics fixture');
insert into catalog.items(id, domain_id, item_type, status)
values ('00000000-0000-0000-0000-000000000948', '00000000-0000-0000-0000-000000000947', 'service', 'active');
insert into catalog.item_names(item_id, name, normalized_name, is_primary)
values ('00000000-0000-0000-0000-000000000948', 'Biometría de prueba', 'biometria de prueba', true);
insert into supply.offers(id, provider_brand_id, catalog_item_id, provider_display_name, normalized_provider_name)
values ('00000000-0000-0000-0000-000000000949', '00000000-0000-0000-0000-000000000945', '00000000-0000-0000-0000-000000000948', 'Biometría de prueba', 'biometria de prueba');
insert into supply.offer_scopes(offer_id, scope_type, provider_location_id)
values ('00000000-0000-0000-0000-000000000949', 'location', '00000000-0000-0000-0000-000000000946');
insert into identity.provider_memberships(
  user_id, organization_id, scope_type, provider_brand_id, role, status, activated_at
)
values (
  '00000000-0000-0000-0000-000000000942', '00000000-0000-0000-0000-000000000944',
  'brand', '00000000-0000-0000-0000-000000000945', 'brand_admin', 'active', now()
);

select extensions.is(
  public.api_record_offer_click(
    '00000000-0000-0000-0000-000000000950', '00000000-0000-0000-0000-000000000949',
    '00000000-0000-0000-0000-000000000948', '00000000-0000-0000-0000-000000000945',
    '00000000-0000-0000-0000-000000000946', 'booking', 'pwa'
  )->>'accepted', 'true', 'a valid offer click is recorded'
);
select extensions.is(
  public.api_record_offer_click(
    '00000000-0000-0000-0000-000000000951', '00000000-0000-0000-0000-000000000949',
    '00000000-0000-0000-0000-000000000948', '00000000-0000-0000-0000-000000000999',
    '00000000-0000-0000-0000-000000000946', 'study', 'pwa'
  )->>'error', 'invalid_offer_click', 'a caller cannot attribute the click to another brand'
);
select extensions.is((select count(*)::text from analytics.offer_click_events), '1', 'invalid clicks do not create raw rows');
select extensions.is(
  public.api_admin_offer_click_metrics(30)->'summary'->>'total_clicks', '1',
  'Admin receives the global click total'
);
select extensions.is(
  public.api_admin_offer_click_metrics(30)->'by_service'->0->>'service_name', 'Biometría de prueba',
  'Admin metrics group interest by canonical service'
);
select extensions.is(
  public.api_server_provider_offer_click_metrics(
    '00000000-0000-0000-0000-000000000942', 'aal2', 30
  )->'summary'->>'total_clicks', '1', 'an approved provider sees clicks inside its brand scope'
);
select extensions.is(
  jsonb_array_length(public.api_server_provider_offer_click_metrics(
    '00000000-0000-0000-0000-000000000942', 'aal2', 30
  )->'by_location'), 1, 'provider aggregates include only its authorized location rows'
);

select * from extensions.finish();
rollback;
