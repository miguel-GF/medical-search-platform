-- Admin review queue v2.
--
-- The clinical resolver remains read-only.  The API may persist only the
-- normalized, ambiguous/no-match result through a service-role RPC.  Admin
-- decisions are transactional and never create a mapping outside the
-- candidate set produced for that normalization run.

begin;

alter table ingest.normalization_candidates
  drop constraint if exists normalization_candidates_method_check;

alter table ingest.normalization_candidates
  add constraint normalization_candidates_method_check check (method in (
    'exact','alias','provider_alias','trigram','word_fuzzy','terminology',
    'disambiguation','loinc_exact','rules','embedding','llm','manual'
  ));

create index if not exists ingest_normalization_queue_keyset_idx
  on ingest.normalization_runs(input_type, status, created_at desc, id desc);
create index if not exists ingest_normalization_lookup_idx
  on ingest.normalization_runs(input_type, normalized_input, created_at desc, id desc);
create index if not exists ops_system_alerts_keyset_idx
  on ops.system_alerts(status, created_at desc, id desc);
create index if not exists ingest_data_quality_keyset_idx
  on ingest.data_quality_issues(status, created_at desc, id desc);

create or replace function public.api_admin_dashboard()
returns jsonb
language sql
stable
security definer
set search_path = public, ingest, catalog, supply, core, ops
as $$
select jsonb_build_object(
  'sources', (select count(*) from ingest.sources where status = 'active'),
  'crawl_runs', (select count(*) from ingest.crawl_runs),
  'failed_or_quarantined_runs', (select count(*) from ingest.crawl_runs where status in ('failed','quarantined','partial')),
  'normalization_pending', (select count(*) from ingest.normalization_runs where status in ('pending','ambiguous','no_match')),
  'normalization_ambiguous', (select count(*) from ingest.normalization_runs where status = 'ambiguous'),
  'normalization_no_match', (select count(*) from ingest.normalization_runs where status = 'no_match'),
  'open_quality_issues', (select count(*) from ingest.data_quality_issues where status = 'open'),
  'open_alerts', (select count(*) from ops.system_alerts where status in ('open','acknowledged')),
  'critical_alerts', (select count(*) from ops.system_alerts where severity = 'critical' and status in ('open','acknowledged')),
  'active_catalog_items', (select count(*) from catalog.items where status = 'active'),
  'active_offers', (select count(*) from supply.offers where status = 'active'),
  'recent_runs', coalesce((
    select jsonb_agg(to_jsonb(r) order by r.started_at desc)
    from (
      select cr.id, s.name as source_name, cr.status, cr.records_received, cr.records_valid,
             cr.records_rejected, cr.records_published, cr.started_at, cr.finished_at
      from ingest.crawl_runs cr
      join ingest.source_endpoints se on se.id = cr.source_endpoint_id
      join ingest.sources s on s.id = se.source_id
      order by cr.started_at desc, cr.id desc
      limit 20
    ) r
  ), '[]'::jsonb)
);
$$;

-- Persist only review-worthy search results.  p_payload is produced by the
-- Worker after calling the pure resolver; query text, coordinates, user IDs
-- and request metadata are intentionally not copied to the database.
create or replace function public.api_record_resolution_review(
  p_payload jsonb,
  p_input_type text default 'search'
)
returns jsonb
language plpgsql
security definer
set search_path = public, ingest, catalog, core, health
as $$
declare
  v_status text := p_payload->>'status';
  v_normalized text := core.normalized_text(left(coalesce(p_payload->>'normalized_query', ''), 200));
  v_engine text := left(coalesce(p_payload->>'engine_version', 'unknown'), 100);
  v_run ingest.normalization_runs%rowtype;
  v_candidate jsonb;
  v_item_id uuid;
  v_method text;
  v_rank smallint;
  v_score numeric;
