-- Read-only identity probe for private provider-SKU draft design.
-- Do not treat a SKU as a canonical clinical concept, offer or branch scope.

with awaiting as materialized (
  select nr.id, nr.provider_brand_id, nr.normalized_input,
         rr.source_id,
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
), label_groups as (
  select provider_brand_id, normalized_input,
         count(*)::bigint as rows,
         count(distinct provider_sku)::bigint as distinct_skus
  from awaiting
  group by provider_brand_id, normalized_input
), sku_groups as (
  select provider_brand_id, provider_sku,
         count(*)::bigint as rows,
         count(distinct normalized_input)::bigint as distinct_labels,
         count(distinct source_id)::bigint as distinct_sources
  from awaiting
  where provider_sku is not null and provider_brand_id is not null
  group by provider_brand_id, provider_sku
)
select
  (select count(*)::bigint from awaiting) as open_rows,
  (select count(*)::bigint from label_groups) as provider_label_groups,
  (select count(*)::bigint from label_groups where distinct_skus > 1) as labels_with_multiple_identifiers,
  (select coalesce(sum(rows), 0)::bigint from label_groups where distinct_skus > 1) as rows_in_multiidentifier_labels,
  (select count(*)::bigint from sku_groups) as provider_source_identifier_groups,
  (select count(*)::bigint from sku_groups where distinct_labels > 1) as identifiers_with_multiple_labels,
  (select coalesce(sum(rows), 0)::bigint from sku_groups where distinct_labels > 1) as rows_in_multilabel_identifiers,
  (select coalesce(max(distinct_labels), 0)::bigint from sku_groups) as max_labels_per_identifier,
  (select count(*)::bigint from sku_groups where distinct_sources > 1) as identifiers_across_multiple_sources,
  (select count(*)::bigint from awaiting where provider_sku is null or provider_brand_id is null)
    as rows_without_source_identifier_or_provider;
