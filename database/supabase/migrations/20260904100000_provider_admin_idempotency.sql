-- Provider-review Admin mutations use the same durable request-id replay
-- contract as normalization/alert mutations. Existing signatures remain as
-- compatibility wrappers for trusted callers that do not supply a request id.

begin;

-- Keep the original state transitions in private helpers. The public overloads
-- below add replay bookkeeping without recursively calling their compatibility
-- wrappers.
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

create or replace function ingest.admin_revoke_provider_claim_core(
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

create or replace function ingest.admin_review_provider_change_core(
  p_request_id uuid,
  p_decision text,
  p_reviewer_user_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, identity, core, ingest, audit
as $$
declare
  v_request identity.provider_change_requests;
  v_before jsonb;
  v_after jsonb;
begin
  if p_reviewer_user_id is null then raise exception 'Reviewer is required'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'Decision must be approved or rejected'; end if;
  if p_reason is not null and length(p_reason) > 2000 then raise exception 'Review reason is too long'; end if;
  select * into v_request from identity.provider_change_requests where id = p_request_id for update;
  if not found then raise exception 'Provider change request does not exist'; end if;
  if v_request.status not in ('pending','under_review') then raise exception 'Change request is not awaiting review'; end if;
  select jsonb_build_object('name', name, 'address_line_1', address_line_1, 'address_line_2', address_line_2,
    'locality_text', locality_text, 'postal_code', postal_code, 'phone', phone, 'whatsapp', whatsapp,
    'email', email, 'website_url', website_url)
  into v_before from core.provider_locations where id = v_request.provider_location_id;

  update identity.provider_change_requests
  set status = p_decision, reviewer_user_id = p_reviewer_user_id, reviewed_at = now(), review_reason = nullif(trim(p_reason), '')
  where id = p_request_id
  returning * into v_request;

  if p_decision = 'approved' then
    update core.provider_locations
    set name = case when v_request.changes ? 'name' then v_request.changes->>'name' else name end,
      normalized_name = case when v_request.changes ? 'name' then core.normalized_text(v_request.changes->>'name') else normalized_name end,
      address_line_1 = case when v_request.changes ? 'address_line_1' then v_request.changes->>'address_line_1' else address_line_1 end,
      address_line_2 = case when v_request.changes ? 'address_line_2' then v_request.changes->>'address_line_2' else address_line_2 end,
      locality_text = case when v_request.changes ? 'locality_text' then v_request.changes->>'locality_text' else locality_text end,
      postal_code = case when v_request.changes ? 'postal_code' then v_request.changes->>'postal_code' else postal_code end,
      phone = case when v_request.changes ? 'phone' then v_request.changes->>'phone' else phone end,
      whatsapp = case when v_request.changes ? 'whatsapp' then v_request.changes->>'whatsapp' else whatsapp end,
      email = case when v_request.changes ? 'email' then v_request.changes->>'email' else email end,
      website_url = case when v_request.changes ? 'website_url' then v_request.changes->>'website_url' else website_url end
    where id = v_request.provider_location_id;
    select jsonb_build_object('name', name, 'address_line_1', address_line_1, 'address_line_2', address_line_2,
      'locality_text', locality_text, 'postal_code', postal_code, 'phone', phone, 'whatsapp', whatsapp,
      'email', email, 'website_url', website_url)
    into v_after from core.provider_locations where id = v_request.provider_location_id;
    insert into ingest.source_observations(source_id, entity_type, entity_id, attribute_name, observed_value, confidence, status)
    values (v_request.source_id, 'provider_location', v_request.provider_location_id, 'provider_profile', v_request.changes, 1.0000, 'accepted');
  else
    v_after := v_before;
  end if;

  insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, before_data, after_data, metadata)
  values (p_reviewer_user_id, 'admin', 'provider.profile_change_reviewed', 'identity', 'provider_change_requests', v_request.id,
    v_before, v_after, jsonb_build_object('decision', p_decision, 'reason', p_reason, 'provider_location_id', v_request.provider_location_id));
  return jsonb_build_object('request_id', v_request.id, 'status', v_request.status, 'provider_location_id', v_request.provider_location_id);
end;
$$;

create or replace function public.api_admin_review_provider_claim(
  p_claim_id uuid,
  p_decision text,
  p_reviewer_user_id uuid,
  p_reason text,
  p_operation_request_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public, identity, core, audit, ingest
as $$
declare
  v_request_id text := nullif(trim(p_operation_request_id), '');
  v_replay jsonb;
  v_result jsonb;
begin
  v_replay := ingest.admin_request_replay(
    v_request_id,
    'provider.claim_reviewed',
    'identity',
    'provider_claims',
    p_claim_id,
    jsonb_build_object('decision', p_decision)
  );
  if v_replay is not null then
    return jsonb_build_object(
      'claim_id', p_claim_id,
      'status', coalesce(v_replay->>'status', p_decision),
      'reviewed_at', v_replay->>'reviewed_at'
    );
  end if;

  v_result := ingest.admin_review_provider_claim_core(p_claim_id, p_decision, p_reviewer_user_id, p_reason);

  if v_request_id is not null then
    update audit.events e
    set request_id = v_request_id,
        after_data = coalesce(e.after_data, '{}'::jsonb) || jsonb_build_object(
          'decision', p_decision,
          'status', p_decision,
          'reviewed_at', v_result->>'reviewed_at'
        ),
        metadata = coalesce(e.metadata, '{}'::jsonb) || jsonb_build_object('request_id', v_request_id)
    where e.id = (
      select candidate.id
      from audit.events candidate
      where candidate.action = 'provider.claim_reviewed'
        and candidate.entity_schema = 'identity'
        and candidate.entity_table = 'provider_claims'
        and candidate.entity_id = p_claim_id
        and candidate.request_id is null
      order by candidate.created_at desc, candidate.id desc
      limit 1
    )
    and e.request_id is null;
    if not found then raise exception 'Provider claim audit event could not be correlated'; end if;
  end if;
  return v_result;
end;
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
set search_path = public, identity, core, audit, ingest
as $$
begin
  return public.api_admin_review_provider_claim(p_claim_id, p_decision, p_reviewer_user_id, p_reason, null);
end;
$$;

create or replace function public.api_admin_revoke_provider_claim(
  p_claim_id uuid,
  p_reviewer_user_id uuid,
  p_reason text,
  p_operation_request_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public, identity, core, audit, ingest
as $$
declare
  v_request_id text := nullif(trim(p_operation_request_id), '');
  v_replay jsonb;
  v_result jsonb;
begin
  v_replay := ingest.admin_request_replay(
    v_request_id,
    'provider.claim_revoked',
    'identity',
    'provider_claims',
    p_claim_id,
    jsonb_build_object('reason', p_reason)
  );
  if v_replay is not null then
    return jsonb_build_object(
      'claim_id', p_claim_id,
      'status', coalesce(v_replay->>'status', 'revoked'),
      'reviewed_at', v_replay->>'reviewed_at'
    );
  end if;

  v_result := ingest.admin_revoke_provider_claim_core(p_claim_id, p_reviewer_user_id, p_reason);

  if v_request_id is not null then
    update audit.events e
    set request_id = v_request_id,
        after_data = coalesce(e.after_data, '{}'::jsonb) || jsonb_build_object(
          'status', 'revoked',
          'reviewed_at', v_result->>'reviewed_at'
        ),
        metadata = coalesce(e.metadata, '{}'::jsonb) || jsonb_build_object('request_id', v_request_id)
    where e.id = (
      select candidate.id
      from audit.events candidate
      where candidate.action = 'provider.claim_revoked'
        and candidate.entity_schema = 'identity'
        and candidate.entity_table = 'provider_claims'
        and candidate.entity_id = p_claim_id
        and candidate.request_id is null
      order by candidate.created_at desc, candidate.id desc
      limit 1
    )
    and e.request_id is null;
    if not found then raise exception 'Provider revocation audit event could not be correlated'; end if;
  end if;
  return v_result;
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
set search_path = public, identity, core, audit, ingest
as $$
begin
  return public.api_admin_revoke_provider_claim(p_claim_id, p_reviewer_user_id, p_reason, null);
end;
$$;

create or replace function public.api_admin_review_provider_change(
  p_request_id uuid,
  p_decision text,
  p_reviewer_user_id uuid,
  p_reason text,
  p_operation_request_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public, identity, core, ingest, audit
as $$
declare
  v_request_id text := nullif(trim(p_operation_request_id), '');
  v_replay jsonb;
  v_result jsonb;
begin
  v_replay := ingest.admin_request_replay(
    v_request_id,
    'provider.profile_change_reviewed',
    'identity',
    'provider_change_requests',
    p_request_id,
    jsonb_build_object('decision', p_decision)
  );
  if v_replay is not null then
    return jsonb_build_object(
      'request_id', p_request_id,
      'status', coalesce(v_replay->>'status', p_decision),
      'provider_location_id', v_replay->>'provider_location_id'
    );
  end if;

  v_result := ingest.admin_review_provider_change_core(p_request_id, p_decision, p_reviewer_user_id, p_reason);

  if v_request_id is not null then
    update audit.events e
    set request_id = v_request_id,
        after_data = coalesce(e.after_data, '{}'::jsonb) || jsonb_build_object(
          'decision', p_decision,
          'status', p_decision,
          'provider_location_id', v_result->>'provider_location_id'
        ),
        metadata = coalesce(e.metadata, '{}'::jsonb) || jsonb_build_object('request_id', v_request_id)
    where e.id = (
      select candidate.id
      from audit.events candidate
      where candidate.action = 'provider.profile_change_reviewed'
        and candidate.entity_schema = 'identity'
        and candidate.entity_table = 'provider_change_requests'
        and candidate.entity_id = p_request_id
        and candidate.request_id is null
      order by candidate.created_at desc, candidate.id desc
      limit 1
    )
    and e.request_id is null;
    if not found then raise exception 'Provider profile audit event could not be correlated'; end if;
  end if;
  return v_result;
end;
$$;

create or replace function public.api_admin_review_provider_change(
  p_request_id uuid,
  p_decision text,
  p_reviewer_user_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, identity, core, ingest, audit
as $$
begin
  return public.api_admin_review_provider_change(p_request_id, p_decision, p_reviewer_user_id, p_reason, null);
end;
$$;

revoke all on function public.api_admin_review_provider_claim(uuid, text, uuid, text, text) from public, anon, authenticated;
grant execute on function public.api_admin_review_provider_claim(uuid, text, uuid, text, text) to service_role;
revoke all on function public.api_admin_review_provider_claim(uuid, text, uuid, text) from public, anon, authenticated;
grant execute on function public.api_admin_review_provider_claim(uuid, text, uuid, text) to service_role;
revoke all on function public.api_admin_revoke_provider_claim(uuid, uuid, text, text) from public, anon, authenticated;
grant execute on function public.api_admin_revoke_provider_claim(uuid, uuid, text, text) to service_role;
revoke all on function public.api_admin_revoke_provider_claim(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.api_admin_revoke_provider_claim(uuid, uuid, text) to service_role;
revoke all on function public.api_admin_review_provider_change(uuid, text, uuid, text, text) from public, anon, authenticated;
grant execute on function public.api_admin_review_provider_change(uuid, text, uuid, text, text) to service_role;
revoke all on function public.api_admin_review_provider_change(uuid, text, uuid, text) from public, anon, authenticated;
grant execute on function public.api_admin_review_provider_change(uuid, text, uuid, text) to service_role;
revoke all on function ingest.admin_review_provider_claim_core(uuid, text, uuid, text) from public, anon, authenticated;
grant execute on function ingest.admin_review_provider_claim_core(uuid, text, uuid, text) to service_role;
revoke all on function ingest.admin_revoke_provider_claim_core(uuid, uuid, text) from public, anon, authenticated;
grant execute on function ingest.admin_revoke_provider_claim_core(uuid, uuid, text) to service_role;
revoke all on function ingest.admin_review_provider_change_core(uuid, text, uuid, text) from public, anon, authenticated;
grant execute on function ingest.admin_review_provider_change_core(uuid, text, uuid, text) to service_role;

commit;
