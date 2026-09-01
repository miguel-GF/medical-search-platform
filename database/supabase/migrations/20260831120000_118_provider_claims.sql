-- Provider identity, branch relationships, claims and scoped memberships.
-- Claimants never write core data directly: approved claims create auditable
-- relationships and memberships through SECURITY DEFINER RPCs.

begin;

create table identity.provider_claims (
  id uuid primary key default gen_random_uuid(),
  claim_scope_type text not null check (claim_scope_type in ('brand','location')),
  provider_brand_id uuid not null references core.provider_brands(id) on delete restrict,
  provider_location_id uuid references core.provider_locations(id) on delete restrict,
  organization_id uuid not null references core.organizations(id) on delete restrict,
  claimant_user_id uuid not null references auth.users(id) on delete restrict,
  requested_role text not null check (requested_role in ('brand_admin','location_manager','editor','read_only')),
  relationship_type text not null check (relationship_type in ('owner','operator','franchisee','billing_entity','tenant','other')),
  status text not null default 'pending' check (status in ('pending','under_review','approved','rejected','revoked')),
  reason text,
  evidence_metadata jsonb not null default '{}'::jsonb,
  reviewer_user_id uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz,
  review_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((claim_scope_type = 'brand' and provider_location_id is null)
      or (claim_scope_type = 'location' and provider_location_id is not null)),
  check (reason is null or length(reason) <= 2000),
  check (review_reason is null or length(review_reason) <= 2000),
  check (jsonb_typeof(evidence_metadata) = 'object')
);

create index identity_provider_claims_claimant_idx
  on identity.provider_claims(claimant_user_id, created_at desc);
create index identity_provider_claims_status_idx
  on identity.provider_claims(status, created_at desc);
create index identity_provider_claims_scope_idx
  on identity.provider_claims(provider_brand_id, provider_location_id, status);

create unique index identity_provider_claims_active_uq
  on identity.provider_claims(
    claim_scope_type,
    provider_brand_id,
    coalesce(provider_location_id, '00000000-0000-0000-0000-000000000000'::uuid),
    organization_id
  )
  where status in ('pending','under_review','approved');

create table identity.provider_verifications (
  id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references identity.provider_claims(id) on delete cascade,
  method text not null check (method in ('domain_email','phone','onsite_code','government_document','manual','other')),
  status text not null default 'pending' check (status in ('pending','passed','failed','expired','cancelled')),
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  reviewer_user_id uuid references auth.users(id) on delete restrict,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (notes is null or length(notes) <= 2000),
  check (jsonb_typeof(metadata) = 'object'),
  check (completed_at is null or completed_at >= requested_at)
);

create index identity_provider_verifications_claim_idx
  on identity.provider_verifications(claim_id, created_at desc);

create table identity.verification_documents (
  id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references identity.provider_claims(id) on delete cascade,
  submitted_by uuid not null references auth.users(id) on delete restrict,
  document_type text not null check (document_type in ('rfc','acta_constitutiva','poder_representante','comprobante_domicilio','permiso_operacion','other')),
  object_key text not null,
  sha256 char(64) not null check (sha256 ~ '^[0-9a-fA-F]{64}$'),
  status text not null default 'pending' check (status in ('pending','accepted','rejected','superseded')),
  metadata jsonb not null default '{}'::jsonb,
  reviewer_user_id uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz,
  review_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (length(object_key) between 1 and 512 and position('..' in object_key) = 0),
  check (jsonb_typeof(metadata) = 'object'),
  check (review_reason is null or length(review_reason) <= 2000)
);

create index identity_verification_documents_claim_idx
  on identity.verification_documents(claim_id, created_at desc);
create unique index identity_verification_documents_dedupe_uq
  on identity.verification_documents(claim_id, sha256)
  where status <> 'rejected';

create table identity.provider_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  organization_id uuid not null references core.organizations(id) on delete restrict,
  scope_type text not null check (scope_type in ('organization','brand','location')),
  provider_brand_id uuid references core.provider_brands(id) on delete restrict,
  provider_location_id uuid references core.provider_locations(id) on delete restrict,
  role text not null check (role in ('organization_owner','organization_admin','brand_admin','location_manager','editor','read_only')),
  status text not null default 'invited' check (status in ('invited','active','suspended','revoked')),
  invited_by uuid references auth.users(id) on delete restrict,
  activated_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((scope_type = 'organization' and provider_brand_id is null and provider_location_id is null)
      or (scope_type = 'brand' and provider_brand_id is not null and provider_location_id is null)
      or (scope_type = 'location' and provider_brand_id is not null and provider_location_id is not null)),
  check (revoked_at is null or revoked_at >= created_at)
);

