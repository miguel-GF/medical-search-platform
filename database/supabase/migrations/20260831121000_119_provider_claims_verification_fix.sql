-- Make claim verification transitions deterministic: approve the pending
-- verification created with the claim instead of appending a tied row.

begin;

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
  v_updated integer;
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

    update identity.provider_verifications
    set status = 'passed', completed_at = now(), reviewer_user_id = p_reviewer_user_id, notes = 'Claim approved'
    where claim_id = v_claim.id and status = 'pending';
    get diagnostics v_updated = row_count;
    if v_updated = 0 then
      insert into identity.provider_verifications(claim_id, method, status, completed_at, reviewer_user_id, notes)
      values (v_claim.id, 'manual', 'passed', now(), p_reviewer_user_id, 'Claim approved');
    end if;
  end if;

  insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, after_data)
  values (p_reviewer_user_id, 'admin', 'provider.claim_reviewed', 'identity', 'provider_claims', v_claim.id,
    jsonb_build_object('decision', p_decision, 'reason', p_reason, 'scope_type', v_claim.claim_scope_type,
      'provider_brand_id', v_claim.provider_brand_id, 'provider_location_id', v_claim.provider_location_id,
      'organization_id', v_claim.organization_id));
  return jsonb_build_object('claim_id', v_claim.id, 'status', v_claim.status, 'reviewed_at', v_claim.reviewed_at);
end;
$$;

revoke all on function public.api_admin_review_provider_claim(uuid, text, uuid, text) from public;
grant execute on function public.api_admin_review_provider_claim(uuid, text, uuid, text) to service_role;

commit;
