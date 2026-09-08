-- Keep provider profile-change evidence bounded even when the RPC is called
-- directly through a privileged database role. The API already limits request
-- bodies, but this constraint protects the table and audit trail independently
-- of that perimeter.
begin;

alter table identity.provider_change_requests
  add constraint identity_provider_change_requests_changes_size_check
  check (pg_column_size(changes) <= 8192);

commit;