create index identity_provider_memberships_user_idx
  on identity.provider_memberships(user_id, status);
create index identity_provider_memberships_scope_idx
  on identity.provider_memberships(organization_id, scope_type, provider_brand_id, provider_location_id, status);
create unique index identity_provider_memberships_org_uq
  on identity.provider_memberships(user_id, organization_id, role)
  where scope_type = 'organization' and status in ('invited','active');
create unique index identity_provider_memberships_brand_uq
  on identity.provider_memberships(user_id, organization_id, provider_brand_id, role)
  where scope_type = 'brand' and status in ('invited','active');
create unique index identity_provider_memberships_location_uq
  on identity.provider_memberships(user_id, organization_id, provider_location_id, role)
  where scope_type = 'location' and status in ('invited','active');

create table core.provider_location_organizations (
  id uuid primary key default gen_random_uuid(),
  provider_location_id uuid not null references core.provider_locations(id) on delete cascade,
  organization_id uuid not null references core.organizations(id) on delete restrict,
  relationship_type text not null check (relationship_type in ('owner','operator','franchisee','billing_entity','tenant','other')),
  status text not null default 'active' check (status in ('active','inactive')),
  valid_from date not null default current_date,
  valid_to date,
  claim_id uuid references identity.provider_claims(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider_location_id, organization_id, relationship_type, valid_from),
  check (valid_to is null or valid_to >= valid_from)
);

create index core_provider_location_organizations_location_idx
  on core.provider_location_organizations(provider_location_id, status, valid_from);
create index core_provider_location_organizations_org_idx
  on core.provider_location_organizations(organization_id, status, valid_from);

alter table core.provider_brand_organizations
  add column if not exists claim_id uuid references identity.provider_claims(id) on delete set null;

create or replace function core.validate_provider_membership_scope()
returns trigger
language plpgsql
as $$
declare
  v_location_brand uuid;
begin
  if new.scope_type = 'location' then
    select provider_brand_id into v_location_brand
    from core.provider_locations
    where id = new.provider_location_id;
    if v_location_brand is null or v_location_brand is distinct from new.provider_brand_id then
      raise exception 'Provider membership brand and location must match';
    end if;
  elsif new.scope_type = 'brand' and new.provider_brand_id is null then
    raise exception 'Brand membership requires a provider brand';
  end if;
  return new;
end;
$$;

create trigger trg_identity_provider_memberships_validate_scope
before insert or update on identity.provider_memberships
for each row execute function core.validate_provider_membership_scope();

create trigger trg_identity_provider_claims_touch_updated_at
before update on identity.provider_claims for each row execute function core.touch_updated_at();
create trigger trg_identity_provider_verifications_touch_updated_at
before update on identity.provider_verifications for each row execute function core.touch_updated_at();
create trigger trg_identity_verification_documents_touch_updated_at
before update on identity.verification_documents for each row execute function core.touch_updated_at();
create trigger trg_identity_provider_memberships_touch_updated_at
before update on identity.provider_memberships for each row execute function core.touch_updated_at();
create trigger trg_core_provider_location_organizations_touch_updated_at
before update on core.provider_location_organizations for each row execute function core.touch_updated_at();

