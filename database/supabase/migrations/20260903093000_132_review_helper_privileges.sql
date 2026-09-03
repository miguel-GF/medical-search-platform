-- Close the implicit PUBLIC EXECUTE grant on the review hardening helpers.
-- This is separate because 131 may already be present in an environment.

begin;

revoke all on function ingest.redact_sensitive_json(jsonb) from public, anon, authenticated;
revoke all on function ingest.bound_admin_json(jsonb, integer) from public, anon, authenticated;
revoke all on function ingest.prevent_duplicate_final_normalization_decision() from public, anon, authenticated;
revoke all on function ingest.validate_normalization_candidate_scope() from public, anon, authenticated;
grant execute on function ingest.redact_sensitive_json(jsonb) to service_role;
grant execute on function ingest.bound_admin_json(jsonb, integer) to service_role;

commit;