begin
  if p_input_type <> 'search' then
    raise exception 'Only search review capture is supported';
  end if;
  if jsonb_typeof(coalesce(p_payload, '{}'::jsonb)) <> 'object' then
    raise exception 'Resolution payload must be an object';
  end if;
  if v_status not in ('ambiguous', 'no_match') then
    return jsonb_build_object('captured', false, 'status', coalesce(v_status, 'invalid'));
  end if;
  if v_normalized = '' then
    raise exception 'A normalized query is required for review capture';
  end if;

  -- Serialize identical exception captures without adding a queue row for
  -- every repeated public search.
  perform pg_advisory_xact_lock(hashtextextended(v_normalized, 0));
  select * into v_run
  from ingest.normalization_runs
  where input_type = 'search'
    and normalized_input = v_normalized
    and status <> 'failed'
  order by created_at desc, id desc
  limit 1
  for update;
  if found then
    return jsonb_build_object(
      'captured', true,
      'created', false,
      'normalization_run_id', v_run.id,
      'status', v_run.status
    );
  end if;

  insert into ingest.normalization_runs(
    input_type, raw_record_id, provider_brand_id, raw_text,
    normalized_input, engine_version, status
  ) values (
    'search', null, null, null, v_normalized, v_engine, v_status
  ) returning * into v_run;

  for v_candidate, v_rank in
    select value, greatest(1, least(32767, ordinal::integer))::smallint
    from jsonb_array_elements(coalesce(p_payload->'candidates', '[]'::jsonb))
    with ordinality as candidates(value, ordinal)
    where ordinal <= 20
    order by ordinal
  loop
    v_item_id := (v_candidate->>'service_id')::uuid;
    v_score := greatest(0, least(1, coalesce((v_candidate->>'confidence')::numeric, 0)));
    v_method := case v_candidate->>'match_method'
      when 'word_fuzzy' then 'word_fuzzy'
      when 'disambiguation' then 'disambiguation'
      when 'loinc_exact' then 'loinc_exact'
      when 'provider_alias' then 'provider_alias'
      when 'alias' then 'alias'
      when 'exact' then 'exact'
      when 'rules' then 'rules'
      when 'embedding' then 'embedding'
      when 'llm' then 'llm'
      when 'manual' then 'manual'
      when 'terminology' then 'terminology'
      else 'trigram'
    end;

    if not exists (
      select 1
      from catalog.items i
      join health.services s on s.catalog_item_id = i.id
      where i.id = v_item_id and i.status = 'active'
    ) then
      raise exception 'Resolution candidate is not an active health service';
    end if;

    insert into ingest.normalization_candidates(
      normalization_run_id, catalog_item_id, rank, score, method, explanation_data
    ) values (
      v_run.id,
      v_item_id,
      v_rank,
      v_score,
      v_method,
      jsonb_build_object(
        'matched_term', v_candidate->>'matched_term',
        'term_source', v_candidate->>'term_source',
        'explanation', coalesce(v_candidate->'explanation', '{}'::jsonb),
        'offers', coalesce((
          select jsonb_agg(offer.value order by offer.ordinal)
          from jsonb_array_elements(coalesce(v_candidate->'offers', '[]'::jsonb)) with ordinality offer(value, ordinal)
          where offer.ordinal <= 10
        ), '[]'::jsonb)
      )
    ) on conflict (normalization_run_id, catalog_item_id) do nothing;
  end loop;

  return jsonb_build_object(
    'captured', true,
    'created', true,
    'normalization_run_id', v_run.id,
    'status', v_run.status
  );
end;
$$;

-- Rich, keyset-paginated queue listing.  Payloads remain behind the detail
-- RPC so list views do not transfer large raw documents.
create or replace function public.api_admin_normalization_queue_v2(
  p_status text default null,
  p_input_type text default null,
  p_limit integer default 50,
  p_before_created_at timestamptz default null,
  p_before_id uuid default null
)
returns table (
  normalization_run_id uuid,
  input_type text,
  raw_record_id uuid,
  raw_text text,
  normalized_input text,
  provider_brand_id uuid,
  provider_brand_name text,
  status text,
  engine_version text,
  created_at timestamptz,
  candidate_count bigint,
  decision_type text,
  decision_reason text,
  source_name text
)
language sql
stable
security definer
set search_path = public, ingest, core
as $$
select
  nr.id,
  nr.input_type,
  nr.raw_record_id,
  nr.raw_text,
  nr.normalized_input,
  nr.provider_brand_id,
  b.name,
  nr.status,
  nr.engine_version,
  nr.created_at,
  (select count(*) from ingest.normalization_candidates nc where nc.normalization_run_id = nr.id),
  d.decision_type,
  d.reason,
  s.name
from ingest.normalization_runs nr
left join core.provider_brands b on b.id = nr.provider_brand_id
left join ingest.raw_records rr on rr.id = nr.raw_record_id
left join ingest.sources s on s.id = rr.source_id
left join lateral (
  select nd.decision_type, nd.reason
  from ingest.normalization_decisions nd
  where nd.normalization_run_id = nr.id
  order by nd.decided_at desc, nd.id desc
  limit 1
) d on true
where (p_status is null or nr.status = p_status)
  and (p_input_type is null or nr.input_type = p_input_type)
  and (
    (p_before_created_at is null and p_before_id is null)
    or (p_before_created_at is not null and p_before_id is not null
      and (nr.created_at, nr.id) < (p_before_created_at, p_before_id))
  )