create or replace function public.api_provider_create_claim(
  p_scope_type text,
  p_provider_brand_id uuid,
  p_provider_location_id uuid,
  p_organization_id uuid,
  p_requested_role text,
  p_relationship_type text,
  p_reason text default null,
  p_evidence_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, identity, core, audit
as $$
declare
  v_user_id uuid := auth.uid();
  v_claim identity.provider_claims;
  v_location_brand uuid;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if p_scope_type not in ('brand','location') then raise exception 'Invalid claim scope'; end if;
  if p_requested_role not in ('brand_admin','location_manager','editor','read_only') then raise exception 'Invalid requested role'; end if;
  if p_relationship_type not in ('owner','operator','franchisee','billing_entity','tenant','other') then raise exception 'Invalid relationship type'; end if;
  if p_provider_brand_id is null or p_organization_id is null then raise exception 'Brand and organization are required'; end if;
  if p_scope_type = 'brand' and p_requested_role not in ('brand_admin','editor','read_only') then raise exception 'Invalid role for brand claim'; end if;
  if p_scope_type = 'location' and (p_provider_location_id is null or p_requested_role not in ('location_manager','editor','read_only')) then raise exception 'Invalid role for location claim'; end if;
  if p_reason is not null and length(p_reason) > 2000 then raise exception 'Reason is too long'; end if;
  if jsonb_typeof(coalesce(p_evidence_metadata, '{}'::jsonb)) <> 'object' then raise exception 'Evidence metadata must be an object'; end if;
  if not exists (select 1 from core.provider_brands where id = p_provider_brand_id and status <> 'closed') then raise exception 'Provider brand does not exist'; end if;
  if not exists (select 1 from core.organizations where id = p_organization_id and status = 'active') then raise exception 'Organization does not exist or is inactive'; end if;
  if p_scope_type = 'location' then
    select provider_brand_id into v_location_brand from core.provider_locations where id = p_provider_location_id and status <> 'closed';
    if v_location_brand is null then raise exception 'Provider location does not exist'; end if;
    if v_location_brand is distinct from p_provider_brand_id then raise exception 'Location does not belong to provider brand'; end if;
  end if;

  insert into identity.provider_claims(
    claim_scope_type, provider_brand_id, provider_location_id, organization_id,
    claimant_user_id, requested_role, relationship_type, reason, evidence_metadata
  ) values (
    p_scope_type, p_provider_brand_id, p_provider_location_id, p_organization_id,
    v_user_id, p_requested_role, p_relationship_type, nullif(trim(p_reason), ''), coalesce(p_evidence_metadata, '{}'::jsonb)
  ) returning * into v_claim;

  insert into identity.provider_verifications(claim_id, method, status, metadata)
  values (v_claim.id, 'manual', 'pending', jsonb_build_object('created_by', 'provider_claim'));

  insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, after_data)
  values (v_user_id, 'user', 'provider.claim_created', 'identity', 'provider_claims', v_claim.id,
    jsonb_build_object('scope_type', v_claim.claim_scope_type, 'provider_brand_id', v_claim.provider_brand_id,
      'provider_location_id', v_claim.provider_location_id, 'organization_id', v_claim.organization_id,
      'requested_role', v_claim.requested_role, 'relationship_type', v_claim.relationship_type));

  return jsonb_build_object('claim_id', v_claim.id, 'status', v_claim.status, 'scope_type', v_claim.claim_scope_type,
    'provider_brand_id', v_claim.provider_brand_id, 'provider_location_id', v_claim.provider_location_id,
    'organization_id', v_claim.organization_id, 'requested_role', v_claim.requested_role);
exception when unique_violation then
  raise exception 'An active claim already exists for this organization and scope';
end;
$$;

create or replace function public.api_provider_my_claims(
  p_status text default null,
  p_limit integer default 50
)
returns table (
  claim_id uuid,
  claim_scope_type text,
  provider_brand_id uuid,
  provider_name text,
  provider_location_id uuid,
  provider_location_name text,
  organization_id uuid,
  organization_name text,
  requested_role text,
  relationship_type text,
  status text,
  reason text,
  created_at timestamptz,
  reviewed_at timestamptz,
  review_reason text
)
language sql
stable
security definer
set search_path = public, identity, core
as $$
select c.id, c.claim_scope_type, c.provider_brand_id, b.name, c.provider_location_id, l.name,
  c.organization_id, o.legal_name, c.requested_role, c.relationship_type, c.status, c.reason,
  c.created_at, c.reviewed_at, c.review_reason
from identity.provider_claims c
join core.provider_brands b on b.id = c.provider_brand_id
left join core.provider_locations l on l.id = c.provider_location_id
join core.organizations o on o.id = c.organization_id
where c.claimant_user_id = auth.uid()
  and (p_status is null or c.status = p_status)
order by c.created_at desc
limit greatest(1, least(coalesce(p_limit, 50), 100));
$$;

