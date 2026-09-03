-- Bound the public review-capture side effect and make every Admin mutation
-- safe to retry after a lost response.  The Worker remains the only caller
-- with service_role access; these checks are defense in depth inside SQL.

begin;

create index if not exists audit_events_request_id_idx
  on audit.events(request_id, created_at desc, id desc)
  where request_id is not null;

create index if not exists ingest_search_review_capacity_idx
  on ingest.normalization_runs(status, created_at, id)
  where input_type = 'search' and status in ('pending', 'ambiguous', 'no_match');

create or replace function ingest.admin_request_replay(
  p_request_id text,
  p_action text,
  p_entity_schema text,
  p_entity_table text,
  p_entity_id uuid default null,
  p_expected_after jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
stable
set search_path = pg_catalog, audit, ingest
as $$
declare
  v_request_id text := nullif(trim(p_request_id), '');
  v_event audit.events%rowtype;
begin
  if v_request_id is null then
    return null;
  end if;
  if length(v_request_id) > 96 or v_request_id !~ '^[A-Za-z0-9._:-]{8,96}$' then
    raise exception 'Request id is invalid';
  end if;

  select e.* into v_event
  from audit.events e
  where e.request_id = v_request_id
  order by e.created_at desc, e.id desc
  limit 1;

  if not found then
    return null;
  end if;
  if v_event.action = p_action
     and v_event.entity_schema = p_entity_schema
     and v_event.entity_table = p_entity_table
     and (p_entity_id is null or v_event.entity_id = p_entity_id)
     and coalesce(v_event.after_data, '{}'::jsonb) @> coalesce(p_expected_after, '{}'::jsonb) then
    return coalesce(v_event.after_data, '{}'::jsonb);
  end if;
  raise exception 'Request id was already used for another operation';
end;
$$;

-- Keep the old service-role-only signature useful while routing it through
-- the bounded/cursor-aware implementation.
create or replace function public.api_admin_normalization_queue(
  p_status text default null,
  p_limit integer default 50
)
returns table (
  normalization_run_id uuid,
  raw_text text,
  normalized_input text,
  provider_brand_id uuid,
  provider_brand_name text,
  status text,
  engine_version text,
  created_at timestamptz,
  candidate_count bigint,
  decision_type text,
  decision_reason text
)
language sql
stable
security definer
set search_path = public
as $$
select q.normalization_run_id,
       q.raw_text,
       q.normalized_input,
       q.provider_brand_id,
       q.provider_brand_name,
       q.status,
       q.engine_version,
       q.created_at,
       q.candidate_count,
       q.decision_type,
       q.decision_reason
from public.api_admin_normalization_queue_v2(p_status, null, p_limit, null, null) q;
$$;

create or replace function public.api_admin_add_manual_candidate(
  p_normalization_run_id uuid,
  p_catalog_item_id uuid,
  p_reviewer_user_id uuid,
  p_reason text,
  p_request_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, ingest, catalog, core, health, audit
as $$
declare
  v_run ingest.normalization_runs%rowtype;
  v_candidate ingest.normalization_candidates%rowtype;
  v_rank smallint;
  v_replay jsonb;
  v_request_id text := nullif(trim(p_request_id), '');
begin
  if p_reviewer_user_id is null or not exists (select 1 from auth.users where id = p_reviewer_user_id) then raise exception 'Reviewer is required'; end if;
  if p_catalog_item_id is null then raise exception 'Catalog item is required'; end if;
  if nullif(trim(coalesce(p_reason, '')), '') is null then raise exception 'A reason is required for a manual candidate'; end if;
  if length(coalesce(p_reason, '')) > 1000 then raise exception 'Reason is too long'; end if;

  select * into v_run from ingest.normalization_runs where id = p_normalization_run_id for update;
  if not found then raise exception 'Normalization run does not exist'; end if;

  v_replay := ingest.admin_request_replay(
    v_request_id,
    'normalization.manual_candidate_added',
    'ingest',
    'normalization_candidates',
    null,
    jsonb_build_object('normalization_run_id', v_run.id, 'catalog_item_id', p_catalog_item_id)
  );
  if v_replay is not null then
    select * into v_candidate
    from ingest.normalization_candidates nc
    where nc.normalization_run_id = v_run.id and nc.catalog_item_id = p_catalog_item_id
    order by nc.created_at desc, nc.id desc
    limit 1;
    if not found then raise exception 'The retried manual candidate no longer exists'; end if;
    return jsonb_build_object('normalization_run_id', v_run.id, 'candidate_id', v_candidate.id, 'catalog_item_id', v_candidate.catalog_item_id, 'created', false, 'method', v_candidate.method);
  end if;

  if v_run.status not in ('pending', 'ambiguous', 'no_match') then raise exception 'Normalization run is not awaiting review'; end if;
  if exists (select 1 from ingest.normalization_decisions nd where nd.normalization_run_id = v_run.id and nd.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')) then raise exception 'Normalization run already has a final decision'; end if;
  if not exists (select 1 from catalog.items i join health.services s on s.catalog_item_id = i.id where i.id = p_catalog_item_id and i.status = 'active') then raise exception 'Catalog item must be an active health service'; end if;
  if v_run.review_scope <> 'default' and not exists (
    select 1 from catalog.items i join catalog.domains d on d.id = i.domain_id
    where i.id = p_catalog_item_id and d.code = v_run.review_scope
  ) then raise exception 'Catalog item does not belong to the review scope'; end if;

  select * into v_candidate from ingest.normalization_candidates nc where nc.normalization_run_id = v_run.id and nc.catalog_item_id = p_catalog_item_id for update;
  if found then
    return jsonb_build_object('normalization_run_id', v_run.id, 'candidate_id', v_candidate.id, 'catalog_item_id', v_candidate.catalog_item_id, 'created', false, 'method', v_candidate.method);
  end if;
  select coalesce(max(nc.rank), 0) + 1 into v_rank from ingest.normalization_candidates nc where nc.normalization_run_id = v_run.id;
  if v_rank > 32767 then raise exception 'Normalization run has too many candidates'; end if;

  insert into ingest.normalization_candidates(normalization_run_id, catalog_item_id, rank, score, method, explanation_data)
  values (v_run.id, p_catalog_item_id, v_rank, 0, 'manual', jsonb_build_object('reason', left(trim(p_reason), 1000), 'added_by', p_reviewer_user_id, 'request_id', v_request_id))
  returning * into v_candidate;

  insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, after_data, request_id, metadata)
  values (p_reviewer_user_id, 'admin', 'normalization.manual_candidate_added', 'ingest', 'normalization_candidates', v_candidate.id,
    jsonb_build_object('normalization_run_id', v_run.id, 'catalog_item_id', v_candidate.catalog_item_id, 'candidate_id', v_candidate.id, 'rank', v_candidate.rank, 'method', v_candidate.method), v_request_id,
    jsonb_build_object('reason', left(trim(p_reason), 1000), 'request_id', v_request_id));
  return jsonb_build_object('normalization_run_id', v_run.id, 'candidate_id', v_candidate.id, 'catalog_item_id', v_candidate.catalog_item_id, 'created', true, 'method', v_candidate.method);
end;
$$;

create or replace function public.api_admin_update_alert_status(
  p_alert_id uuid,
  p_status text,
  p_reason text default null,
  p_reviewer_user_id uuid default null,
  p_request_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, ops, audit, ingest
as $$
declare
  v_alert ops.system_alerts%rowtype;
  v_updated ops.system_alerts%rowtype;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_replay jsonb;
  v_request_id text := nullif(trim(p_request_id), '');
begin
  if p_reviewer_user_id is null or not exists (select 1 from auth.users where id = p_reviewer_user_id) then raise exception 'Reviewer is required'; end if;
  if p_status not in ('acknowledged', 'resolved', 'ignored') then raise exception 'Invalid alert status'; end if;
  if length(coalesce(p_reason, '')) > 1000 then raise exception 'Reason is too long'; end if;
  select * into v_alert from ops.system_alerts where id = p_alert_id for update;
  if not found then raise exception 'Alert does not exist'; end if;

  v_replay := ingest.admin_request_replay(v_request_id, 'system_alert.status_changed', 'ops', 'system_alerts', p_alert_id, jsonb_build_object('status', p_status));
  if v_replay is not null then return jsonb_build_object('alert_id', p_alert_id, 'status', v_replay->>'status'); end if;
  if v_alert.status in ('resolved', 'ignored') then raise exception 'Alert is already closed'; end if;

  update ops.system_alerts
  set status = p_status,
      acknowledged_at = case when p_status in ('acknowledged', 'resolved') then coalesce(acknowledged_at, now()) else acknowledged_at end,
      acknowledged_by = case when p_status in ('acknowledged', 'resolved') then coalesce(acknowledged_by, p_reviewer_user_id) else acknowledged_by end,
      resolved_at = case when p_status = 'resolved' then now() else resolved_at end,
      resolved_by = case when p_status = 'resolved' then p_reviewer_user_id else resolved_by end
  where id = p_alert_id
  returning * into v_updated;

  insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, before_data, after_data, request_id, metadata)
  values (p_reviewer_user_id, 'admin', 'system_alert.status_changed', 'ops', 'system_alerts', p_alert_id,
    jsonb_build_object('status', v_alert.status), jsonb_build_object('status', v_updated.status), v_request_id,
    jsonb_build_object('reason', v_reason, 'request_id', v_request_id, 'status', p_status));
  return jsonb_build_object('alert_id', p_alert_id, 'status', v_updated.status);
end;
$$;

create or replace function public.api_admin_update_quality_issue_status(
  p_issue_id uuid,
  p_status text,
  p_reason text default null,
  p_reviewer_user_id uuid default null,
  p_request_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, ingest, audit
as $$
declare
  v_issue ingest.data_quality_issues%rowtype;
  v_updated ingest.data_quality_issues%rowtype;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_replay jsonb;
  v_request_id text := nullif(trim(p_request_id), '');
begin
  if p_reviewer_user_id is null or not exists (select 1 from auth.users where id = p_reviewer_user_id) then raise exception 'Reviewer is required'; end if;
  if p_status not in ('acknowledged', 'resolved', 'ignored') then raise exception 'Invalid quality issue status'; end if;
  if length(coalesce(p_reason, '')) > 1000 then raise exception 'Reason is too long'; end if;
  select * into v_issue from ingest.data_quality_issues where id = p_issue_id for update;
  if not found then raise exception 'Quality issue does not exist'; end if;

  v_replay := ingest.admin_request_replay(v_request_id, 'data_quality.status_changed', 'ingest', 'data_quality_issues', p_issue_id, jsonb_build_object('status', p_status));
  if v_replay is not null then return jsonb_build_object('issue_id', p_issue_id, 'status', v_replay->>'status'); end if;
  if v_issue.status in ('resolved', 'ignored') then raise exception 'Quality issue is already closed'; end if;

  update ingest.data_quality_issues
  set status = p_status,
      resolved_at = case when p_status = 'resolved' then now() else resolved_at end,
      resolved_by = case when p_status = 'resolved' then p_reviewer_user_id else resolved_by end
  where id = p_issue_id
  returning * into v_updated;

  insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, before_data, after_data, request_id, metadata)
  values (p_reviewer_user_id, 'admin', 'data_quality.status_changed', 'ingest', 'data_quality_issues', p_issue_id,
    jsonb_build_object('status', v_issue.status), jsonb_build_object('status', v_updated.status), v_request_id,
    jsonb_build_object('reason', v_reason, 'request_id', v_request_id, 'status', p_status));
  return jsonb_build_object('issue_id', p_issue_id, 'status', v_updated.status);
end;
$$;

revoke all on function ingest.admin_request_replay(text, text, text, text, uuid, jsonb) from public, anon, authenticated;
grant execute on function ingest.admin_request_replay(text, text, text, text, uuid, jsonb) to service_role;
revoke all on function public.api_admin_normalization_queue(text, integer) from public, anon, authenticated;
grant execute on function public.api_admin_normalization_queue(text, integer) to service_role;
revoke all on function public.api_admin_add_manual_candidate(uuid, uuid, uuid, text, text) from public, anon, authenticated;
grant execute on function public.api_admin_add_manual_candidate(uuid, uuid, uuid, text, text) to service_role;
revoke all on function public.api_admin_update_alert_status(uuid, text, text, uuid, text) from public, anon, authenticated;
grant execute on function public.api_admin_update_alert_status(uuid, text, text, uuid, text) to service_role;
revoke all on function public.api_admin_update_quality_issue_status(uuid, text, text, uuid, text) from public, anon, authenticated;
grant execute on function public.api_admin_update_quality_issue_status(uuid, text, text, uuid, text) to service_role;

commit;