order by nr.created_at desc, nr.id desc
limit greatest(1, least(coalesce(p_limit, 50), 200));
$$;

create or replace function public.api_admin_normalization_detail(
  p_normalization_run_id uuid,
  p_include_raw_payload boolean default false
)
returns jsonb
language sql
stable
security definer
set search_path = public, ingest, catalog, core, health
as $$
select jsonb_build_object(
  'run', jsonb_build_object(
    'normalization_run_id', nr.id,
    'input_type', nr.input_type,
    'raw_record_id', nr.raw_record_id,
    'raw_text', nr.raw_text,
    'normalized_input', nr.normalized_input,
    'provider_brand_id', nr.provider_brand_id,
    'provider_brand_name', b.name,
    'status', nr.status,
    'engine_version', nr.engine_version,
    'created_at', nr.created_at,
    'resolved_at', nr.resolved_at
  ),
  'raw_record', case when rr.id is null then null::jsonb else jsonb_build_object(
    'raw_record_id', rr.id,
    'source_name', s.name,
    'record_type', rr.record_type,
    'external_record_id', rr.external_record_id,
    'parse_status', rr.parse_status,
    'observed_at', rr.observed_at,
    'crawl_run_id', rr.crawl_run_id,
    'source_url', coalesce(rd.source_url, rr.payload->>'source_url'),
    'payload_bytes', octet_length(rr.payload::text),
    'payload', case
      when not p_include_raw_payload then null::jsonb
      when octet_length(rr.payload::text) <= 65536 then rr.payload
      else jsonb_build_object('_redacted', 'raw payload exceeds 65536 bytes', 'payload_bytes', octet_length(rr.payload::text))
    end
  ) end,
  'candidates', coalesce((
    select jsonb_agg(jsonb_build_object(
      'candidate_id', nc.id,
      'catalog_item_id', nc.catalog_item_id,
      'display_name', coalesce((
        select n.name
        from catalog.item_names n
        where n.item_id = nc.catalog_item_id and n.is_primary
        order by n.locale = 'es-MX' desc, n.created_at desc
        limit 1
      ), nc.catalog_item_id::text),
      'rank', nc.rank,
      'score', nc.score,
      'method', nc.method,
      'explanation', nc.explanation_data
    ) order by nc.rank, nc.id)
    from ingest.normalization_candidates nc
    where nc.normalization_run_id = nr.id
  ), '[]'::jsonb),
  'decision', (
    select jsonb_build_object(
      'decision_id', nd.id,
      'selected_item_id', nd.selected_item_id,
      'decision_type', nd.decision_type,
      'reviewer_user_id', nd.reviewer_user_id,
      'reason', nd.reason,
      'decided_at', nd.decided_at,
      'metadata', nd.metadata
    )
    from ingest.normalization_decisions nd
    where nd.normalization_run_id = nr.id
    order by nd.decided_at desc, nd.id desc
    limit 1
  )
)
from ingest.normalization_runs nr
left join core.provider_brands b on b.id = nr.provider_brand_id
left join ingest.raw_records rr on rr.id = nr.raw_record_id
left join ingest.sources s on s.id = rr.source_id
left join ingest.raw_documents rd on rd.id = rr.raw_document_id
where nr.id = p_normalization_run_id;
$$;

