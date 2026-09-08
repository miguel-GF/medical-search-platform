-- Internal Admin/catalog release only. Reopening requires a reviewed migration
-- after the scanner and document review flow are operational, not a UI toggle.
begin;

create policy provider_documents_internal_freeze on storage.objects
as restrictive for all to anon, authenticated
using (bucket_id <> 'provider-claims')
with check (bucket_id <> 'provider-claims');

-- Also block service-role RPC writes: Storage RLS alone cannot protect the
-- metadata/approval boundary. Statement-level means even zero-row calls fail.
create function core.reject_internal_document_write()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  raise exception using errcode = '42501',
    message = 'provider_documents_disabled';
end;
$$;
revoke all on function core.reject_internal_document_write()
  from public, anon, authenticated, service_role;

create trigger internal_document_write_freeze
before insert or update on identity.verification_documents
for each statement execute function core.reject_internal_document_write();

commit;
