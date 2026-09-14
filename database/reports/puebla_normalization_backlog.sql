-- Read-only snapshot for prioritizing the interrupted Puebla coverage work.
-- One row per provider + normalized label. Not an approval or publication script.
-- Use only crawler inputs: no patient search/OCR payloads are exported.
with pending as (
  select nr.*
  from ingest.normalization_runs nr
  where nr.input_type = 'crawler'
    and nr.status in ('pending', 'ambiguous', 'no_match')
    and not exists (
      select 1 from ingest.normalization_decisions nd
      where nd.normalization_run_id = nr.id
        and nd.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
    )
)
select p.slug as provider, nr.normalized_input as label,
       count(*) as pending_rows,
       min(nr.created_at) as first_queued_at,
       max(nr.created_at) as last_queued_at
from pending nr
left join core.provider_brands p on p.id = nr.provider_brand_id
group by p.slug, nr.normalized_input
order by pending_rows desc, p.slug, nr.normalized_input;