create or replace function public.api_provider_add_claim_document(
  p_claim_id uuid,
  p_document_type text,
  p_object_key text,
  p_sha256 text,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, identity, audit
as $$
declare
  v_user_id uuid := auth.uid();
  v_document identity.verification_documents;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if p_document_type not in ('rfc','acta_constitutiva','poder_representante','comprobante_domicilio','permiso_operacion','other') then raise exception 'Invalid document type'; end if;
  if p_object_key is null or length(p_object_key) not between 1 and 512 or position('..' in p_object_key) > 0 then raise exception 'Invalid document object key'; end if;
  if p_sha256 is null or p_sha256 !~ '^[0-9a-fA-F]{64}$' then raise exception 'Invalid SHA-256'; end if;
  if jsonb_typeof(coalesce(p_metadata, '{}'::jsonb)) <> 'object' then raise exception 'Document metadata must be an object'; end if;
  if not exists (select 1 from identity.provider_claims where id = p_claim_id and claimant_user_id = v_user_id and status in ('pending','under_review')) then
    raise exception 'Claim is not available to this user';
  end if;
  insert into identity.verification_documents(claim_id, submitted_by, document_type, object_key, sha256, metadata)
  values (p_claim_id, v_user_id, p_document_type, p_object_key, lower(p_sha256), coalesce(p_metadata, '{}'::jsonb))
  returning * into v_document;
  insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, after_data)
  values (v_user_id, 'user', 'provider.claim_document_added', 'identity', 'verification_documents', v_document.id,
    jsonb_build_object('claim_id', p_claim_id, 'document_type', p_document_type, 'sha256', lower(p_sha256)));
  return jsonb_build_object('document_id', v_document.id, 'claim_id', p_claim_id, 'status', v_document.status);
exception when unique_violation then
  raise exception 'This document has already been submitted for the claim';
end;
$$;

create or replace function public.api_provider_invite_member(
  p_claim_id uuid,
  p_user_id uuid,
  p_role text,
  p_provider_location_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, identity, core, audit
as $$
declare
  v_actor uuid := auth.uid();
  v_claim identity.provider_claims;
  v_scope_type text;
  v_brand_id uuid;
  v_location_id uuid;
  v_membership identity.provider_memberships;
  v_authorized boolean := false;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if p_user_id is null or not exists (select 1 from auth.users where id = p_user_id) then raise exception 'Invited user does not exist'; end if;
  select * into v_claim from identity.provider_claims where id = p_claim_id and status = 'approved';
  if not found then raise exception 'Approved claim does not exist'; end if;
  if p_role not in ('brand_admin','location_manager','editor','read_only') then raise exception 'Invalid membership role'; end if;

  if v_claim.claim_scope_type = 'brand' then
    if p_provider_location_id is null then
      if p_role not in ('brand_admin','editor','read_only') then raise exception 'Invalid role for brand membership'; end if;
      v_scope_type := 'brand'; v_brand_id := v_claim.provider_brand_id; v_location_id := null;
    else
      if p_role not in ('location_manager','editor','read_only') then raise exception 'Invalid role for location membership'; end if;
      if not exists (select 1 from core.provider_locations where id = p_provider_location_id and provider_brand_id = v_claim.provider_brand_id and status <> 'closed') then raise exception 'Location does not belong to claimed brand'; end if;
      v_scope_type := 'location'; v_brand_id := v_claim.provider_brand_id; v_location_id := p_provider_location_id;
    end if;
  else
    if p_provider_location_id is not null and p_provider_location_id is distinct from v_claim.provider_location_id then raise exception 'Location is outside the claim scope'; end if;
    if p_role not in ('location_manager','editor','read_only') then raise exception 'Invalid role for location membership'; end if;
    v_scope_type := 'location'; v_brand_id := v_claim.provider_brand_id; v_location_id := v_claim.provider_location_id;
  end if;

  v_authorized := exists (
    select 1 from identity.provider_memberships m
    where m.user_id = v_actor and m.organization_id = v_claim.organization_id and m.status = 'active'
      and ((m.scope_type = 'organization' and m.role in ('organization_owner','organization_admin'))
        or (m.scope_type = 'brand' and m.provider_brand_id = v_claim.provider_brand_id and m.role = 'brand_admin')
        or (m.scope_type = 'location' and m.provider_location_id = v_location_id and m.role = 'location_manager'))
  );
  if not v_authorized then raise exception 'Insufficient provider membership'; end if;

  insert into identity.provider_memberships(user_id, organization_id, scope_type, provider_brand_id, provider_location_id, role, status, invited_by)
  values (p_user_id, v_claim.organization_id, v_scope_type, v_brand_id, v_location_id, p_role, 'invited', v_actor)
  on conflict do nothing
  returning * into v_membership;
  if v_membership.id is null then
    select * into v_membership from identity.provider_memberships
    where user_id = p_user_id and organization_id = v_claim.organization_id
      and scope_type = v_scope_type
      and provider_brand_id is not distinct from v_brand_id
      and provider_location_id is not distinct from v_location_id
      and role = p_role and status in ('invited','active')
    limit 1;
  end if;
  insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, after_data)
  values (v_actor, 'user', 'provider.member_invited', 'identity', 'provider_memberships', v_membership.id,
    jsonb_build_object('claim_id', p_claim_id, 'user_id', p_user_id, 'scope_type', v_scope_type,
      'provider_brand_id', v_brand_id, 'provider_location_id', v_location_id, 'role', p_role));
  return jsonb_build_object('membership_id', v_membership.id, 'status', v_membership.status, 'role', v_membership.role,
    'scope_type', v_membership.scope_type, 'provider_brand_id', v_membership.provider_brand_id,
    'provider_location_id', v_membership.provider_location_id);
