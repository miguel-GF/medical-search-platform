-- Complete the provider lifecycle: evidence-gated approval, membership
-- acceptance and reversible revocation without deleting history.

begin;

alter table identity.provider_claims
  add constraint identity_provider_claims_evidence_metadata_size_check
  check (pg_column_size(evidence_metadata) <= 8192);
alter table identity.provider_verifications
  add constraint identity_provider_verifications_metadata_size_check
  check (pg_column_size(metadata) <= 8192);
alter table identity.verification_documents
  add constraint identity_verification_documents_metadata_size_check
  check (pg_column_size(metadata) <= 8192);

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
    where claim_id = v_claim.id and status in ('pending','accepted')
  ) then
    raise exception 'Claim requires at least one verification document';
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
    update identity.verification_documents
    set status = 'accepted', reviewer_user_id = p_reviewer_user_id, reviewed_at = now(), review_reason = 'Claim approved'
    where claim_id = v_claim.id and status = 'pending';
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

create or replace function public.api_admin_revoke_provider_claim(
  p_claim_id uuid,
  p_reviewer_user_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, identity, core, audit
as $$
declare
  v_claim identity.provider_claims;
begin
  if p_reviewer_user_id is null then raise exception 'Reviewer is required'; end if;
  if nullif(trim(p_reason), '') is null or length(p_reason) > 2000 then raise exception 'Revocation reason is required'; end if;
  select * into v_claim from identity.provider_claims where id = p_claim_id for update;
  if not found then raise exception 'Provider claim does not exist'; end if;
  if v_claim.status <> 'approved' then raise exception 'Only an approved claim can be revoked'; end if;

  update identity.provider_claims
  set status = 'revoked', reviewer_user_id = p_reviewer_user_id, reviewed_at = now(), review_reason = trim(p_reason)
  where id = p_claim_id
  returning * into v_claim;

  if v_claim.claim_scope_type = 'brand' then
    update core.provider_brand_organizations
    set valid_to = current_date
    where claim_id = v_claim.id and valid_to is null;
    update identity.provider_memberships
    set status = 'revoked', revoked_at = now()
    where organization_id = v_claim.organization_id and provider_brand_id = v_claim.provider_brand_id
      and scope_type = 'brand' and status in ('invited','active');
  else
    update core.provider_location_organizations
    set status = 'inactive', valid_to = current_date
    where claim_id = v_claim.id and valid_to is null;
    update identity.provider_memberships
    set status = 'revoked', revoked_at = now()
    where organization_id = v_claim.organization_id and provider_location_id = v_claim.provider_location_id
      and scope_type = 'location' and status in ('invited','active');
  end if;

  insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, after_data)
  values (p_reviewer_user_id, 'admin', 'provider.claim_revoked', 'identity', 'provider_claims', v_claim.id,
    jsonb_build_object('reason', p_reason, 'scope_type', v_claim.claim_scope_type,
      'provider_brand_id', v_claim.provider_brand_id, 'provider_location_id', v_claim.provider_location_id,
      'organization_id', v_claim.organization_id));
  return jsonb_build_object('claim_id', v_claim.id, 'status', v_claim.status, 'reviewed_at', v_claim.reviewed_at);
end;
$$;

create or replace function public.api_provider_accept_membership(p_membership_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, identity, audit
as $$
declare
  v_user_id uuid := auth.uid();
  v_membership identity.provider_memberships;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  update identity.provider_memberships
  set status = 'active', activated_at = coalesce(activated_at, now())
  where id = p_membership_id and user_id = v_user_id and status = 'invited'
  returning * into v_membership;
  if not found then
    select * into v_membership from identity.provider_memberships
    where id = p_membership_id and user_id = v_user_id and status = 'active';
    if not found then raise exception 'Membership invitation does not exist'; end if;
  end if;
  insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, after_data)
  values (v_user_id, 'user', 'provider.membership_accepted', 'identity', 'provider_memberships', v_membership.id,
    jsonb_build_object('scope_type', v_membership.scope_type, 'provider_brand_id', v_membership.provider_brand_id,
      'provider_location_id', v_membership.provider_location_id, 'role', v_membership.role));
  return jsonb_build_object('membership_id', v_membership.id, 'status', v_membership.status, 'role', v_membership.role,
    'scope_type', v_membership.scope_type, 'provider_brand_id', v_membership.provider_brand_id,
    'provider_location_id', v_membership.provider_location_id);
end;
$$;

create or replace function public.api_provider_my_memberships(
  p_status text default null,
  p_limit integer default 100
)
returns table (
  membership_id uuid,
  organization_id uuid,
  organization_name text,
  scope_type text,
  provider_brand_id uuid,
  provider_name text,
  provider_location_id uuid,
  provider_location_name text,
  role text,
  status text,
  invited_by uuid,
  activated_at timestamptz,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public, identity, core
as $$
select m.id, m.organization_id, o.legal_name, m.scope_type, m.provider_brand_id, b.name,
  m.provider_location_id, l.name, m.role, m.status, m.invited_by, m.activated_at, m.created_at
from identity.provider_memberships m
join core.organizations o on o.id = m.organization_id
left join core.provider_brands b on b.id = m.provider_brand_id
left join core.provider_locations l on l.id = m.provider_location_id
where m.user_id = auth.uid()
  and (p_status is null or m.status = p_status)
order by m.created_at desc
limit greatest(1, least(coalesce(p_limit, 100), 200));
$$;

revoke all on function public.api_admin_review_provider_claim(uuid, text, uuid, text) from public;
revoke all on function public.api_admin_revoke_provider_claim(uuid, uuid, text) from public;
revoke all on function public.api_provider_accept_membership(uuid) from public;
revoke all on function public.api_provider_my_memberships(text, integer) from public;
grant execute on function public.api_admin_review_provider_claim(uuid, text, uuid, text) to service_role;
grant execute on function public.api_admin_revoke_provider_claim(uuid, uuid, text) to service_role;
grant execute on function public.api_provider_accept_membership(uuid) to authenticated, service_role;
grant execute on function public.api_provider_my_memberships(text, integer) to authenticated, service_role;

commit;
