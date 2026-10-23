-- PROPOSAL ONLY: DO NOT EXECUTE. D006 approval and isolated evaluation pending.
CREATE OR REPLACE FUNCTION catalog.resolve_items_v4(p_query text, p_domain_code text DEFAULT 'health_diagnostics'::text, p_provider_brand_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 10)
 RETURNS TABLE(item_id uuid, display_name text, matched_term text, term_source text, provider_brand_id uuid, confidence numeric, resolution_status text, match_method text, explanation_data jsonb, result_rank bigint)
 LANGUAGE sql
 STABLE PARALLEL SAFE
 SET search_path TO 'pg_catalog'
AS $function$
with rows as materialized (
  select * from catalog.resolve_items_v3(p_query, p_domain_code, p_provider_brand_id, p_limit)
), ranked as (
  select rows.*, count(*) over () as safe_count
  from rows
)
select r.item_id, r.display_name, r.matched_term, r.term_source,
       r.provider_brand_id, r.confidence,
       case when not coalesce((r.explanation_data->>'exact_identity_literal')::boolean,false)
                 or coalesce((r.explanation_data->>'requirements_pruned')::boolean,false)
                 or coalesce((r.explanation_data->>'prefix_discovery')::boolean,false)
                 or r.safe_count > 1 or r.term_source = 'disambiguation' then 'ambiguous' else 'resolved' end,
       r.match_method,
       r.explanation_data || jsonb_build_object('automatic_identity_policy','exact-reviewed-identity-only-LOCAL'),
       r.result_rank
from ranked r
order by r.result_rank;
$function$
