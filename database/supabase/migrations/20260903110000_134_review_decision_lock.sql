-- Make the one-final-decision trigger safe under concurrent privileged writes.
-- Historical duplicate decisions are preserved; only new races are blocked.

begin;

create or replace function ingest.prevent_duplicate_final_normalization_decision()
returns trigger
language plpgsql
set search_path = pg_catalog, ingest
as $$
begin
  if new.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match') then
    perform pg_advisory_xact_lock(hashtextextended(new.normalization_run_id::text, 0));
    if exists (
      select 1
      from ingest.normalization_decisions nd
      where nd.normalization_run_id = new.normalization_run_id
        and nd.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
    ) then
      raise exception 'Normalization run already has a final decision';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function ingest.prevent_duplicate_final_normalization_decision() from public, anon, authenticated;
grant execute on function ingest.prevent_duplicate_final_normalization_decision() to service_role;

commit;