-- A scraper no_match may have no resolver candidate.  An admin may add one
-- explicitly from the active catalog, after which approval still goes through
-- api_admin_review_normalization and its candidate-membership checks.
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
begin
  if p_reviewer_user_id is null or not exists (select 1 from auth.users where id = p_reviewer_user_id) then
    raise exception 'Reviewer is required';
  end if;
  if p_catalog_item_id is null then
    raise exception 'Catalog item is required';
  end if;
  if nullif(trim(coalesce(p_reason, '')), '') is null then
    raise exception 'A reason is required for a manual candidate';
  end if;
  if length(coalesce(p_reason, '')) > 1000 or length(coalesce(p_request_id, '')) > 128 then
    raise exception 'Reason or request id is too long';
  end if;

  select * into v_run
  from ingest.normalization_runs
  where id = p_normalization_run_id
  for update;
  if not found then raise exception 'Normalization run does not exist'; end if;
  if v_run.status not in ('pending', 'ambiguous', 'no_match') then
    raise exception 'Normalization run is not awaiting review';
  end if;
  if exists (
    select 1 from ingest.normalization_decisions nd
    where nd.normalization_run_id = v_run.id
      and nd.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
  ) then
    raise exception 'Normalization run already has a final decision';
  end if;
  if not exists (
    select 1
    from catalog.items i
    join health.services s on s.catalog_item_id = i.id
    where i.id = p_catalog_item_id and i.status = 'active'
  ) then
    raise exception 'Catalog item must be an active health service';
  end if;

  select * into v_candidate
  from ingest.normalization_candidates nc
  where nc.normalization_run_id = v_run.id
    and nc.catalog_item_id = p_catalog_item_id
  for update;
  if found then
    return jsonb_build_object(
      'normalization_run_id', v_run.id,
      'candidate_id', v_candidate.id,
      'catalog_item_id', v_candidate.catalog_item_id,
      'created', false,
      'method', v_candidate.method
    );
  end if;

  select coalesce(max(nc.rank), 0) + 1 into v_rank
  from ingest.normalization_candidates nc
  where nc.normalization_run_id = v_run.id;
  if v_rank > 32767 then raise exception 'Normalization run has too many candidates'; end if;

  insert into ingest.normalization_candidates(
    normalization_run_id, catalog_item_id, rank, score, method, explanation_data
  ) values (
    v_run.id, p_catalog_item_id, v_rank, 0, 'manual',
    jsonb_build_object('reason', trim(p_reason), 'added_by', p_reviewer_user_id, 'request_id', p_request_id)
  ) returning * into v_candidate;

  insert into audit.events(
    actor_user_id, actor_type, action, entity_schema, entity_table, entity_id,
    after_data, request_id, metadata
  ) values (
    p_reviewer_user_id, 'admin', 'normalization.manual_candidate_added', 'ingest', 'normalization_candidates', v_candidate.id,
    jsonb_build_object('normalization_run_id', v_run.id, 'catalog_item_id', v_candidate.catalog_item_id, 'rank', v_candidate.rank),
    p_request_id,
    jsonb_build_object('reason', trim(p_reason), 'request_id', p_request_id)
  );

  return jsonb_build_object(
    'normalization_run_id', v_run.id,
    'candidate_id', v_candidate.id,
    'catalog_item_id', v_candidate.catalog_item_id,
    'created', true,
    'method', v_candidate.method
  );
end;
$$;

-- One transaction for either an approved candidate or an explicit no-match.
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

  select * into v_run
  from ingest.normalization_runs
  where id = p_normalization_run_id
  for update;
  if not found then
    raise exception 'Normalization run does not exist';
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

