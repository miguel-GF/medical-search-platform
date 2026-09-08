-- Provider evidence is not trustworthy merely because a claimant supplied an
-- object key and hash. Bind each object to its claim and require a trusted scan
-- plus an explicit document review before a claim can be approved.

begin;

alter table identity.verification_documents
  add column server_sha256 char(64),
  add column detected_mime text,
  add column size_bytes integer,
  add column scan_status text not null default 'pending',
  add column scanned_at timestamptz,
  add column scan_attempts integer not null default 0 check (scan_attempts between 0 and 5),
  add column scan_engine text check (scan_engine is null or length(scan_engine) <= 200),
  add column scan_error_code text check (scan_error_code is null or scan_error_code ~ '^[a-z_]{1,64}$'),
  add column content_verified boolean not null default false,
  add constraint identity_verification_documents_server_sha_check
    check (server_sha256 is null or server_sha256 ~ '^[0-9a-f]{64}$'),
  add constraint identity_verification_documents_mime_check
    check (detected_mime is null or detected_mime in ('application/pdf','image/jpeg','image/png')),
  add constraint identity_verification_documents_size_check
    check (size_bytes is null or size_bytes between 1 and 10485760),
  add constraint identity_verification_documents_scan_status_check
    check (scan_status in ('pending','clean','infected','error')),
  add constraint identity_verification_documents_verified_scan_check
    check (not content_verified or (
      scan_status = 'clean' and scanned_at is not null and server_sha256 is not null
      and detected_mime is not null and size_bytes is not null and scan_engine is not null
    ));

create or replace function core.validate_provider_document()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if (tg_op = 'INSERT' or new.object_key is distinct from old.object_key or new.status = 'accepted') and new.object_key !~ (
    '^provider-claims/' || new.claim_id::text || '/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\.(pdf|jpg|jpeg|png)$'
  ) then
    raise exception 'Document object key must be bound to its claim';
  end if;
  if new.status = 'accepted' and (
    new.content_verified
    and new.scan_status = 'clean'
    and new.server_sha256 = lower(new.sha256)
    and new.detected_mime in ('application/pdf','image/jpeg','image/png')
    and new.size_bytes between 1 and 10485760
    and new.scanned_at is not null
    and new.scan_engine is not null
    and new.reviewer_user_id is not null
    and new.reviewed_at is not null
  ) is not true then
    raise exception 'Document must be scanned, verified and reviewed before acceptance';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_identity_verification_documents_validate on identity.verification_documents;
create trigger trg_identity_verification_documents_validate
before insert or update on identity.verification_documents
for each row execute function core.validate_provider_document();

revoke all on function core.validate_provider_document() from public, anon, authenticated, service_role;

