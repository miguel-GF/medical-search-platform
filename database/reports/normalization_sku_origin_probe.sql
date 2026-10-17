-- Read-only field-origin diagnostic. Returns counts/lengths, never raw IDs.
-- A provider SKU must be a stable identity; external_record_id is only a
-- fallback locator and may include branch/crawl-instance material.

with awaiting as materialized (
  select nr.id, rr.source_id, rr.payload,
         nullif(rr.payload->>'provider_sku', '') as payload_sku,
         nullif(rr.payload->>'provider_external_id', '') as payload_external_id,
         nullif(rr.external_record_id, '') as raw_external_id
  from ingest.normalization_runs nr
  left join ingest.raw_records rr on rr.id = nr.raw_record_id
  where nr.input_type = 'crawler'
    and nr.status in ('pending', 'ambiguous', 'no_match')
    and not exists (
      select 1 from ingest.normalization_decisions d
      where d.normalization_run_id = nr.id
        and d.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
    )
)
select coalesce(s.name, '(missing source)') as source_name,
       count(*)::bigint as open_rows,
       count(*) filter (where a.payload_sku is not null)::bigint as payload_provider_sku_rows,
       count(distinct a.payload_sku)::bigint as distinct_payload_provider_skus,
       count(*) filter (where a.payload_sku is null and a.payload_external_id is not null)::bigint
         as payload_external_id_fallback_rows,
       count(*) filter (where a.payload_sku is null and a.payload_external_id is null
                        and a.raw_external_id is not null)::bigint as raw_external_id_fallback_rows,
       min(length(coalesce(a.payload_sku, a.payload_external_id, a.raw_external_id)))::bigint
         as min_identity_length,
       max(length(coalesce(a.payload_sku, a.payload_external_id, a.raw_external_id)))::bigint
         as max_identity_length
from awaiting a
left join ingest.sources s on s.id = a.source_id
group by s.id, s.name
order by open_rows desc, source_name;
