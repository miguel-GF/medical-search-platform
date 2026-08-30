-- A rejected fuzzy item must not leak its offers into the package response.
-- The Worker also filters defensively, but the public RPC must be safe alone.

begin;

create or replace function public.apply_package_confidence_guard(p_payload jsonb)
returns jsonb
language sql
immutable
parallel safe
as $$
with rewritten_items as materialized (
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
), safe_indexes as (
  select (item.value->>'index')::integer as item_index
  from jsonb_array_elements((select value from rewritten_items)) item(value)
  where item.value->>'status' = 'resolved'
), safe_offers as (
  select coalesce(jsonb_agg(offer.value order by offer.ordinality), '[]'::jsonb) as value
  from jsonb_array_elements(coalesce(p_payload->'offers', '[]'::jsonb)) with ordinality offer(value, ordinality)
  where exists (
    select 1 from safe_indexes i
    where i.item_index = (offer.value->>'item_index')::integer
  )
)
select p_payload || jsonb_build_object(
  'items', (select value from rewritten_items),
  'offers', (select value from safe_offers)
);
$$;

revoke all on function public.apply_package_confidence_guard(jsonb) from public, anon, authenticated;

commit;
