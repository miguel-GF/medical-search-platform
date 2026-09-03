-- Public RPC contract tests for Search API and Admin API.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(45);

select extensions.has_function(
  'public',
  'api_search',
  array['text','text','double precision','double precision','uuid','integer'],
  'public.api_search is exposed as a typed RPC'
);
select extensions.has_function('public', 'api_admin_catalog_items', array['text','integer'], 'admin catalog lookup RPC exists');
select extensions.has_function('public', 'api_admin_dashboard', array[]::text[], 'admin dashboard RPC exists');
select extensions.has_function(
  'public',
  'api_admin_update_alias',
  array['uuid','uuid','text','uuid','text','uuid'],
  'admin alias update RPC exists'
);
select extensions.has_function(
  'public',
  'api_admin_update_alias',
  array['uuid','uuid','text','uuid','text','uuid','text'],
  'admin alias update RPC propagates request id'
);
select extensions.has_function('public', 'api_admin_providers', array['integer'], 'admin providers lookup exists');
select extensions.has_function('public', 'api_admin_locations', array['integer'], 'admin locations lookup exists');
select extensions.has_function('public', 'api_admin_offers', array['integer'], 'admin offers lookup exists');
select extensions.has_function('public', 'api_admin_prices', array['integer'], 'admin prices lookup exists');
select extensions.has_function('public', 'api_admin_quality_issues', array['text','integer'], 'admin quality lookup exists');
select extensions.has_function('public', 'api_admin_alerts', array['text','integer'], 'admin alerts lookup exists');
select extensions.has_function('public', 'api_admin_normalization_queue_v2', array['text','text','integer','timestamptz','uuid'], 'rich normalization queue RPC exists');
select extensions.has_function('public', 'api_admin_normalization_detail', array['uuid','boolean'], 'normalization detail RPC exists');
select extensions.has_function('public', 'api_record_resolution_review', array['jsonb','text','text'], 'scoped resolution review capture RPC exists');
select extensions.has_function('public', 'api_admin_add_manual_candidate', array['uuid','uuid','uuid','text','text'], 'manual candidate RPC exists');
select extensions.has_function('public', 'api_admin_review_normalization', array['uuid','text','uuid','text','text','uuid','text'], 'transactional normalization review RPC exists');
select extensions.has_function('public', 'api_admin_update_alert_status', array['uuid','text','text','uuid','text'], 'alert status RPC exists');
select extensions.has_function('public', 'api_admin_update_quality_issue_status', array['uuid','text','text','uuid','text'], 'quality status RPC exists');
select extensions.is(jsonb_typeof(public.api_admin_dashboard()), 'object', 'admin dashboard returns JSON object');

insert into core.provider_brands(id, name, normalized_name, slug)
values ('00000000-0000-0000-0000-000000000901', 'API Fixture Brand', 'api fixture brand', 'api-fixture-brand');
insert into core.provider_locations(id, provider_brand_id, name, normalized_name, coordinates)
values (
  '00000000-0000-0000-0000-000000000902',
  '00000000-0000-0000-0000-000000000901',
  'API Fixture Location',
  'api fixture location',
  gis.st_geogfromtext('SRID=4326;POINT(-98.2001 19.0401)')
);
insert into core.provider_markets(id, provider_brand_id, name, normalized_name, slug)
values ('00000000-0000-0000-0000-000000000903', '00000000-0000-0000-0000-000000000901', 'API Puebla', 'api puebla', 'api-puebla');
insert into core.provider_market_locations(provider_market_id, provider_location_id)
values ('00000000-0000-0000-0000-000000000903', '00000000-0000-0000-0000-000000000902');

insert into catalog.items(id, domain_id, item_type, status)
select '00000000-0000-0000-0000-000000000904', id, 'service', 'active'
from catalog.domains where code = 'health_diagnostics';
insert into catalog.item_names(item_id, name, normalized_name, is_primary)
values ('00000000-0000-0000-0000-000000000904', 'API Fixture Hemograma', 'api fixture hemograma', true);
insert into health.services(catalog_item_id, service_type)
values ('00000000-0000-0000-0000-000000000904', 'lab_test');
insert into supply.offers(id, provider_brand_id, catalog_item_id, provider_display_name, normalized_provider_name)
values ('00000000-0000-0000-0000-000000000905', '00000000-0000-0000-0000-000000000901', '00000000-0000-0000-0000-000000000904', 'Hemograma API', 'hemograma api');
insert into supply.offer_scopes(offer_id, scope_type, provider_market_id)
values ('00000000-0000-0000-0000-000000000905', 'market', '00000000-0000-0000-0000-000000000903');
insert into supply.price_versions(offer_scope_id, amount_minor)
select id, 12345 from supply.offer_scopes
where offer_id = '00000000-0000-0000-0000-000000000905' and scope_type = 'market';
insert into supply.offer_links(offer_scope_id, link_type, url)
select id, 'details', 'https://example.test/api-fixture'
from supply.offer_scopes
where offer_id = '00000000-0000-0000-0000-000000000905' and scope_type = 'market';

