-- Read-only operational snapshot for the crawler normalization backlog.
-- Run against the intended linked project and record the date/environment.
-- The top-100 resolver sample is a triage signal, not clinical approval.

with awaiting as materialized (
  select nr.id, nr.provider_brand_id, nr.normalized_input,
         coalesce(nullif(rr.payload->>'provider_sku', ''),
                  nullif(rr.payload->>'provider_external_id', ''),
                  nullif(rr.external_record_id, '')) as provider_sku
  from ingest.normalization_runs nr
  left join ingest.raw_records rr on rr.id = nr.raw_record_id
  where nr.input_type = 'crawler'
    and nr.status in ('pending', 'ambiguous', 'no_match')
    and not exists (
      select 1 from ingest.normalization_decisions d
      where d.normalization_run_id = nr.id
        and d.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
    )
), groups as materialized (
  select provider_brand_id, normalized_input, count(*)::bigint as rows
  from awaiting
  group by provider_brand_id, normalized_input
), sample as materialized (
  select * from groups order by rows desc, provider_brand_id, normalized_input limit 100
), sample_candidates as (
  select g.rows,
         (select count(*) from catalog.resolve_items_v6(
           g.normalized_input, 'health_diagnostics', g.provider_brand_id, 5
         )) as candidate_count
  from sample g
)
select
  (select count(*) from awaiting) as open_rows,
  (select count(*) from groups) as unique_provider_labels,
  (select count(*) from ingest.admin_exact_normalization_matches()) as exact_eligible_rows,
  (select count(*) from awaiting a where a.provider_sku is not null) as rows_with_source_identifier,
  (select count(*) from awaiting a where exists (
    select 1 from supply.offers o
    join catalog.items i on i.id = o.catalog_item_id and i.status = 'active'
    where o.provider_brand_id = a.provider_brand_id
      and o.provider_sku = a.provider_sku
      and o.status = 'active'
  )) as rows_whose_source_identifier_matches_active_offer_sku,
  (select count(*) from catalog.items where status = 'active') as active_catalog_items,
  (select count(*) from sample_candidates) as sampled_top_groups,
  (select count(*) from sample_candidates where candidate_count = 0) as sampled_without_catalog_candidate,
  (select count(*) from sample_candidates where candidate_count = 1) as sampled_with_one_catalog_candidate,
  (select count(*) from sample_candidates where candidate_count > 1) as sampled_with_ambiguous_catalog_candidates;
