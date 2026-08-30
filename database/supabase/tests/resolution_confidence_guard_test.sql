-- Resolver hardening: weak fuzzy matches are suggestions, never clinical
-- equivalences or provider coverage.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(9);

select extensions.has_function(
  'public',
  'apply_resolution_confidence_guard',
  array['jsonb'],
  'search confidence guard exists'
);

select extensions.has_function(
  'public',
  'apply_package_confidence_guard',
  array['jsonb'],
  'package confidence guard exists'
);

select extensions.is(
  (select public.api_resolve_search('Insulina')->>'status'),
  'no_match',
  'weak fuzzy Insulina match is not auto-resolved'
);

select extensions.ok(
  (select public.api_resolve_search('Insulina')->'candidates'->0->'explanation'->>'requires_confirmation')::boolean,
  'weak fuzzy candidate explicitly requires confirmation'
);

select extensions.is(
  (select public.api_resolve_package(jsonb_build_array('Insulina'))->'items'->0->>'reason_code'),
  'low_confidence_match',
  'package marks weak fuzzy candidate with a precise reason'
);

select extensions.is(
  (select jsonb_array_length(public.api_resolve_package(jsonb_build_array('Insulina'))->'offers')),
  0,
  'weak fuzzy package emits no offers'
);

select extensions.is(
  (select public.api_resolve_search('electromiografia de extremidades inferiore')->>'status'),
  'resolved',
  'strong fuzzy typo remains usable'
);

select extensions.is(
  (select public.api_resolve_search('Glucosa')->>'status'),
  'resolved',
  'exact study remains resolved'
);

select extensions.is(
  (select public.apply_resolution_confidence_guard(jsonb_build_object(
    'status', 'ambiguous',
    'candidates', jsonb_build_array(
      jsonb_build_object('match_method', 'exact', 'confidence', 1, 'resolution_status', 'resolved'),
      jsonb_build_object('match_method', 'word_fuzzy', 'confidence', 0.5, 'resolution_status', 'resolved')
    )
  ))->>'status'),
  'ambiguous',
  'weak alternatives never downgrade an ambiguous set'
);

select * from extensions.finish();
rollback;