select extensions.is(
  (select count(*)::bigint from public.api_search('hemograma api', 'health_diagnostics', 19.04, -98.20, null, 1)),
  1::bigint,
  'api_search returns one provider row'
);
select extensions.is(
  (select amount_minor from public.api_search('hemograma api', 'health_diagnostics', 19.04, -98.20, null, 1) limit 1),
  12345::bigint,
  'api_search includes current price'
);
select extensions.ok(
  (select distance_meters is not null from public.api_search('hemograma api', 'health_diagnostics', 19.04, -98.20, null, 1) limit 1),
  'api_search calculates distance when coordinates are provided'
);
select extensions.ok(
  (select abs(latitude - 19.0401) < 0.0001 from public.api_search('hemograma api', 'health_diagnostics', 19.04, -98.20, null, 1) limit 1),
  'api_search returns latitude in latitude field'
);
select extensions.ok(
  (select abs(longitude - (-98.2001)) < 0.0001 from public.api_search('hemograma api', 'health_diagnostics', 19.04, -98.20, null, 1) limit 1),
  'api_search returns longitude in longitude field'
);
select extensions.is(
  (select count(*)::bigint from public.api_search('---', 'health_diagnostics', null, null, null, 20)),
  0::bigint,
  'api_search rejects queries that normalize to empty text'
);

insert into ingest.normalization_runs(id, input_type, provider_brand_id, raw_text, normalized_input, engine_version, status)
values ('00000000-0000-0000-0000-000000000906', 'manual', '00000000-0000-0000-0000-000000000901', 'Hemograma API', 'hemograma api', 'test', 'ambiguous');
insert into auth.users(id, aud, role, email, created_at, updated_at, is_sso_user, is_anonymous)
values ('00000000-0000-0000-0000-000000000999', 'authenticated', 'authenticated', 'admin-review-test@example.invalid', now(), now(), false, false)
on conflict (id) do nothing;
insert into ingest.normalization_candidates(normalization_run_id, catalog_item_id, rank, score, method, explanation_data)
values ('00000000-0000-0000-0000-000000000906', '00000000-0000-0000-0000-000000000904', 1, 0.95, 'trigram', '{"source":"pgtap"}'::jsonb);
select public.api_admin_update_alias(
  '00000000-0000-0000-0000-000000000906',
  '00000000-0000-0000-0000-000000000904',
  'BH API',
  null,
  'Fixture manual review',
  '00000000-0000-0000-0000-000000000999'
);
select extensions.is(
  (select status from ingest.normalization_runs where id = '00000000-0000-0000-0000-000000000906'),
  'resolved',
  'admin alias update resolves normalization run'
);
select extensions.is(
  (select count(*)::bigint from catalog.item_aliases where item_id = '00000000-0000-0000-0000-000000000904' and normalized_alias = 'bh api'),
  1::bigint,
  'admin alias update creates approved provider alias'
);
select extensions.is(
  (select count(*)::bigint from audit.events where action = 'normalization.approve_candidate' and entity_id = '00000000-0000-0000-0000-000000000906'),
  1::bigint,
  'admin alias update writes an audit event'
);
select extensions.is(
  (select count(*)::bigint from public.api_admin_catalog_items('api fixture', 10)),
  1::bigint,
  'admin catalog lookup returns the canonical fixture'
);

insert into ingest.normalization_runs(id, input_type, provider_brand_id, raw_text, normalized_input, engine_version, status)
values ('00000000-0000-0000-0000-000000000907', 'crawler', '00000000-0000-0000-0000-000000000901', 'Etiqueta scraper', 'etiqueta scraper', 'test', 'no_match');
select extensions.ok(
  (public.api_admin_add_manual_candidate(
    '00000000-0000-0000-0000-000000000907',
    '00000000-0000-0000-0000-000000000904',
    '00000000-0000-0000-0000-000000000999',
     'La evidencia del scraper coincide con el servicio canonico',
     'req-9071'
  )->>'created')::boolean,
  'manual candidate is created only through the active catalog'
);
select extensions.is(
  (select method from ingest.normalization_candidates where normalization_run_id = '00000000-0000-0000-0000-000000000907'),
  'manual',
  'manual catalog selection is explicitly marked manual'
);
select extensions.is(
  public.api_admin_review_normalization(
    '00000000-0000-0000-0000-000000000907',
    'approve_candidate',
    (select id from ingest.normalization_candidates where normalization_run_id = '00000000-0000-0000-0000-000000000907'),
    'Etiqueta scraper',
    'Aprobada tras revisar evidencia',
     '00000000-0000-0000-0000-000000000999',
     'req-9071-review'
  )->>'status',
  'resolved',
  'manual candidate approval resolves the run'
);
select extensions.is(
  (select status from ingest.normalization_runs where id = '00000000-0000-0000-0000-000000000907'),
  'resolved',
  'approved manual candidate updates normalization status'
);
select extensions.is(
  (select count(*)::bigint from catalog.item_aliases where item_id = '00000000-0000-0000-0000-000000000904' and normalized_alias = 'etiqueta scraper'),
  1::bigint,
  'approved manual candidate creates the alias'
);
select extensions.is(
   (select count(*)::bigint from audit.events where action = 'normalization.approve_candidate' and entity_id = '00000000-0000-0000-0000-000000000907' and request_id = 'req-9071-review'),
   1::bigint,
   'normalization approval stores the request id in the audit column'
);
select extensions.is(
  (public.api_admin_review_normalization(
    '00000000-0000-0000-0000-000000000907',
    'approve_candidate',
    (select id from ingest.normalization_candidates where normalization_run_id = '00000000-0000-0000-0000-000000000907'),
    'Etiqueta scraper',
    'Aprobada tras revisar evidencia',
    '00000000-0000-0000-0000-000000000999',
    'req-9071-review'
  )->>'status'),
  'resolved',
  'repeating the same review request returns the committed decision'
);

