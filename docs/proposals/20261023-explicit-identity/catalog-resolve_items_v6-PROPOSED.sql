-- PROPOSAL ONLY: DO NOT EXECUTE. D006 approval and isolated evaluation pending.
CREATE OR REPLACE FUNCTION catalog.resolve_items_v6(p_query text, p_domain_code text DEFAULT 'health_diagnostics'::text, p_provider_brand_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 10)
 RETURNS TABLE(item_id uuid, display_name text, matched_term text, term_source text, provider_brand_id uuid, confidence numeric, resolution_status text, match_method text, explanation_data jsonb, result_rank bigint)
 LANGUAGE sql
 STABLE PARALLEL SAFE
 SET search_path TO 'pg_catalog'
AS $function$
with identifier_candidates as materialized (
  select
    i.id as item_id,
    coalesce((
      select n.name
      from catalog.item_names n
      where n.item_id = i.id and n.is_primary
      order by n.created_at desc
      limit 1
    ), i.id::text) as display_name,
    ii.code as matched_term,
    'loinc'::text as term_source,
    null::uuid as provider_brand_id,
    1.0000::numeric as confidence,
    ii.code,
    ii.version,
    ii.mapping_type,
    row_number() over (
      partition by i.id
      order by ii.created_at desc, ii.version desc, ii.id
    ) as item_version_rank
  from catalog.item_identifiers ii
  join catalog.items i on i.id = ii.item_id
  join catalog.domains d on d.id = i.domain_id
  where lower(trim(ii.system)) = 'http://loinc.org'
    and lower(trim(ii.code)) = lower(trim(coalesce(p_query, '')))
    and ii.mapping_type = 'exact'
    and ii.status = 'active'
    and ii.verified = true
    and ii.approved_at is not null
    and i.status = 'active'
    and d.code = p_domain_code
), identifier_matches as materialized (
  select
    c.item_id,
    c.display_name,
    c.matched_term,
    c.term_source,
    c.provider_brand_id,
    c.confidence,
    c.code,
    c.version,
    c.mapping_type,
    count(*) over () as candidate_count,
    row_number() over (order by c.version desc, c.item_id) as result_rank
  from identifier_candidates c
  where c.item_version_rank = 1
), fallback_raw as materialized (
  select r.*
  from catalog.resolve_items_v5(
    p_query,
    p_domain_code,
    p_provider_brand_id,
    greatest(1, least(coalesce(p_limit, 10), 50))
  ) r
), exact_items as materialized (
  select distinct item_id
  from fallback_raw
  where match_method = 'exact'
), fallback_filtered as materialized (
  select r.*
  from fallback_raw r
  where not exists (select 1 from exact_items)
     or r.item_id in (select e.item_id from exact_items e)
), fallback_ranked as (
  select
    f.*,
    count(*) over () as filtered_count,
    count(*) filter (where f.match_method = 'exact') over () as filtered_exact_count,
    row_number() over (order by f.confidence desc, f.display_name) as filtered_rank,
    lead(f.confidence) over (order by f.confidence desc, f.display_name) as next_filtered_confidence
  from fallback_filtered f
)
select
  m.item_id,
  m.display_name,
  m.matched_term,
  m.term_source,
  m.provider_brand_id,
  m.confidence,
  case when m.candidate_count > 1 then 'ambiguous' else 'resolved' end,
  'loinc_exact'::text,
  jsonb_build_object(
    'terminology', 'LOINC',
    'code', m.code,
    'version', m.version,
    'mapping_type', m.mapping_type
  ),
  m.result_rank
from identifier_matches m
union all
select
  f.item_id,
  f.display_name,
  f.matched_term,
  f.term_source,
  f.provider_brand_id,
  f.confidence,
  case
    when coalesce((f.explanation_data->>'requirements_pruned')::boolean,false) then 'ambiguous'
    when f.filtered_exact_count > 1 then 'ambiguous'
    when f.filtered_exact_count = 1 then 'resolved'
    else f.resolution_status
  end,
  f.match_method,
  f.explanation_data || jsonb_build_object(
    'exact_dominance', f.filtered_exact_count = 1,
    'candidate_count_after_exact_filter', f.filtered_count
  ),
  f.filtered_rank
from fallback_ranked f
where not exists (select 1 from identifier_matches)
  and f.filtered_rank <= greatest(1, least(coalesce(p_limit, 10), 50))
order by result_rank
limit greatest(1, least(coalesce(p_limit, 10), 50));
$function$
