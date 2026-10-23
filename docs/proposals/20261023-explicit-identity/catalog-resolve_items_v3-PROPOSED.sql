-- PROPOSAL ONLY: DO NOT EXECUTE. D006 approval and isolated evaluation pending.
CREATE OR REPLACE FUNCTION catalog.resolve_items_v3(p_query text, p_domain_code text DEFAULT 'health_diagnostics'::text, p_provider_brand_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 10)
 RETURNS TABLE(item_id uuid, display_name text, matched_term text, term_source text, provider_brand_id uuid, confidence numeric, resolution_status text, match_method text, explanation_data jsonb, result_rank bigint)
 LANGUAGE sql
 STABLE PARALLEL SAFE
 SET search_path TO 'pg_catalog'
AS $function$
with q as (
  select core.normalized_text(p_query) as normalized_query
), candidates as materialized (
  select r.*
  from catalog.resolve_items_v2(p_query, p_domain_code, p_provider_brand_id, greatest(50, coalesce(p_limit,10) * 4)) r
), guarded as (
  select c.*,
    (
      select count(*)
      from unnest(string_to_array(q.normalized_query, ' ')) as qt(token)
      where length(qt.token) >= 4
        and qt.token not in ('para','como','desde','entre','sobre','este','esta','estos','estas','con','sin','del','las','los','una','uno','por','que','sus','en','de','el','la','y')
        and exists (
          select 1
          from unnest(string_to_array(core.normalized_text(c.matched_term), ' ')) as mt(token)
          where mt.token = qt.token
             or mt.token like qt.token || '%'
             or qt.token like mt.token || '%'
             or extensions.word_similarity(mt.token, qt.token) >= 0.80
        )
    )::integer as meaningful_token_matches,
    (
      select count(*)
      from unnest(string_to_array(q.normalized_query, ' ')) as qt(token)
      where length(qt.token) >= 4
        and qt.token not in ('para','como','desde','entre','sobre','este','esta','estos','estas','con','sin','del','las','los','una','uno','por','que','sus','en','de','el','la','y')
    )::integer as meaningful_token_count
  from candidates c
  cross join q
), lexical_accepted as materialized (
  select g.*
  from guarded g
  where g.match_method in ('exact','alias','disambiguation')
     or (g.meaningful_token_count > 0 and g.meaningful_token_matches = g.meaningful_token_count)
), requirement_checked as materialized (
  select a.*,
    not exists (
      select 1
      from unnest(string_to_array(core.normalized_text(p_query), ' ')) as qt(token)
      where qt.token <> ''
        and qt.token not in ('de','del','el','la','los','las','en')
        and not (qt.token = any(string_to_array(core.normalized_text(a.matched_term), ' ')))
    ) as literal_requirements_present,
    (a.term_source in ('name','alias') and a.match_method in ('exact','alias')
      and a.confidence = 1
      and core.normalized_text(a.matched_term)=core.normalized_text(p_query)) as exact_identity_literal,
    (core.normalized_text(p_query) ~ '^[a-z]{4,40}$'
      and not (core.normalized_text(p_query) = any(string_to_array(core.normalized_text(a.matched_term),' ')))
      and exists(select 1 from unnest(string_to_array(core.normalized_text(a.matched_term),' ')) mt(token)
                 where mt.token like core.normalized_text(p_query)||'%')) as prefix_discovery
  from lexical_accepted a
), accepted as (
  select a.*,
    (not a.exact_identity_literal and exists (select 1 from requirement_checked x where not x.literal_requirements_present)) as requirements_pruned
  from requirement_checked a
  where a.literal_requirements_present or a.prefix_discovery
), ranked as (
  select a.*,
    count(*) over () as candidate_count,
    row_number() over (order by a.confidence desc, a.display_name) as safe_rank
  from accepted a
)
select
  r.item_id,
  r.display_name,
  r.matched_term,
  r.term_source,
  r.provider_brand_id,
  r.confidence,
  case when r.prefix_discovery or r.requirements_pruned or r.candidate_count > 1 then 'ambiguous' else r.resolution_status end as resolution_status,
  r.match_method,
  r.explanation_data || jsonb_build_object(
    'meaningful_token_matches', r.meaningful_token_matches,
    'meaningful_token_count', r.meaningful_token_count,
    'literal_requirements_present', r.literal_requirements_present,
    'requirements_pruned', r.requirements_pruned,
    'prefix_discovery', r.prefix_discovery,
    'exact_identity_literal', r.exact_identity_literal,
    'requirements_policy', 'literal-content-v2-LOCAL-EXPERIMENT'
  ) as explanation_data,
  r.safe_rank as result_rank
from ranked r
where r.safe_rank <= greatest(1, least(coalesce(p_limit,10),50))
order by r.safe_rank;
$function$