end;
$$;

create or replace function public.api_admin_provider_claims(
  p_status text default null,
  p_limit integer default 100
)
returns table (
  claim_id uuid,
  claim_scope_type text,
  provider_brand_id uuid,
  provider_name text,
  provider_location_id uuid,
  provider_location_name text,
  organization_id uuid,
  organization_name text,
  claimant_user_id uuid,
  requested_role text,
  relationship_type text,
  status text,
  reason text,
  created_at timestamptz,
  reviewed_at timestamptz,
  review_reason text
)
language sql
stable
security definer
set search_path = public, identity, core
as $$
select c.id, c.claim_scope_type, c.provider_brand_id, b.name, c.provider_location_id, l.name,
  c.organization_id, o.legal_name, c.claimant_user_id, c.requested_role, c.relationship_type,
  c.status, c.reason, c.created_at, c.reviewed_at, c.review_reason
from identity.provider_claims c
join core.provider_brands b on b.id = c.provider_brand_id
left join core.provider_locations l on l.id = c.provider_location_id
join core.organizations o on o.id = c.organization_id
where p_status is null or c.status = p_status
order by c.created_at desc
limit greatest(1, least(coalesce(p_limit, 100), 200));
$$;

create or replace function public.api_admin_review_provider_claim(
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
  v_membership identity.provider_memberships;
begin
  if p_reviewer_user_id is null then raise exception 'Reviewer is required'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'Decision must be approved or rejected'; end if;
  if p_reason is not null and length(p_reason) > 2000 then raise exception 'Review reason is too long'; end if;
  select * into v_claim from identity.provider_claims where id = p_claim_id for update;
  if not found then raise exception 'Provider claim does not exist'; end if;
  if v_claim.status not in ('pending','under_review') then raise exception 'Claim is not awaiting review'; end if;

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
    insert into identity.provider_verifications(claim_id, method, status, completed_at, reviewer_user_id, notes)
    values (v_claim.id, 'manual', 'passed', now(), p_reviewer_user_id, 'Claim approved')
    on conflict do nothing;
  end if;

  insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, after_data)
  values (p_reviewer_user_id, 'admin', 'provider.claim_reviewed', 'identity', 'provider_claims', v_claim.id,
    jsonb_build_object('decision', p_decision, 'reason', p_reason, 'scope_type', v_claim.claim_scope_type,
      'provider_brand_id', v_claim.provider_brand_id, 'provider_location_id', v_claim.provider_location_id,
      'organization_id', v_claim.organization_id));
  return jsonb_build_object('claim_id', v_claim.id, 'status', v_claim.status, 'reviewed_at', v_claim.reviewed_at);
end;
$$;

revoke all on table identity.provider_claims, identity.provider_verifications,
  identity.verification_documents, identity.provider_memberships,
  core.provider_location_organizations from public, anon, authenticated;

revoke all on function public.api_provider_create_claim(text, uuid, uuid, uuid, text, text, text, jsonb) from public;
revoke all on function public.api_provider_my_claims(text, integer) from public;
revoke all on function public.api_provider_add_claim_document(uuid, text, text, text, jsonb) from public;
revoke all on function public.api_provider_invite_member(uuid, uuid, text, uuid) from public;
revoke all on function public.api_admin_provider_claims(text, integer) from public;
revoke all on function public.api_admin_review_provider_claim(uuid, text, uuid, text) from public;
grant execute on function public.api_provider_create_claim(text, uuid, uuid, uuid, text, text, text, jsonb) to authenticated, service_role;
grant execute on function public.api_provider_my_claims(text, integer) to authenticated, service_role;
grant execute on function public.api_provider_add_claim_document(uuid, text, text, text, jsonb) to authenticated, service_role;
grant execute on function public.api_provider_invite_member(uuid, uuid, text, uuid) to authenticated, service_role;
grant execute on function public.api_admin_provider_claims(text, integer) to service_role;
grant execute on function public.api_admin_review_provider_claim(uuid, text, uuid, text) to service_role;

commit;
