-- Provider profile corrections are proposed changes, never direct writes from
-- a claimant. Approval records the provider portal as a source observation.

begin;

create table identity.provider_change_requests (
  id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references identity.provider_claims(id) on delete restrict,
  provider_location_id uuid not null references core.provider_locations(id) on delete restrict,
  source_id uuid not null references ingest.sources(id) on delete restrict,
  submitted_by uuid not null references auth.users(id) on delete restrict,
  changes jsonb not null,
  status text not null default 'pending' check (status in ('pending','under_review','approved','rejected','cancelled')),
  reviewer_user_id uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz,
  review_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (jsonb_typeof(changes) = 'object' and changes <> '{}'::jsonb),
  check (review_reason is null or length(review_reason) <= 2000)
);

create index identity_provider_change_requests_status_idx
  on identity.provider_change_requests(status, created_at desc);
create index identity_provider_change_requests_location_idx
  on identity.provider_change_requests(provider_location_id, created_at desc);
create index identity_provider_change_requests_claim_idx
  on identity.provider_change_requests(claim_id, created_at desc);

create trigger trg_identity_provider_change_requests_touch_updated_at
before update on identity.provider_change_requests
for each row execute function core.touch_updated_at();

create or replace function public.api_provider_submit_location_change(
  p_claim_id uuid,
  p_provider_location_id uuid,
  p_changes jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, identity, core, ingest, audit
as $$
declare
  v_user_id uuid := auth.uid();
  v_claim identity.provider_claims;
  v_location_brand uuid;
  v_bad_key text;
  v_source_id uuid;
  v_request identity.provider_change_requests;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if p_changes is null or jsonb_typeof(p_changes) <> 'object' or p_changes = '{}'::jsonb then raise exception 'Changes must be a non-empty object'; end if;
  if (select count(*) from jsonb_object_keys(p_changes)) > 12 then raise exception 'Too many profile fields'; end if;
  select key into v_bad_key
  from jsonb_object_keys(p_changes) as key
  where key not in ('name','address_line_1','address_line_2','locality_text','postal_code','phone','whatsapp','email','website_url')
  limit 1;
  if v_bad_key is not null then raise exception 'Field is not editable through provider profile: %', v_bad_key; end if;
  if exists (
    select 1 from jsonb_each(p_changes) e
    where jsonb_typeof(e.value) not in ('string','null')
      or (jsonb_typeof(e.value) = 'string' and length(e.value #>> '{}') > 500)
  ) then raise exception 'Profile fields must be strings or null and at most 500 characters'; end if;
  if p_changes ? 'name' and (p_changes->>'name' is null or trim(p_changes->>'name') = '') then raise exception 'Location name cannot be empty'; end if;

  select * into v_claim
  from identity.provider_claims
  where id = p_claim_id and status = 'approved'
  for update;
  if not found then raise exception 'Approved claim does not exist'; end if;
  select provider_brand_id into v_location_brand
  from core.provider_locations
  where id = p_provider_location_id and status <> 'closed';
  if v_location_brand is null then raise exception 'Provider location does not exist'; end if;
  if v_location_brand is distinct from v_claim.provider_brand_id then raise exception 'Location does not belong to claimed brand'; end if;
  if v_claim.claim_scope_type = 'location' and v_claim.provider_location_id is distinct from p_provider_location_id then raise exception 'Location is outside the claim scope'; end if;
  if not exists (
    select 1 from identity.provider_memberships m
    where m.user_id = v_user_id and m.organization_id = v_claim.organization_id and m.status = 'active'
      and ((m.scope_type = 'brand' and m.provider_brand_id = v_claim.provider_brand_id and m.role in ('brand_admin','editor'))
        or (m.scope_type = 'location' and m.provider_location_id = p_provider_location_id and m.role in ('location_manager','editor')))
  ) then raise exception 'Insufficient provider membership'; end if;

  insert into ingest.sources(name, source_type, provider_brand_id, trust_rank, usage_policy_status, notes)
  values ('Provider portal claim ' || v_claim.id::text, 'provider_portal', v_claim.provider_brand_id, 90, 'approved', 'Authenticated provider profile submission')
  returning id into v_source_id;

  insert into identity.provider_change_requests(claim_id, provider_location_id, source_id, submitted_by, changes)
  values (v_claim.id, p_provider_location_id, v_source_id, v_user_id, p_changes)
  returning * into v_request;

  insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, after_data)
  values (v_user_id, 'user', 'provider.profile_change_submitted', 'identity', 'provider_change_requests', v_request.id,
    jsonb_build_object('claim_id', v_claim.id, 'provider_location_id', p_provider_location_id, 'changes', p_changes));
  return jsonb_build_object('request_id', v_request.id, 'status', v_request.status, 'provider_location_id', p_provider_location_id);
end;
$$;

create or replace function public.api_admin_provider_change_requests(
  p_status text default null,
  p_limit integer default 100
)
returns table (
  request_id uuid,
  claim_id uuid,
  provider_location_id uuid,
  provider_name text,
  provider_location_name text,
  source_id uuid,
  submitted_by uuid,
  changes jsonb,
  status text,
  created_at timestamptz,
  reviewed_at timestamptz,
  review_reason text
)
language sql
stable
security definer
set search_path = public, identity, core
as $$
select r.id, r.claim_id, r.provider_location_id, b.name, l.name, r.source_id, r.submitted_by,
  r.changes, r.status, r.created_at, r.reviewed_at, r.review_reason
from identity.provider_change_requests r
join core.provider_locations l on l.id = r.provider_location_id
join core.provider_brands b on b.id = l.provider_brand_id
where p_status is null or r.status = p_status
order by r.created_at desc
limit greatest(1, least(coalesce(p_limit, 100), 200));
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

revoke all on table identity.provider_change_requests from public, anon, authenticated;
revoke all on function public.api_provider_submit_location_change(uuid, uuid, jsonb) from public;
revoke all on function public.api_admin_provider_change_requests(text, integer) from public;
revoke all on function public.api_admin_review_provider_change(uuid, text, uuid, text) from public;
grant execute on function public.api_provider_submit_location_change(uuid, uuid, jsonb) to authenticated, service_role;
grant execute on function public.api_admin_provider_change_requests(text, integer) to service_role;
grant execute on function public.api_admin_review_provider_change(uuid, text, uuid, text) to service_role;

commit;
