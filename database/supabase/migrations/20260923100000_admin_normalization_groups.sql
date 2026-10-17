-- Collapse repeated crawler labels into actionable Admin groups.
--
-- This RPC is deliberately read-only. It never proposes or approves a
-- clinical equivalence and never groups patient search/OCR inputs. The
-- representative run can be reviewed with the existing audited workflow;
-- once that review creates a provider-scoped approved alias, the existing
-- exact reprocessor may resolve the remaining repetitions safely.

begin;

create or replace function public.api_admin_normalization_groups(
  p_status text default null,
  p_query text default null,
  p_limit integer default 100,
  p_offset integer default 0
)
returns table (
  representative_run_id uuid,
  input_type text,
  normalized_input text,
  sample_raw_text text,
  provider_brand_id uuid,
  provider_brand_name text,
  source_name text,
  source_type text,
  source_usage_policy_status text,
  provider_sku text,
  source_url text,
  status text,
  occurrence_count bigint,
  distinct_sku_count bigint,
  rows_with_candidates bigint,
  first_queued_at timestamptz,
  last_queued_at timestamptz,
  total_groups bigint
)
language sql
stable
security definer
set search_path = public, ingest, core
as $$
with parameters as (
  select nullif(core.normalized_text(trim(coalesce(p_query, ''))), '') as normalized_query
), awaiting as materialized (
  select
    nr.id,
    nr.raw_record_id,
    nr.raw_text,
    nr.normalized_input,
    nr.provider_brand_id,
    nr.status,
    nr.created_at,
    coalesce(nullif(rr.payload->>'provider_sku', ''),
             nullif(rr.payload->>'provider_external_id', ''),
             nullif(rr.external_record_id, '')) as provider_sku,
    exists (
      select 1
      from ingest.normalization_candidates nc
      where nc.normalization_run_id = nr.id
    ) as has_candidates
  from ingest.normalization_runs nr
  cross join parameters p
  left join core.provider_brands b on b.id = nr.provider_brand_id
  left join ingest.raw_records rr on rr.id = nr.raw_record_id
  left join ingest.sources s on s.id = rr.source_id
  where nr.input_type = 'crawler'
    and nr.status in ('pending', 'ambiguous', 'no_match')
    and nullif(nr.normalized_input, '') is not null
    and (p_status is null or nr.status = p_status)
    and not exists (
      select 1
      from ingest.normalization_decisions nd
      where nd.normalization_run_id = nr.id
        and nd.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
    )
    and (
      p.normalized_query is null
      or nr.normalized_input like '%' || p.normalized_query || '%'
      or core.normalized_text(coalesce(nr.raw_text, '')) like '%' || p.normalized_query || '%'
      or core.normalized_text(coalesce(b.name, '')) like '%' || p.normalized_query || '%'
      or core.normalized_text(coalesce(s.name, '')) like '%' || p.normalized_query || '%'
    )
), grouped as materialized (
  select
    a.provider_brand_id,
    a.normalized_input,
    case
      when bool_or(a.status = 'ambiguous') then 'ambiguous'
      when bool_or(a.status = 'pending') then 'pending'
      else 'no_match'
    end as status,
    count(*)::bigint as occurrence_count,
    count(distinct a.provider_sku)::bigint as distinct_sku_count,
    count(*) filter (where a.has_candidates)::bigint as rows_with_candidates,
    min(a.created_at) as first_queued_at,
    max(a.created_at) as last_queued_at
  from awaiting a
  group by a.provider_brand_id, a.normalized_input
), ranked as (
  select g.*, count(*) over ()::bigint as total_groups
  from grouped g
  order by g.occurrence_count desc, g.last_queued_at desc,
           g.provider_brand_id nulls last, g.normalized_input
  limit greatest(1, least(coalesce(p_limit, 100), 200))
  offset greatest(0, least(coalesce(p_offset, 0), 100000))
)
select
  representative.id,
  'crawler'::text,
  g.normalized_input,
  representative.raw_text,
  g.provider_brand_id,
  b.name,
  s.name,
  s.source_type,
  s.usage_policy_status,
  representative.provider_sku,
  coalesce(nullif(rd.source_url, ''),
           nullif(rr.payload->>'source_url', ''),
           nullif(rr.payload->>'product_url', '')),
  g.status,
  g.occurrence_count,
  g.distinct_sku_count,
  g.rows_with_candidates,
  g.first_queued_at,
  g.last_queued_at,
  g.total_groups
from ranked g
left join core.provider_brands b on b.id = g.provider_brand_id
join lateral (
  select a.id, a.raw_record_id, a.raw_text, a.provider_sku
  from awaiting a
  where a.provider_brand_id is not distinct from g.provider_brand_id
    and a.normalized_input = g.normalized_input
  order by a.has_candidates desc, a.created_at desc, a.id desc
  limit 1
) representative on true
left join ingest.raw_records rr on rr.id = representative.raw_record_id
left join ingest.raw_documents rd on rd.id = rr.raw_document_id
left join ingest.sources s on s.id = rr.source_id
order by g.occurrence_count desc, g.last_queued_at desc,
         g.provider_brand_id nulls last, g.normalized_input;
$$;

revoke all on function public.api_admin_normalization_groups(text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.api_admin_normalization_groups(text, text, integer, integer)
  to service_role;

-- Bounded read-only export of the active names/approved aliases that the
-- offline triage uses. It may suggest candidates but cannot approve them.
create or replace function public.api_admin_catalog_terms(
  p_limit integer default 500,
  p_offset integer default 0
)
returns table (
  item_id uuid,
  display_name text,
  term text,
  normalized_term text,
  term_type text,
  provider_brand_id uuid,
  service_type text
)
language sql
stable
security definer
set search_path = public, catalog, core, health
as $$
with active_items as (
  select i.id, hs.service_type,
         coalesce((
           select n.name from catalog.item_names n
           where n.item_id = i.id and n.is_primary
           order by n.locale = 'es-MX' desc, n.created_at desc
           limit 1
         ), i.id::text) as display_name
  from catalog.items i
  join catalog.domains d on d.id = i.domain_id
    and d.code = 'health_diagnostics'
  join health.services hs on hs.catalog_item_id = i.id
  where i.status = 'active'
), terms as (
  select i.id as item_id, i.display_name, n.name as term,
         n.normalized_name as normalized_term,
         'name'::text as term_type, null::uuid as provider_brand_id,
         i.service_type
  from active_items i
  join catalog.item_names n on n.item_id = i.id
  union all
  select i.id, i.display_name, a.alias, a.normalized_alias,
         'alias'::text, a.provider_brand_id, i.service_type
  from active_items i
  join catalog.item_aliases a on a.item_id = i.id
  where a.status = 'approved'
)
select t.item_id, t.display_name, t.term, t.normalized_term,
       t.term_type, t.provider_brand_id, t.service_type
from terms t
order by t.item_id, t.term_type, t.provider_brand_id nulls first,
         t.normalized_term, t.term
limit greatest(1, least(coalesce(p_limit, 500), 500))
offset greatest(0, least(coalesce(p_offset, 0), 100000));
$$;

revoke all on function public.api_admin_catalog_terms(integer, integer)
  from public, anon, authenticated;
grant execute on function public.api_admin_catalog_terms(integer, integer)
  to service_role;

commit;
