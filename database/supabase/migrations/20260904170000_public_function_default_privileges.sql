-- Fail closed for future public-schema functions.
--
-- PostgREST exposes the public schema. A newly-created function otherwise
-- inherits PostgreSQL's PUBLIC EXECUTE default and can become a Data API
-- endpoint before a reviewer notices it. Existing intentional API grants are
-- unchanged; they remain explicit in their owning migrations.

begin;

alter default privileges in schema public
  revoke execute on functions from public, anon, authenticated;

commit;
