-- Final hardening for the administrative review surface.
-- Search-derived reviews never create global aliases implicitly; decisions are
-- idempotent when a caller retries the same request id; ingest JSON has write
-- limits before it can become an unbounded inspection or storage problem.

begin;

-- The five-argument V1 function was removed by migration 076 in a clean
-- install. Keep this defensive drop for environments that applied migrations
-- out of order. The six/seven-argument compatibility route remains available
-- but delegates to the guarded canonical review function below.
drop function if exists public.api_admin_update_alias(uuid, uuid, text, uuid, text);

create or replace function public.api_admin_review_normalization(
  p_normalization_run_id uuid,
  p_decision text,
  p_selected_candidate_id uuid default null,
  p_alias text default null,
  p_reason text default null,
  p_reviewer_user_id uuid default null,
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
  v_item_name text;
  v_alias text;
  v_normalized_alias text;
  v_brand_id uuid;
  v_alias_id uuid;
  v_previous_status text;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_after jsonb;
  v_existing_action text;
  v_existing_schema text;
  v_existing_table text;
  v_existing_entity_id uuid;
begin
  if p_reviewer_user_id is null or not exists (select 1 from auth.users where id = p_reviewer_user_id) then
    raise exception 'Reviewer is required';
  end if;
  if p_decision not in ('approve_candidate', 'no_match') then
    raise exception 'Decision must be approve_candidate or no_match';
  end if;
  if length(coalesce(p_request_id, '')) > 128 or length(coalesce(p_reason, '')) > 1000 then
    raise exception 'Request id or reason is too long';
  end if;

  if nullif(trim(p_request_id), '') is not null then
    -- Serialize all retries using the same caller id, even when they target
    -- different rows. This closes the race before the audit event exists.
    perform pg_advisory_xact_lock(hashtextextended('admin_request:' || trim(p_request_id), 0));
  end if;

  select * into v_run
  from ingest.normalization_runs
  where id = p_normalization_run_id
  for update;
  if not found then
    raise exception 'Normalization run does not exist';
  end if;

  -- The row lock serializes concurrent retries. Looking up the audit event
  -- after taking it means a retry that lost the first response returns the
  -- committed result instead of reporting a misleading closed-run error.
  if nullif(trim(p_request_id), '') is not null then
    select e.action, e.entity_schema, e.entity_table, e.entity_id, e.after_data
      into v_existing_action, v_existing_schema, v_existing_table, v_existing_entity_id, v_after
    from audit.events e
    where e.request_id = trim(p_request_id)
    order by e.created_at desc, e.id desc
    limit 1;
    if found then
      if v_existing_schema = 'ingest'
         and v_existing_table = 'normalization_runs'
         and v_existing_entity_id = v_run.id
         and ((p_decision = 'approve_candidate' and v_existing_action = 'normalization.approve_candidate')
           or (p_decision = 'no_match' and v_existing_action = 'normalization.no_match')) then
        return coalesce(v_after, '{}'::jsonb)
          || jsonb_build_object(
            'normalization_run_id', v_run.id,
            'decision', p_decision,
            'status', case when p_decision = 'no_match' then 'no_match' else 'resolved' end
          );
      end if;
      raise exception 'Request id was already used for another operation';
    end if;
  end if;

  if v_run.status not in ('pending', 'ambiguous', 'no_match') then
    raise exception 'Normalization run is not awaiting review';
  end if;
  v_previous_status := v_run.status;

  if exists (
    select 1 from ingest.normalization_decisions nd
    where nd.normalization_run_id = v_run.id
      and nd.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
  ) then
    raise exception 'Normalization run already has a final decision';
  end if;

  if p_decision = 'no_match' then
    if v_reason is null then
      raise exception 'A reason is required for no_match';
    end if;
    if p_selected_candidate_id is not null or nullif(trim(coalesce(p_alias, '')), '') is not null then
      raise exception 'no_match cannot include a candidate or alias';
    end if;

    update ingest.normalization_runs
    set status = 'no_match', resolved_at = now()
    where id = v_run.id;

    insert into ingest.normalization_decisions(
      normalization_run_id, selected_item_id, decision_type,
      reviewer_user_id, reason, metadata
    ) values (
      v_run.id, null, 'no_match', p_reviewer_user_id, v_reason,
      jsonb_build_object('decision', 'no_match', 'request_id', p_request_id)
    );

    insert into audit.events(
      actor_user_id, actor_type, action, entity_schema, entity_table, entity_id,
      before_data, after_data, request_id, metadata
    ) values (
      p_reviewer_user_id, 'admin', 'normalization.no_match', 'ingest', 'normalization_runs', v_run.id,
      jsonb_build_object('status', v_previous_status, 'input_type', v_run.input_type),
      jsonb_build_object('status', 'no_match'),
      p_request_id,
      jsonb_build_object('reason', v_reason, 'request_id', p_request_id)
    );

    return jsonb_build_object(
      'normalization_run_id', v_run.id,
      'decision', 'no_match',
      'status', 'no_match'
    );
  end if;

  if p_selected_candidate_id is null then
    raise exception 'A candidate is required for approval';
  end if;

  select * into v_candidate
  from ingest.normalization_candidates nc
  where nc.id = p_selected_candidate_id
    and nc.normalization_run_id = v_run.id
  for update;
  if not found then
    raise exception 'Selected candidate does not belong to normalization run';
  end if;
  if not exists (
    select 1
    from catalog.items i
    join health.services s on s.catalog_item_id = i.id
    where i.id = v_candidate.catalog_item_id and i.status = 'active'
  ) then
    raise exception 'Selected candidate must be an active health service';
  end if;

  v_brand_id := v_run.provider_brand_id;
  -- A search or unscoped run has no provider context. Never turn the operator's
  -- one-off wording into a global alias that changes every future provider's
  -- resolver. Provider-scoped crawler reviews can still create aliases.
  if v_brand_id is null then
    if nullif(trim(coalesce(p_alias, '')), '') is not null then
      raise exception 'A provider-scoped review is required before creating an alias';
    end if;
  else
    v_alias := trim(coalesce(p_alias, v_run.raw_text, v_run.normalized_input, ''));
    if v_alias = '' or length(v_alias) > 200 then
      raise exception 'A valid alias of at most 200 characters is required';
    end if;
    v_normalized_alias := core.normalized_text(v_alias);
    if v_normalized_alias = '' then
      raise exception 'Alias must contain letters or numbers';
    end if;
    if exists (
      select 1 from catalog.item_aliases a
      where a.provider_brand_id is not distinct from v_brand_id
        and a.locale = 'es-MX'
        and a.normalized_alias = v_normalized_alias
        and a.status <> 'rejected'
        and a.item_id <> v_candidate.catalog_item_id
    ) then
      raise exception 'Alias is already assigned to another canonical item';
    end if;

    insert into catalog.item_aliases(
      item_id, alias, normalized_alias, alias_type, provider_brand_id,
      confidence, status, source_note, approved_by, approved_at
    ) values (
      v_candidate.catalog_item_id, v_alias, v_normalized_alias, 'provider_name', v_brand_id,
      1.0000, 'approved', coalesce(v_reason, 'Manual admin review'), p_reviewer_user_id, now()
    ) on conflict do nothing
    returning id into v_alias_id;

    if v_alias_id is null then
      select a.id into v_alias_id
      from catalog.item_aliases a
      where a.item_id = v_candidate.catalog_item_id
        and a.provider_brand_id is not distinct from v_brand_id
        and a.locale = 'es-MX'
        and a.normalized_alias = v_normalized_alias
        and a.status <> 'rejected'
      order by a.created_at desc
      limit 1;
      if v_alias_id is null then
        raise exception 'Alias could not be created because it conflicts with another item';
      end if;
    end if;
  end if;

  select n.name into v_item_name
  from catalog.item_names n
  where n.item_id = v_candidate.catalog_item_id and n.is_primary
  order by n.locale = 'es-MX' desc, n.created_at desc
  limit 1;

  update ingest.normalization_runs
  set status = 'resolved', resolved_at = now()
  where id = v_run.id;

  insert into ingest.normalization_decisions(
    normalization_run_id, selected_item_id, decision_type,
    reviewer_user_id, reason, metadata
  ) values (
    v_run.id, v_candidate.catalog_item_id, 'manual', p_reviewer_user_id, v_reason,
    jsonb_build_object(
      'decision', 'approve_candidate',
      'candidate_id', v_candidate.id,
      'alias_id', v_alias_id,
      'alias', v_alias,
      'request_id', p_request_id
    )
  );

  v_after := jsonb_build_object(
    'status', 'resolved',
    'candidate_id', v_candidate.id,
    'selected_item_id', v_candidate.catalog_item_id,
    'item_name', v_item_name,
    'alias_id', v_alias_id,
    'alias', v_alias,
    'normalized_alias', v_normalized_alias,
    'provider_brand_id', v_brand_id
  );
  insert into audit.events(
    actor_user_id, actor_type, action, entity_schema, entity_table, entity_id,
    before_data, after_data, request_id, metadata
  ) values (
    p_reviewer_user_id, 'admin', 'normalization.approve_candidate', 'ingest', 'normalization_runs', v_run.id,
    jsonb_build_object('status', v_previous_status),
    v_after,
    p_request_id,
    jsonb_build_object('reason', v_reason, 'request_id', p_request_id, 'engine_version', v_run.engine_version)
  );

  return jsonb_build_object(
    'normalization_run_id', v_run.id,
    'decision', 'approve_candidate',
    'candidate_id', v_candidate.id,
    'selected_item_id', v_candidate.catalog_item_id,
    'alias_id', v_alias_id,
    'normalized_alias', v_normalized_alias,
    'status', 'resolved'
  );
end;
$$;

-- Admin quality details are diagnostic input, not an unlimited export.
create or replace function public.api_admin_quality_issues(p_status text default null, p_limit integer default 100)
returns table (issue_id uuid, issue_code text, severity text, status text, source_id uuid, crawl_run_id uuid, details jsonb, created_at timestamptz)
language sql stable security definer
set search_path = public, ingest
as $$
select id, issue_code, severity, status, source_id, crawl_run_id,
       ingest.bound_admin_json(details, 8192), created_at
from ingest.data_quality_issues
where p_status is null or status = p_status
order by created_at desc, id desc
limit greatest(1, least(coalesce(p_limit, 100), 200));
$$;

create or replace function ingest.enforce_ingest_json_limits()
returns trigger
language plpgsql
set search_path = pg_catalog, ingest
as $$
begin
  if tg_table_name = 'raw_records' and octet_length((to_jsonb(new)->'payload')::text) > 1048576 then
    raise exception 'Raw record payload exceeds 1048576 bytes';
  end if;
  if tg_table_name = 'data_quality_issues' and octet_length((to_jsonb(new)->'details')::text) > 65536 then
    raise exception 'Data quality details exceed 65536 bytes';
  end if;
  if tg_table_name = 'normalization_candidates' and octet_length((to_jsonb(new)->'explanation_data')::text) > 65536 then
    raise exception 'Normalization candidate explanation exceeds 65536 bytes';
  end if;
  if tg_table_name = 'normalization_decisions' and octet_length((to_jsonb(new)->'metadata')::text) > 16384 then
    raise exception 'Normalization decision metadata exceeds 16384 bytes';
  end if;
  if tg_table_name = 'normalization_runs' and length(coalesce(to_jsonb(new)->>'raw_text', '')) > 4000 then
    raise exception 'Normalization raw_text exceeds 4000 characters';
  end if;
  if tg_table_name = 'normalization_runs' and length(coalesce(to_jsonb(new)->>'engine_version', '')) > 100 then
    raise exception 'Normalization engine_version exceeds 100 characters';
  end if;
  if tg_table_name = 'item_aliases' and length(coalesce(to_jsonb(new)->>'alias', '')) > 200 then
    raise exception 'Catalog alias exceeds 200 characters';
  end if;
  if tg_table_name = 'item_aliases' and length(coalesce(to_jsonb(new)->>'source_note', '')) > 1000 then
    raise exception 'Catalog alias source note exceeds 1000 characters';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_raw_records_json_size on ingest.raw_records;
create trigger trg_raw_records_json_size
before insert or update on ingest.raw_records
for each row execute function ingest.enforce_ingest_json_limits();

drop trigger if exists trg_data_quality_issues_json_size on ingest.data_quality_issues;
create trigger trg_data_quality_issues_json_size
before insert or update on ingest.data_quality_issues
for each row execute function ingest.enforce_ingest_json_limits();

drop trigger if exists trg_normalization_candidates_json_size on ingest.normalization_candidates;
create trigger trg_normalization_candidates_json_size
before insert or update on ingest.normalization_candidates
for each row execute function ingest.enforce_ingest_json_limits();

drop trigger if exists trg_normalization_decisions_json_size on ingest.normalization_decisions;
create trigger trg_normalization_decisions_json_size
before insert or update on ingest.normalization_decisions
for each row execute function ingest.enforce_ingest_json_limits();

drop trigger if exists trg_normalization_runs_text_size on ingest.normalization_runs;
create trigger trg_normalization_runs_text_size
before insert or update on ingest.normalization_runs
for each row execute function ingest.enforce_ingest_json_limits();

drop trigger if exists trg_catalog_item_aliases_text_size on catalog.item_aliases;
create trigger trg_catalog_item_aliases_text_size
before insert or update on catalog.item_aliases
for each row execute function ingest.enforce_ingest_json_limits();

revoke all on function ingest.enforce_ingest_json_limits() from public, anon, authenticated;
grant execute on function ingest.enforce_ingest_json_limits() to service_role;

commit;
