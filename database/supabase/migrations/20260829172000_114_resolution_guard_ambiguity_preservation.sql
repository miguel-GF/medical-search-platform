-- Do not downgrade an originally ambiguous candidate set just because weak
-- candidates are excluded from the resolved-count calculation.

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
  count(*) filter (where weak) as weak_count,
  bool_or(not weak and value->>'resolution_status' = 'ambiguous') as safe_ambiguous
  from raw_candidates
), status as (
  select case
    when safe_count = 0 then 'no_match'
    when safe_ambiguous or safe_count > 1 or weak_count > 0 then 'ambiguous'
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

revoke all on function public.apply_resolution_confidence_guard(jsonb) from public, anon, authenticated;

commit;
