-- Bound unregistered provider-evidence uploads per claim.
--
-- Storage objects are uploaded before the metadata RPC can register a
-- verification_documents row. Without a quota, a claimant could create an
-- unbounded number of arbitrary UUID objects under their own claim and
-- consume storage. Keep the read helper independent from the quota so
-- existing evidence remains readable after the limit is reached.

begin;

create or replace function public.provider_can_upload_claim_storage(p_name text)
returns boolean
language plpgsql
volatile
security definer
set search_path = pg_catalog, identity, auth, storage
as $$
declare
  v_claim_id uuid;
  v_object_count bigint;
begin
  if not public.provider_can_access_claim_storage(p_name) then
    return false;
  end if;

  begin
    v_claim_id := split_part(p_name, '/', 1)::uuid;
  exception when invalid_text_representation then
    return false;
  end;

  -- Serialize concurrent uploads for the same claim. hashtext is used only
  -- as an advisory-lock key; path/owner validation remains the boundary.
  perform pg_advisory_xact_lock(hashtext(v_claim_id::text));

  select count(*)
    into v_object_count
  from storage.objects o
  where o.bucket_id = 'provider-claims'
    and o.owner_id = auth.uid()::text
    -- Count paths case-insensitively as a defence-in-depth measure. The
    -- canonical lowercase regex above rejects mixed-case names, but counting
    -- all variants also protects the quota if a future policy is loosened or
    -- legacy objects were created before canonicalisation.
    and lower(o.name) like lower(v_claim_id::text) || '/%';

  -- Ten objects of at most 10 MiB each is a bounded per-claim allowance.
  return v_object_count < 10;
end;
$$;

revoke all on function public.provider_can_upload_claim_storage(text)
  from public, anon, authenticated, service_role;
grant execute on function public.provider_can_upload_claim_storage(text)
  to authenticated;

drop policy if exists provider_claim_documents_insert on storage.objects;
create policy provider_claim_documents_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'provider-claims'
  and owner_id = auth.uid()::text
  and public.provider_can_upload_claim_storage(name));

drop policy if exists provider_claim_documents_insert_scope on storage.objects;
create policy provider_claim_documents_insert_scope on storage.objects
as restrictive for insert to authenticated
with check (bucket_id <> 'provider-claims' or
  (owner_id = auth.uid()::text
   and public.provider_can_upload_claim_storage(name)));

commit;
