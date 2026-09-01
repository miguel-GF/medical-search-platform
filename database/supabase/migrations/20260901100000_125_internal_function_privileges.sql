-- Keep internal helpers and extension routines out of the Data API roles.
-- Schema USAGE is already denied, but function ACLs must also fail closed if
-- a future migration changes schema visibility.

begin;

do $$
declare
  schema_name text;
begin
  foreach schema_name in array array[
    'geo','core','catalog','health','supply','ingest','identity','audit',
    'ops','analytics','marketplace','sensitive','billing','extensions','gis'
  ] loop
    execute format(
      'revoke all on all functions in schema %I from public, anon, authenticated',
      schema_name
    );
    execute format(
      'alter default privileges in schema %I revoke execute on functions from public, anon, authenticated',
      schema_name
    );
  end loop;
end $$;

commit;
