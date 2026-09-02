-- Deterministically split a free-form prescription line using only the
-- approved catalog vocabulary. No fuzzy, semantic, or AI result is allowed
-- to create a segment automatically.
--
-- The Worker calls this only when its punctuation/line parser produced one
-- item. A disambiguation term may also form a segment, but is tagged
-- `catalog_exact_ambiguous` and never selects an item. A complete exact-token
-- partition is returned as `segmented`; a whole exact catalog phrase is
-- returned as `whole_match`; and no partition or more than one partition is
-- returned without segments so the original text can be sent to the normal
-- resolver for clarification.

begin;

create or replace function public.api_segment_package_text(
  p_text text,
  p_domain_code text default 'health_diagnostics',
  p_max_items integer default 30
)
returns jsonb
language sql
stable
parallel safe
security definer
set search_path = public, catalog, core
as $$
with recursive input as materialized (
  select
    trim(coalesce(p_text, '')) as raw_text,
    left(trim(coalesce(p_text, '')), 4000) as original_text,
    core.normalized_text(left(trim(coalesce(p_text, '')), 4000)) as normalized_text,
    coalesce(nullif(trim(p_domain_code), ''), 'health_diagnostics') as domain_code,
    greatest(1, least(coalesce(p_max_items, 30), 30)) as max_items
), raw_tokens as materialized (
  select
    row_number() over (order by token_no)::integer as token_index,
    token as raw_token,
    core.normalized_text(token) as normalized_token
  from input i
  cross join lateral regexp_split_to_table(i.original_text, '\s+') with ordinality as x(token, token_no)
  where char_length(i.raw_text) between 1 and 4000
    and core.normalized_text(token) <> ''
), token_count as (
  select count(*)::integer as value from raw_tokens
), term_source as materialized (
  select
    n.item_id,
    n.name as surface_text,
    core.normalized_text(n.normalized_name) as normalized_term,
    false as is_ambiguous
  from catalog.item_names n
  join catalog.items i on i.id = n.item_id and i.status = 'active'
  join catalog.domains d on d.id = i.domain_id and d.code = (select domain_code from input)
  where n.locale = 'es-MX'
    and core.normalized_text(n.normalized_name) <> ''
  union all
  select
    a.item_id,
    a.alias as surface_text,
    core.normalized_text(a.normalized_alias) as normalized_term,
    false as is_ambiguous
  from catalog.item_aliases a
  join catalog.items i on i.id = a.item_id and i.status = 'active'
  join catalog.domains d on d.id = i.domain_id and d.code = (select domain_code from input)
  where a.locale = 'es-MX'
    and a.provider_brand_id is null
    and a.status = 'approved'
    and core.normalized_text(a.normalized_alias) <> ''
  union all
  -- A disambiguation phrase is still useful for splitting a line, but it
  -- must not select a service. Its segment is sent back to the normal
  -- resolver, which returns all approved candidates for user confirmation.
  select
    null::uuid as item_id,
    t.term as surface_text,
    core.normalized_text(t.normalized_term) as normalized_term,
    true as is_ambiguous
  from catalog.disambiguation_terms t
  join catalog.disambiguation_candidates dc on dc.term_id = t.id
  join catalog.items i on i.id = dc.item_id and i.status = 'active'
  where (select domain_code from input) = 'health_diagnostics'
    and t.locale = 'es-MX'
    and t.status = 'approved'
    and core.normalized_text(t.normalized_term) <> ''
), terms as materialized (
  select
    ts.normalized_term,
    (array_agg(ts.item_id order by ts.item_id) filter (where ts.item_id is not null))[1] as item_id,
    min(ts.surface_text) as surface_text,
    bool_or(ts.is_ambiguous) as is_ambiguous,
    regexp_split_to_array(ts.normalized_term, '\s+') as term_tokens
  from term_source ts
  group by ts.normalized_term
  -- A unique service phrase is safe to partition. A disambiguation phrase is
  -- also safe to partition lexically, but keeps a null item_id so the regular
  -- resolver can return all candidates for human confirmation.
  having count(distinct ts.item_id) = 1 or bool_or(ts.is_ambiguous)
), whole_matches as materialized (
  select t.item_id, t.surface_text, t.is_ambiguous
  from terms t
  where t.term_tokens = (select array_agg(rt.normalized_token order by rt.token_index) from raw_tokens rt)
), paths (next_token, segments, item_ids, methods) as (
  values (1, array[]::text[], array[]::uuid[], array[]::text[])
  union all
  select
    p.next_token + cardinality(t.term_tokens),
    p.segments || array[array_to_string(array(
      select rt.raw_token
      from raw_tokens rt
      where rt.token_index between p.next_token and p.next_token + cardinality(t.term_tokens) - 1
      order by rt.token_index
    ), ' ')],
    p.item_ids || array[t.item_id],
    p.methods || array[case when t.is_ambiguous then 'catalog_exact_ambiguous' else 'catalog_exact' end]
  from paths p
  join terms t
    on t.term_tokens[1] = (select rt.normalized_token from raw_tokens rt where rt.token_index = p.next_token)
   and p.next_token + cardinality(t.term_tokens) - 1 <= (select value from token_count)
   and t.term_tokens = (select array_agg(rt.normalized_token order by rt.token_index)
                        from raw_tokens rt
                        where rt.token_index between p.next_token and p.next_token + cardinality(t.term_tokens) - 1)
  where cardinality(p.segments) < (select max_items from input)
    -- A prescription is capped at 30 package items by the public API. Keep a
    -- pathological direct RPC call from causing an exponential path search.
    and (select value from token_count) <= 120
), complete_paths as materialized (
  select distinct p.segments, p.item_ids, p.methods
  from paths p
  where p.next_token = (select value + 1 from token_count)
), summary as (
  select
    (select raw_text from input) as raw_text,
    (select original_text from input) as original_text,
    (select normalized_text from input) as normalized_text,
    (select max_items from input) as max_items,
    (select count(*)::integer from raw_tokens) as token_count,
    (select count(*)::integer from whole_matches) as whole_count,
    (select count(*)::integer from complete_paths) as complete_count,
    (select segments from complete_paths limit 1) as segments,
    (select item_ids from complete_paths limit 1) as item_ids,
    (select methods from complete_paths limit 1) as methods,
    (select item_id from whole_matches limit 1) as whole_item_id,
    (select surface_text from whole_matches limit 1) as whole_surface_text,
    (select is_ambiguous from whole_matches limit 1) as whole_ambiguous
)
select jsonb_build_object(
  'original_text', s.original_text,
  'normalized_text', s.normalized_text,
  'engine_version', 'catalog-exact-segmentation-v1',
  'status', case
    when s.original_text = '' or char_length(s.raw_text) > 4000 or s.normalized_text = '' then 'invalid_input'
    when s.token_count > 120 then 'no_match'
    when s.token_count = 0 then 'no_match'
    when s.whole_count = 1 and s.whole_ambiguous then 'whole_match_ambiguous'
    when s.whole_count = 1 then 'whole_match'
    when s.complete_count = 0 then 'no_match'
    when s.complete_count > 1 then 'ambiguous'
    when cardinality(s.segments) < 2 then 'whole_match'
    else 'segmented'
  end,
  'reason', case
    when s.original_text = '' or s.normalized_text = '' then 'empty_text'
    when char_length(s.raw_text) > 4000 then 'text_too_long'
    when s.token_count > 120 then 'too_many_tokens'
    when s.token_count = 0 then 'no_catalog_tokens'
    when s.whole_count = 1 and s.whole_ambiguous then 'whole_ambiguous_catalog_phrase'
    when s.whole_count = 1 then 'whole_catalog_phrase'
    when s.complete_count = 0 then 'no_complete_exact_partition'
    when s.complete_count > 1 then 'multiple_exact_partitions'
    when cardinality(s.segments) < 2 then 'single_catalog_phrase'
    else 'unique_exact_catalog_partition'
  end,
  'segments', case
    when s.whole_count = 1 then jsonb_build_array(jsonb_build_object(
      'index', 1,
      'text', s.original_text,
      'normalized_text', s.normalized_text,
      'item_id', s.whole_item_id,
      'method', case when s.whole_ambiguous then 'catalog_exact_ambiguous' else 'catalog_exact' end
    ))
    when s.complete_count = 1 and cardinality(s.segments) >= 2 then (
      select jsonb_agg(jsonb_build_object(
        'index', x.ordinality::integer,
        'text', x.value,
        'normalized_text', core.normalized_text(x.value),
        'item_id', s.item_ids[x.ordinality::integer],
        'method', s.methods[x.ordinality::integer]
      ) order by x.ordinality)
      from unnest(s.segments) with ordinality as x(value, ordinality)
    )
    else '[]'::jsonb
  end,
  'candidate_partitions', case
    when s.complete_count > 1 then (
      select jsonb_agg(jsonb_build_object('segments', p.segments, 'item_ids', p.item_ids, 'methods', p.methods) order by p.segments::text)
      from complete_paths p
    )
    else '[]'::jsonb
  end
)
from summary s;
$$;

revoke all on function public.api_segment_package_text(text, text, integer) from public;
grant execute on function public.api_segment_package_text(text, text, integer) to anon, authenticated, service_role;

commit;