create or replace function public.api_server_record_provider_document_scan(
  p_document_id uuid,
  p_server_sha256 text,
  p_detected_mime text,
  p_size_bytes integer,
  p_scan_status text,
  p_engine_version text,
  p_error_code text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, identity, audit
as $$
declare
  v_document identity.verification_documents;
begin
  if p_scan_status is null or p_scan_status not in ('clean','infected','error') then raise exception 'Invalid scan status'; end if;
  if p_server_sha256 is not null and p_server_sha256 !~ '^[0-9a-fA-F]{64}$' then raise exception 'Invalid server SHA-256'; end if;
  if p_detected_mime is not null and p_detected_mime not in ('application/pdf','image/jpeg','image/png') then raise exception 'Unsupported detected MIME type'; end if;
  if p_size_bytes is not null and p_size_bytes not between 1 and 10485760 then raise exception 'Invalid document size'; end if;
  if p_engine_version is not null and (length(p_engine_version) > 200 or p_engine_version !~ '^ClamAV [0-9]+\.[0-9]+\.[0-9]+/[0-9]+/[A-Za-z0-9 :]+$') then raise exception 'Invalid scan engine version'; end if;
  if p_scan_status in ('clean','infected') and (p_server_sha256 is null or p_size_bytes is null or p_engine_version is null) then raise exception 'Completed scan requires hash, size and engine version'; end if;
  if p_scan_status = 'clean' and p_detected_mime is null then raise exception 'Clean scan requires a supported MIME type'; end if;
  if (p_scan_status = 'error' and (p_error_code is null or p_error_code !~ '^[a-z_]{1,64}$'))
     or (p_scan_status <> 'error' and p_error_code is not null) then raise exception 'Invalid scan error code'; end if;

  update identity.verification_documents
  set server_sha256 = lower(p_server_sha256),
      detected_mime = p_detected_mime,
      size_bytes = p_size_bytes,
      scan_status = p_scan_status,
      scanned_at = now(),
      -- A queue lease already consumed the attempt. Direct service-only
      -- calls (kept for controlled migration tests) consume it here.
      scan_attempts = case when scan_error_code = 'scan_in_progress'
        then scan_attempts else scan_attempts + 1 end,
      scan_engine = p_engine_version,
      scan_error_code = p_error_code,
      content_verified = p_scan_status = 'clean' and lower(p_server_sha256) = lower(sha256)
  where id = p_document_id and status = 'pending' and scan_status in ('pending','error')
    and (
      (scan_error_code = 'scan_in_progress' and scan_attempts between 1 and 5)
      or (scan_error_code is distinct from 'scan_in_progress' and scan_attempts < 5)
    )
  returning * into v_document;
  if not found then raise exception 'Retryable pending verification document does not exist'; end if;

  insert into audit.events(actor_type, action, entity_schema, entity_table, entity_id, after_data)
  values ('system', 'provider.claim_document_scanned', 'identity', 'verification_documents', v_document.id,
    jsonb_build_object('scan_status', v_document.scan_status, 'detected_mime', v_document.detected_mime,
      'size_bytes', v_document.size_bytes, 'content_verified', v_document.content_verified,
      'server_sha256', v_document.server_sha256, 'scan_engine', v_document.scan_engine,
      'scan_error_code', v_document.scan_error_code, 'scan_attempts', v_document.scan_attempts));
  return jsonb_build_object('document_id', v_document.id, 'scan_status', v_document.scan_status,
    'content_verified', v_document.content_verified);
end;
$$;

create or replace function public.api_admin_provider_claim_documents(p_claim_id uuid)
returns table (
  document_id uuid,
  claim_id uuid,
  submitted_by uuid,
  document_type text,
  object_key text,
  submitted_sha256 text,
  server_sha256 text,
  detected_mime text,
  size_bytes integer,
  scan_status text,
  scan_attempts integer,
  scan_engine text,
  scan_error_code text,
  content_verified boolean,
  status text,
  created_at timestamptz,
  scanned_at timestamptz,
  reviewed_at timestamptz,
  reviewer_user_id uuid,
  review_reason text
)
language sql
stable
security definer
set search_path = pg_catalog, identity
as $$
select d.id, d.claim_id, d.submitted_by, d.document_type, d.object_key,
  d.sha256::text, d.server_sha256::text, d.detected_mime, d.size_bytes,
  d.scan_status, d.scan_attempts, d.scan_engine, d.scan_error_code, d.content_verified, d.status, d.created_at, d.scanned_at,
  d.reviewed_at, d.reviewer_user_id, d.review_reason
from identity.verification_documents d
where d.claim_id = p_claim_id
order by d.created_at desc;
$$;

create or replace function public.api_admin_review_provider_document(
  p_document_id uuid,
  p_decision text,
  p_reviewer_user_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, identity, audit
as $$
declare
  v_document identity.verification_documents;
begin
  if p_reviewer_user_id is null then raise exception 'Reviewer is required'; end if;
  if p_decision is null or p_decision not in ('accepted','rejected') then raise exception 'Decision must be accepted or rejected'; end if;
  if p_reason is not null and length(p_reason) > 2000 then raise exception 'Review reason is too long'; end if;
  if p_decision = 'rejected' and nullif(trim(p_reason), '') is null then raise exception 'Rejection reason is required'; end if;

  select * into v_document from identity.verification_documents where id = p_document_id for update;
  if not found then raise exception 'Verification document does not exist'; end if;
  if v_document.status <> 'pending' then raise exception 'Verification document is not pending'; end if;
  if p_decision = 'accepted' and (
    v_document.content_verified and v_document.scan_status = 'clean'
    and v_document.server_sha256 = lower(v_document.sha256)
  ) is not true then
    raise exception 'Document has not passed trusted content verification';
  end if;

  update identity.verification_documents
  set status = p_decision, reviewer_user_id = p_reviewer_user_id,
      reviewed_at = now(), review_reason = nullif(trim(p_reason), '')
  where id = p_document_id
  returning * into v_document;

  insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, after_data)
  values (p_reviewer_user_id, 'admin', 'provider.claim_document_reviewed', 'identity', 'verification_documents', v_document.id,
    jsonb_build_object('claim_id', v_document.claim_id, 'decision', p_decision,
      'reason', p_reason, 'scan_status', v_document.scan_status,
      'content_verified', v_document.content_verified, 'server_sha256', v_document.server_sha256));
  return jsonb_build_object('document_id', v_document.id, 'claim_id', v_document.claim_id, 'status', v_document.status);
end;
$$;

-- Replace the current private transition so claim approval cannot accept
-- pending evidence as a side effect.
create or replace function ingest.admin_review_provider_claim_core(
  p_claim_id uuid,
  p_decision text,
  p_reviewer_user_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, identity, core, audit
as $$
declare
  v_claim identity.provider_claims;
  v_updated integer;
begin
  if p_reviewer_user_id is null then raise exception 'Reviewer is required'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'Decision must be approved or rejected'; end if;
  if p_reason is not null and length(p_reason) > 2000 then raise exception 'Review reason is too long'; end if;
  if p_decision = 'rejected' and nullif(trim(p_reason), '') is null then raise exception 'Rejection reason is required'; end if;
  select * into v_claim from identity.provider_claims where id = p_claim_id for update;
  if not found then raise exception 'Provider claim does not exist'; end if;
  if v_claim.status not in ('pending','under_review') then raise exception 'Claim is not awaiting review'; end if;

  if p_decision = 'approved' and not exists (
    select 1 from identity.verification_documents
    where claim_id = v_claim.id and status = 'accepted' and content_verified and scan_status = 'clean'
  ) then
    raise exception 'Claim requires accepted, verified evidence';
  end if;

  update identity.provider_claims
  set status = p_decision, reviewer_user_id = p_reviewer_user_id, reviewed_at = now(), review_reason = nullif(trim(p_reason), '')
  where id = p_claim_id
  returning * into v_claim;

  if p_decision = 'approved' then
    if v_claim.claim_scope_type = 'brand' then
      insert into core.provider_brand_organizations(provider_brand_id, organization_id, relationship_type, claim_id)
      values (v_claim.provider_brand_id, v_claim.organization_id, v_claim.relationship_type, v_claim.id)
      on conflict (provider_brand_id, organization_id, relationship_type, valid_from)
      do update set claim_id = coalesce(core.provider_brand_organizations.claim_id, excluded.claim_id);
      insert into identity.provider_memberships(user_id, organization_id, scope_type, provider_brand_id, role, status, activated_at)
      values (v_claim.claimant_user_id, v_claim.organization_id, 'brand', v_claim.provider_brand_id, v_claim.requested_role, 'active', now())
      on conflict do nothing;
    else
      insert into core.provider_location_organizations(provider_location_id, organization_id, relationship_type, claim_id)
      values (v_claim.provider_location_id, v_claim.organization_id, v_claim.relationship_type, v_claim.id)
      on conflict (provider_location_id, organization_id, relationship_type, valid_from)
      do update set claim_id = coalesce(core.provider_location_organizations.claim_id, excluded.claim_id);
      insert into identity.provider_memberships(user_id, organization_id, scope_type, provider_brand_id, provider_location_id, role, status, activated_at)
      values (v_claim.claimant_user_id, v_claim.organization_id, 'location', v_claim.provider_brand_id, v_claim.provider_location_id, v_claim.requested_role, 'active', now())
      on conflict do nothing;
    end if;

    update identity.provider_verifications
    set status = 'passed', completed_at = now(), reviewer_user_id = p_reviewer_user_id, notes = 'Claim approved'
    where claim_id = v_claim.id and status = 'pending';
    get diagnostics v_updated = row_count;
    if v_updated = 0 then
      insert into identity.provider_verifications(claim_id, method, status, completed_at, reviewer_user_id, notes)
      values (v_claim.id, 'manual', 'passed', now(), p_reviewer_user_id, 'Claim approved');
    end if;
  else
    update identity.verification_documents
    set status = 'rejected', reviewer_user_id = p_reviewer_user_id, reviewed_at = now(), review_reason = p_reason
    where claim_id = v_claim.id and status = 'pending';
  end if;

  insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, after_data)
  values (p_reviewer_user_id, 'admin', 'provider.claim_reviewed', 'identity', 'provider_claims', v_claim.id,
    jsonb_build_object('decision', p_decision, 'reason', p_reason, 'scope_type', v_claim.claim_scope_type,
      'provider_brand_id', v_claim.provider_brand_id, 'provider_location_id', v_claim.provider_location_id,
      'organization_id', v_claim.organization_id));
  return jsonb_build_object('claim_id', v_claim.id, 'status', v_claim.status, 'reviewed_at', v_claim.reviewed_at);
end;
$$;

revoke all on function public.api_server_record_provider_document_scan(uuid, text, text, integer, text, text, text) from public, anon, authenticated, service_role;
revoke all on function public.api_admin_provider_claim_documents(uuid) from public, anon, authenticated, service_role;
revoke all on function public.api_admin_review_provider_document(uuid, text, uuid, text) from public, anon, authenticated, service_role;
grant execute on function public.api_server_record_provider_document_scan(uuid, text, text, integer, text, text, text) to service_role;
grant execute on function public.api_admin_provider_claim_documents(uuid) to service_role;
grant execute on function public.api_admin_review_provider_document(uuid, text, uuid, text) to service_role;

commit;
