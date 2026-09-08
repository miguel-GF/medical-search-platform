-- Private Supabase Storage boundary for provider verification evidence.

begin;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('provider-claims', 'provider-claims', false, 10485760,
  array['application/pdf','image/jpeg','image/png']::text[])
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.provider_can_access_claim_storage(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = pg_catalog, identity, auth
as $$
declare
  v_claim_id uuid;
begin
  if p_name is null or p_name !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(pdf|jpg|jpeg|png)$' then return false; end if;
  begin
    v_claim_id := split_part(p_name, '/', 1)::uuid;
  exception when invalid_text_representation then
    return false;
  end;
  return auth.uid() is not null
    and auth.jwt()->>'aal' = 'aal2'
    and exists (
      select 1 from auth.users u
      where u.id = auth.uid() and u.is_anonymous is false
    )
    and exists (
      select 1 from auth.mfa_factors f
      where f.user_id = auth.uid() and f.status = 'verified'
    )
    and exists (
      select 1 from identity.provider_claims c
      where c.id = v_claim_id and c.claimant_user_id = auth.uid()
        and c.status in ('pending','under_review')
    );
end;
$$;

revoke all on function public.provider_can_access_claim_storage(text) from public, anon, authenticated, service_role;
grant execute on function public.provider_can_access_claim_storage(text) to authenticated;

drop policy if exists provider_claim_documents_insert on storage.objects;
create policy provider_claim_documents_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'provider-claims' and owner_id = auth.uid()::text and public.provider_can_access_claim_storage(name));

drop policy if exists provider_claim_documents_select on storage.objects;
create policy provider_claim_documents_select on storage.objects
for select to authenticated
using (bucket_id = 'provider-claims' and owner_id = auth.uid()::text and public.provider_can_access_claim_storage(name));

-- Restrictive policies keep unrelated future permissive bucket policies from
-- authorizing an overwrite, delete, or cross-claim upload for this bucket.
create policy provider_claim_documents_no_update on storage.objects
as restrictive for update to anon, authenticated
using (bucket_id <> 'provider-claims') with check (bucket_id <> 'provider-claims');
create policy provider_claim_documents_no_delete on storage.objects
as restrictive for delete to anon, authenticated
using (bucket_id <> 'provider-claims');
create policy provider_claim_documents_insert_scope on storage.objects
as restrictive for insert to authenticated
with check (bucket_id <> 'provider-claims' or
  (owner_id = auth.uid()::text and public.provider_can_access_claim_storage(name)));
create policy provider_claim_documents_select_scope on storage.objects
as restrictive for select to authenticated
using (bucket_id <> 'provider-claims' or
  (owner_id = auth.uid()::text and public.provider_can_access_claim_storage(name)));
-- anon has no access to the ownership helper. Block this bucket explicitly so
-- a broad policy for another bucket cannot grant anonymous reads or uploads.
create policy provider_claim_documents_anon_no_insert on storage.objects
as restrictive for insert to anon
with check (bucket_id <> 'provider-claims');
create policy provider_claim_documents_anon_no_select on storage.objects
as restrictive for select to anon
using (bucket_id <> 'provider-claims');

-- Deliberately no UPDATE or DELETE policy: evidence is immutable, so bytes
-- cannot be replaced behind a hash after review.

create or replace function core.validate_provider_document()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, storage
as $$
declare
  v_storage_name text;
begin
  if (tg_op = 'INSERT' or new.object_key is distinct from old.object_key or new.status = 'accepted')
    and new.object_key !~ ('^provider-claims/' || new.claim_id::text || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(pdf|jpg|jpeg|png)$') then
    raise exception 'Document object key must be bound to its claim';
  end if;
  v_storage_name := substring(new.object_key from length('provider-claims/') + 1);
  if tg_op = 'INSERT' and not exists (
    select 1 from storage.objects o
    where o.bucket_id = 'provider-claims' and o.name = v_storage_name
      and o.owner_id = new.submitted_by::text
  ) then
    raise exception 'Verification document object does not exist or is not owned by the claimant';
  end if;
  if new.status = 'accepted' and (
    new.content_verified and new.scan_status = 'clean'
    and new.server_sha256 = lower(new.sha256)
    and new.detected_mime in ('application/pdf','image/jpeg','image/png')
    and new.size_bytes between 1 and 10485760 and new.scanned_at is not null and new.scan_engine is not null
    and new.reviewer_user_id is not null and new.reviewed_at is not null
  ) is not true then
    raise exception 'Document must be scanned, verified and reviewed before acceptance';
  end if;
  return new;
end;
$$;

revoke all on function core.validate_provider_document() from public, anon, authenticated, service_role;

commit;
