-- Product feedback and Android closed-test intake stay isolated and fail closed.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(22);

select extensions.has_table('research', 'product_feedback', 'anonymous feedback table exists');
select extensions.has_table('research', 'tester_candidates', 'tester candidate table exists');
select extensions.has_table('research', 'pilot_settings', 'pilot settings table exists');

select extensions.is(
  has_table_privilege('anon', 'research.tester_candidates', 'select'), false,
  'anonymous users cannot read tester emails'
);
select extensions.is(
  has_table_privilege('authenticated', 'research.product_feedback', 'select'), false,
  'authenticated users cannot bypass the Admin feedback view'
);
select extensions.is(
  has_function_privilege('anon', 'public.api_submit_tester_interest(text,text,boolean,text,text,text)', 'execute'), false,
  'anonymous users cannot bypass Worker intake validation'
);
select extensions.is(
  has_function_privilege('service_role', 'public.api_submit_product_feedback(text,text,text,text[],text,text,text,integer,text,text,boolean)', 'execute'), true,
  'the Worker service role can submit bounded feedback'
);
select extensions.is(
  public.api_android_pilot_info()->>'target_audience', '18_plus',
  'the public app declares an adult target audience'
);
select extensions.is(
  public.api_android_pilot_info()->>'restrict_minor_access', 'false',
  'the public app does not block a minor from helping a family member'
);

select extensions.is(
  public.api_submit_tester_interest(
    'person@example.test', 'Puebla', true, 'android-testers-2026-09-v1', null, null
  )->>'error', 'tester_intake_disabled',
  'tester intake is closed after migration installation'
);

update research.pilot_settings set
  feedback_enabled = true,
  tester_intake_enabled = true,
  pilot_starts_at = now() - interval '1 day',
  pilot_ends_at = now() + interval '21 days',
  controller_name = 'Pruevia Test Controller',
  controller_address = 'Test address used only inside rollback fixture',
  privacy_email = 'privacy@example.test'
where id;

select extensions.is(
  public.api_submit_tester_interest(
    'PERSON@EXAMPLE.TEST', 'Puebla', true, 'android-testers-2026-09-v1', 'Android 16', 'Test phone'
  )->>'accepted', 'true',
  'an adult candidate in the pilot area can register'
);
select extensions.is(
  public.api_submit_tester_interest(
    'person@example.test', 'Puebla', true, 'android-testers-2026-09-v1', 'Android 16', 'Test phone'
  )->>'accepted', 'true',
  'duplicate registration receives the same accepted response'
);
select extensions.is(
  (select count(*)::text from research.tester_candidates where email = 'person@example.test'), '1',
  'candidate email is normalized and deduplicated'
);
select extensions.is(
  public.api_submit_tester_interest(
    'minor@example.test', 'Puebla', false, 'android-testers-2026-09-v1', null, null
  )->>'error', 'notice_required',
  'closed-test registration requires adult confirmation'
);
select extensions.is(
  public.api_submit_tester_interest(
    'outside@example.test', 'Tlaxcala', true, 'android-testers-2026-09-v1', null, null
  )->>'error', 'invalid_tester_interest',
  'the first pilot does not silently expand its municipality list'
);

select extensions.is(
  public.api_submit_product_feedback(
    'yes', 'partly', 'yes', array['missing_price'], 'android', 'public',
    'results', 2, '1.0.0+1', null, false
  )->>'accepted', 'true',
  'structured public feedback is accepted without an identity'
);
select extensions.is(
  public.api_submit_product_feedback(
    'yes', 'yes', 'yes', '{}'::text[], 'android', 'public',
    'results', 1, '1.0.0+1', 'medical free text', true
  )->>'error', 'comment_not_allowed',
  'the public channel cannot submit free text'
);
select extensions.is(
  public.api_submit_product_feedback(
    'yes', 'yes', 'partly', array['other'], 'android', 'closed_android',
    'results', 1, '1.0.0+1', 'La comparación fue clara.', true
  )->>'accepted', 'true',
  'the adult closed-test channel can submit a bounded comment'
);
select extensions.is(
  (select count(*)::text from research.product_feedback), '2',
  'rejected comments do not create feedback rows'
);

insert into auth.users(id, aud, role, email, created_at, updated_at, is_sso_user, is_anonymous)
values ('00000000-0000-0000-0000-000000000918', 'authenticated', 'authenticated',
        'research-admin@example.invalid', now(), now(), false, false)
on conflict (id) do nothing;

select extensions.is(
  jsonb_array_length(public.api_admin_research(
    '00000000-0000-0000-0000-000000000918', 'list_testers', null, '{"limit":100}'::jsonb
  )->'items'), 1,
  'the protected Admin boundary lists the deduplicated candidate'
);
select extensions.is(
  public.api_admin_research(
    '00000000-0000-0000-0000-000000000918', 'update_tester',
    (select id from research.tester_candidates limit 1),
    '{"status":"withdrawn","note":"Retiro solicitado"}'::jsonb
  )->>'updated', 'true',
  'Admin can record withdrawal through the audited boundary'
);
select extensions.ok(
  (select retention_until <= now() + interval '7 days 1 minute'
    from research.tester_candidates limit 1),
  'withdrawal shortens personal-data retention to seven days'
);

select * from extensions.finish();
rollback;