insert into ingest.normalization_runs(id, input_type, raw_text, normalized_input, engine_version, status)
values ('00000000-0000-0000-0000-000000000909', 'search', 'Busqueda sin alias', 'busqueda sin alias', 'test', 'ambiguous');
insert into ingest.normalization_candidates(normalization_run_id, catalog_item_id, rank, score, method, explanation_data)
values ('00000000-0000-0000-0000-000000000909', '00000000-0000-0000-0000-000000000904', 1, 0.95, 'trigram', '{}'::jsonb);
select extensions.is(
  (public.api_admin_review_normalization(
    '00000000-0000-0000-0000-000000000909',
    'approve_candidate',
    (select id from ingest.normalization_candidates where normalization_run_id = '00000000-0000-0000-0000-000000000909'),
    null,
    'Aprobada como equivalencia puntual de búsqueda',
    '00000000-0000-0000-0000-000000000999',
    'req-9091'
  )->>'status'),
  'resolved',
  'unscoped search approval resolves without creating a global alias'
);
select extensions.is(
  (select count(*)::bigint from catalog.item_aliases where normalized_alias = 'busqueda sin alias'),
  0::bigint,
  'unscoped search approval cannot create a global alias'
);

insert into ingest.normalization_runs(id, input_type, raw_text, normalized_input, engine_version, status)
values ('00000000-0000-0000-0000-000000000908', 'search', 'texto no clinico', 'texto no clinico', 'test', 'ambiguous');
select extensions.is(
  public.api_admin_review_normalization(
    '00000000-0000-0000-0000-000000000908',
    'no_match',
    null,
    null,
    'No corresponde a un servicio clinico del catalogo',
    '00000000-0000-0000-0000-000000000999',
    'req-9081'
  )->>'decision',
  'no_match',
  'admin can explicitly reject a no-match case with a reason'
);
select extensions.is(
  (select status from ingest.normalization_runs where id = '00000000-0000-0000-0000-000000000908'),
  'no_match',
  'no-match decision leaves the run closed as no_match'
);
select extensions.is(
  (select count(*)::bigint from ingest.normalization_decisions where normalization_run_id = '00000000-0000-0000-0000-000000000908' and decision_type = 'no_match'),
  1::bigint,
  'no-match decision is persisted'
);

select extensions.is(
  (public.api_record_resolution_review(
    jsonb_build_object(
      'status', 'ambiguous',
      'normalized_query', 'scoped capture fixture',
      'engine_version', 'test-scoped',
      'candidates', jsonb_build_array(jsonb_build_object(
        'service_id', '00000000-0000-0000-0000-000000000904',
        'confidence', 0.88,
        'match_method', 'trigram'
      ))
    ),
    'search',
    'default'
  )->>'created'),
  'true',
  'review capture creates the first scoped queue record'
);
select extensions.is(
  (public.api_record_resolution_review(
    jsonb_build_object(
      'status', 'ambiguous',
      'normalized_query', 'scoped capture fixture',
      'engine_version', 'test-scoped',
      'candidates', jsonb_build_array(jsonb_build_object(
        'service_id', '00000000-0000-0000-0000-000000000904',
        'confidence', 0.88,
        'match_method', 'trigram'
      ))
    ),
    'search',
    'default'
  )->>'created'),
  'false',
  'review capture deduplicates an identical candidate fingerprint'
);
select extensions.is(
  (public.api_record_resolution_review(
    jsonb_build_object(
      'status', 'ambiguous',
      'normalized_query', 'scoped capture fixture',
      'engine_version', 'test-scoped',
      'candidates', jsonb_build_array(jsonb_build_object(
        'service_id', '00000000-0000-0000-0000-000000000904',
        'confidence', 0.88,
        'match_method', 'trigram'
      ))
    ),
    'search',
    'health_diagnostics'
  )->>'created'),
  'true',
  'review capture separates records by domain scope'
);
select extensions.is(
  (select count(*)::bigint from ingest.normalization_runs where normalized_input = 'scoped capture fixture' and review_scope = 'health_diagnostics'),
  1::bigint,
  'scoped capture stores the domain in the normalization run'
);

select * from extensions.finish();
rollback;
