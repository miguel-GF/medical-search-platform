-- Keep endpoint freshness in sync with successful ingest runs.

begin;

create or replace function ingest.touch_endpoint_last_success()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'succeeded' and new.finished_at is not null then
    update ingest.source_endpoints
    set last_success_at = greatest(coalesce(last_success_at, new.finished_at), new.finished_at),
        updated_at = now()
    where id = new.source_endpoint_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_ingest_crawl_runs_touch_endpoint_success on ingest.crawl_runs;
create trigger trg_ingest_crawl_runs_touch_endpoint_success
after insert or update of status, finished_at on ingest.crawl_runs
for each row execute function ingest.touch_endpoint_last_success();

update ingest.source_endpoints se
set last_success_at = latest.finished_at,
    updated_at = now()
from (
  select source_endpoint_id, max(finished_at) as finished_at
  from ingest.crawl_runs
  where status = 'succeeded' and finished_at is not null
  group by source_endpoint_id
) latest
where latest.source_endpoint_id = se.id;

commit;
