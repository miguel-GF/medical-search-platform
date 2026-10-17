-- Read-only source-level gate for the open crawler normalization queue.
-- Check the intended linked project before running. No source URL or payload is
-- returned, because those fields may contain tokens or private parameters.

with awaiting as materialized (
  select nr.id, nr.provider_brand_id, nr.normalized_input, nr.raw_record_id,
         rr.source_id,
         coalesce(nullif(rr.payload->>'provider_sku', ''),
                  nullif(rr.payload->>'provider_external_id', ''),
                  nullif(rr.external_record_id, '')) as provider_sku,
         coalesce(nullif(rd.source_url, ''),
                  nullif(rr.payload->>'source_url', ''),
                  nullif(rr.payload->>'product_url', '')) as source_url
  from ingest.normalization_runs nr
  left join ingest.raw_records rr on rr.id = nr.raw_record_id
  left join ingest.raw_documents rd on rd.id = rr.raw_document_id
  where nr.input_type = 'crawler'
    and nr.status in ('pending', 'ambiguous', 'no_match')
    and not exists (
      select 1 from ingest.normalization_decisions d
      where d.normalization_run_id = nr.id
        and d.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
    )
)
select
  coalesce(s.name, '(source missing)') as source_name,
  coalesce(s.source_type, '(missing)') as source_type,
  coalesce(s.status, '(missing)') as source_status,
  coalesce(s.usage_policy_status, '(missing)') as usage_policy_status,
  count(*)::bigint as open_rows,
  count(distinct (a.provider_brand_id, a.normalized_input))::bigint as provider_label_groups,
  count(*) filter (where a.raw_record_id is null)::bigint as rows_without_raw_record,
  count(*) filter (where a.provider_sku is null)::bigint as rows_without_source_identifier,
  count(*) filter (where a.source_url is null or a.source_url !~* '^https://')::bigint as rows_without_https_evidence
from awaiting a
left join ingest.sources s on s.id = a.source_id
group by s.id, s.name, s.source_type, s.status, s.usage_policy_status
order by open_rows desc, source_name;