-- Backward-compatible route for the existing Admin V1 client.  It now uses
-- the same candidate membership and transactional safeguards as v2.
create or replace function public.api_admin_update_alias(
  p_normalization_run_id uuid,
  p_selected_item_id uuid,
  p_alias text,
  p_provider_brand_id uuid default null,
  p_reason text default 'Manual admin review',
  p_reviewer_user_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, ingest, catalog, core
as $$
declare
  v_candidate_id uuid;
begin
  select nc.id into v_candidate_id
  from ingest.normalization_candidates nc
  where nc.normalization_run_id = p_normalization_run_id
    and nc.catalog_item_id = p_selected_item_id
  order by nc.rank, nc.id
  limit 1;
  if v_candidate_id is null then
    raise exception 'Selected service must be a candidate for this normalization run';
  end if;
  return public.api_admin_review_normalization(
    p_normalization_run_id,
    'approve_candidate',
    v_candidate_id,
    p_alias,
    p_reason,
    p_reviewer_user_id,
    null
  );
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
set search_path = public, ops, audit
as $$
declare
  v_alert ops.system_alerts%rowtype;
  v_updated ops.system_alerts%rowtype;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
begin
  if p_reviewer_user_id is null or not exists (select 1 from auth.users where id = p_reviewer_user_id) then
    raise exception 'Reviewer is required';
  end if;
  if p_status not in ('acknowledged', 'resolved', 'ignored') then
    raise exception 'Invalid alert status';
  end if;
  if length(coalesce(p_reason, '')) > 1000 or length(coalesce(p_request_id, '')) > 128 then
    raise exception 'Reason or request id is too long';
  end if;
  select * into v_alert from ops.system_alerts where id = p_alert_id for update;
  if not found then raise exception 'Alert does not exist'; end if;
  if v_alert.status in ('resolved', 'ignored') then raise exception 'Alert is already closed'; end if;

  update ops.system_alerts
  set status = p_status,
      acknowledged_at = case when p_status in ('acknowledged', 'resolved') then coalesce(acknowledged_at, now()) else acknowledged_at end,
      acknowledged_by = case when p_status in ('acknowledged', 'resolved') then coalesce(acknowledged_by, p_reviewer_user_id) else acknowledged_by end,
      resolved_at = case when p_status = 'resolved' then now() else resolved_at end,
      resolved_by = case when p_status = 'resolved' then p_reviewer_user_id else resolved_by end
  where id = p_alert_id
  returning * into v_updated;

  insert into audit.events(
    actor_user_id, actor_type, action, entity_schema, entity_table, entity_id,
    before_data, after_data, request_id, metadata
  ) values (
    p_reviewer_user_id, 'admin', 'system_alert.status_changed', 'ops', 'system_alerts', p_alert_id,
    jsonb_build_object('status', v_alert.status),
    jsonb_build_object('status', v_updated.status),
    p_request_id,
    jsonb_build_object('reason', v_reason, 'request_id', p_request_id)
  );
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
begin
  if p_reviewer_user_id is null or not exists (select 1 from auth.users where id = p_reviewer_user_id) then
    raise exception 'Reviewer is required';
  end if;
  if p_status not in ('acknowledged', 'resolved', 'ignored') then
    raise exception 'Invalid quality issue status';
  end if;
  if length(coalesce(p_reason, '')) > 1000 or length(coalesce(p_request_id, '')) > 128 then
    raise exception 'Reason or request id is too long';
  end if;
  select * into v_issue from ingest.data_quality_issues where id = p_issue_id for update;
  if not found then raise exception 'Quality issue does not exist'; end if;
  if v_issue.status in ('resolved', 'ignored') then raise exception 'Quality issue is already closed'; end if;

  update ingest.data_quality_issues
  set status = p_status,
      resolved_at = case when p_status = 'resolved' then now() else resolved_at end,
      resolved_by = case when p_status = 'resolved' then p_reviewer_user_id else resolved_by end
  where id = p_issue_id
  returning * into v_updated;

  insert into audit.events(
    actor_user_id, actor_type, action, entity_schema, entity_table, entity_id,
    before_data, after_data, request_id, metadata
  ) values (
    p_reviewer_user_id, 'admin', 'data_quality.status_changed', 'ingest', 'data_quality_issues', p_issue_id,
    jsonb_build_object('status', v_issue.status),
    jsonb_build_object('status', v_updated.status),
    p_request_id,
    jsonb_build_object('reason', v_reason, 'request_id', p_request_id)
  );
  return jsonb_build_object('issue_id', p_issue_id, 'status', v_updated.status);
end;
$$;

revoke all on function public.api_record_resolution_review(jsonb, text) from public, anon, authenticated;
revoke all on function public.api_admin_normalization_queue_v2(text, text, integer, timestamptz, uuid) from public, anon, authenticated;
revoke all on function public.api_admin_normalization_detail(uuid, boolean) from public, anon, authenticated;
revoke all on function public.api_admin_add_manual_candidate(uuid, uuid, uuid, text, text) from public, anon, authenticated;
revoke all on function public.api_admin_review_normalization(uuid, text, uuid, text, text, uuid, text) from public, anon, authenticated;
revoke all on function public.api_admin_update_alias(uuid, uuid, text, uuid, text, uuid) from public, anon, authenticated;
revoke all on function public.api_admin_update_alert_status(uuid, text, text, uuid, text) from public, anon, authenticated;
revoke all on function public.api_admin_update_quality_issue_status(uuid, text, text, uuid, text) from public, anon, authenticated;
grant execute on function public.api_record_resolution_review(jsonb, text) to service_role;
grant execute on function public.api_admin_normalization_queue_v2(text, text, integer, timestamptz, uuid) to service_role;
grant execute on function public.api_admin_normalization_detail(uuid, boolean) to service_role;
grant execute on function public.api_admin_add_manual_candidate(uuid, uuid, uuid, text, text) to service_role;
grant execute on function public.api_admin_review_normalization(uuid, text, uuid, text, text, uuid, text) to service_role;
grant execute on function public.api_admin_update_alias(uuid, uuid, text, uuid, text, uuid) to service_role;
grant execute on function public.api_admin_update_alert_status(uuid, text, text, uuid, text) to service_role;
grant execute on function public.api_admin_update_quality_issue_status(uuid, text, text, uuid, text) to service_role;

commit;
