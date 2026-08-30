-- Do not treat a weak fuzzy candidate as a clinical equivalence.
-- Exact names, approved aliases, disambiguation terms and strong fuzzy typos
-- remain valid.  Weak fuzzy candidates are retained as suggestions but the
-- public status becomes no_match so an operator/user must confirm them.

begin;

create or replace function public.apply_resolution_confidence_guard(p_payload jsonb)
returns jsonb
language sql
immutable
parallel safe
as $$
with raw_candidates as materialized (
  select c.value, c.ordinality,
    (
      c.value->>'match_method' in ('word_fuzzy', 'trigram')
      and coalesce((c.value->>'confidence')::numeric, 0) < 0.75
    ) as weak
  from jsonb_array_elements(coalesce(p_payload->'candidates', '[]'::jsonb)) with ordinality c(value, ordinality)
), rewritten_candidates as (
  select coalesce(jsonb_agg(
    case when weak then value || jsonb_build_object(
      'resolution_status', 'ambiguous',
      'explanation', coalesce(value->'explanation', '{}'::jsonb) || jsonb_build_object(
        'requires_confirmation', true,
        'confidence_guard', 'min_fuzzy_confidence_0.75'
      )
    ) else value end
    order by ordinality
  ), '[]'::jsonb) as value,
  count(*) filter (where not weak) as safe_count,
  bool_or(not weak and value->>'resolution_status' = 'ambiguous') as safe_ambiguous
  from raw_candidates
), status as (
  select case
    when safe_count = 0 then 'no_match'
    when safe_ambiguous or safe_count > 1 then 'ambiguous'
    else 'resolved'
  end as value
  from rewritten_candidates
)
select p_payload
  || jsonb_build_object(
    'status', (select value from status),
    'candidates', (select value from rewritten_candidates)
  );
$$;

create or replace function public.apply_package_confidence_guard(p_payload jsonb)
returns jsonb
language sql
immutable
parallel safe
as $$
with rewritten_items as (
  select coalesce(jsonb_agg(
    case
      when item.value->>'status' = 'resolved'
       and not exists (
         select 1
         from jsonb_array_elements(coalesce(item.value->'candidates', '[]'::jsonb)) candidate(value)
         where candidate.value->>'match_method' not in ('word_fuzzy', 'trigram')
            or coalesce((candidate.value->>'confidence')::numeric, 0) >= 0.75
       )
      then item.value
        || jsonb_build_object(
          'status', 'no_match',
          'reason_code', 'low_confidence_match',
          'candidates', coalesce((
            select jsonb_agg(candidate.value || jsonb_build_object(
              'resolution_status', 'ambiguous',
              'explanation', coalesce(candidate.value->'explanation', '{}'::jsonb) || jsonb_build_object(
                'requires_confirmation', true,
                'confidence_guard', 'min_fuzzy_confidence_0.75'
              )
            ) order by candidate.ordinality)
            from jsonb_array_elements(coalesce(item.value->'candidates', '[]'::jsonb)) with ordinality candidate(value, ordinality)
          ), '[]'::jsonb)
        )
      else item.value
    end
    order by item.ordinality
  ), '[]'::jsonb) as value
  from jsonb_array_elements(coalesce(p_payload->'items', '[]'::jsonb)) with ordinality item(value, ordinality)
)
select p_payload || jsonb_build_object('items', (select value from rewritten_items));
$$;

-- The existing wrappers are kept as internal/unfiltered implementations and
-- replaced with bounded public wrappers.  This also covers direct PostgREST
-- calls, not only the Worker request validator.
alter function public.api_resolve_search(text, text, double precision, double precision, uuid, integer)
  rename to api_resolve_search_unfiltered;

create or replace function public.api_resolve_search(
  p_query text,
  p_domain_code text default 'health_diagnostics',
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_location_id uuid default null,
  p_limit integer default 20
)
returns jsonb
language sql
stable
parallel safe
security definer
set search_path = public, catalog, core, supply, geo, gis, extensions
as $$
select public.apply_resolution_confidence_guard(public.api_resolve_search_unfiltered(
  p_query, p_domain_code, p_latitude, p_longitude, p_location_id, p_limit
));
$$;

alter function public.api_resolve_package(jsonb, text, double precision, double precision, uuid, integer)
  rename to api_resolve_package_unfiltered;

create or replace function public.api_resolve_package(
  p_items jsonb,
  p_domain_code text default 'health_diagnostics',
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_location_id uuid default null,
  p_limit integer default 10
)
returns jsonb
language sql
stable
parallel safe
security definer
set search_path = public, catalog, core, supply, geo, gis, extensions
as $$
select public.apply_package_confidence_guard(public.api_resolve_package_unfiltered(
  p_items, p_domain_code, p_latitude, p_longitude, p_location_id, p_limit
));
$$;

revoke all on function public.apply_resolution_confidence_guard(jsonb) from public, anon, authenticated;
revoke all on function public.apply_package_confidence_guard(jsonb) from public, anon, authenticated;
revoke all on function public.api_resolve_search_unfiltered(text, text, double precision, double precision, uuid, integer) from public, anon, authenticated;
revoke all on function public.api_resolve_package_unfiltered(jsonb, text, double precision, double precision, uuid, integer) from public, anon, authenticated;
revoke all on function public.api_resolve_search(text, text, double precision, double precision, uuid, integer) from public;
revoke all on function public.api_resolve_package(jsonb, text, double precision, double precision, uuid, integer) from public;
grant execute on function public.api_resolve_search(text, text, double precision, double precision, uuid, integer) to anon, authenticated, service_role;
grant execute on function public.api_resolve_package(jsonb, text, double precision, double precision, uuid, integer) to anon, authenticated, service_role;

commit;
