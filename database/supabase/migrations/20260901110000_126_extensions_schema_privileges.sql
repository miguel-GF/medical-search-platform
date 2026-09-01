-- Extension objects are provider-managed and retain their system ACLs, but
-- the Data API roles do not need direct access to the extension schema. Public
-- SECURITY DEFINER RPCs execute those functions as their owner.

begin;

revoke all on schema extensions from public, anon, authenticated;

commit;
