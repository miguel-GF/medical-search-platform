-- Final hardening for the review queue and its administrative inspection
-- surface.  This migration keeps historical rows intact while making new
-- captures bounded, context-aware and auditable.

begin;

alter table ingest.normalization_runs
  add column if not exists review_scope text not null default 'default',
  add column if not exists candidate_fingerprint text not null default '';

alter table ingest.normalization_runs
  drop constraint if exists normalization_runs_review_scope_check;

alter table ingest.normalization_runs
  add constraint normalization_runs_review_scope_check
  check (review_scope ~ '^[a-z][a-z0-9_]{0,127}$');

create index if not exists ingest_normalization_review_lookup_idx
  on ingest.normalization_runs(input_type, review_scope, normalized_input, engine_version, candidate_fingerprint, created_at desc, id desc)
  where status <> 'failed';

-- Redact common credential-bearing keys before a privileged admin inspection
-- response is assembled.  The function is deliberately conservative: it
-- never writes to the source payload and it also handles nested objects and
-- arrays.
create or replace function ingest.redact_sensitive_json(p_value jsonb)
returns jsonb
language plpgsql
stable
parallel safe
set search_path = pg_catalog, ingest
as $$
declare
  v_result jsonb;
  v_entry record;
begin
  if p_value is null then
    return null;
  end if;

  if jsonb_typeof(p_value) = 'object' then
    v_result := '{}'::jsonb;
    for v_entry in select key, value from jsonb_each(p_value)
    loop
      if lower(v_entry.key) ~ '(password|passphrase|secret|token|authorization|cookie|api[_-]?key|private[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret)' then
        v_result := v_result || jsonb_build_object(v_entry.key, '[REDACTED]');
      else
        v_result := v_result || jsonb_build_object(v_entry.key, ingest.redact_sensitive_json(v_entry.value));
      end if;
    end loop;
    return v_result;
  end if;

  if jsonb_typeof(p_value) = 'array' then
    select coalesce(jsonb_agg(ingest.redact_sensitive_json(entry.value) order by entry.ordinality), '[]'::jsonb)
      into v_result
    from jsonb_array_elements(p_value) with ordinality as entry(value, ordinality);
    return v_result;
  end if;

  return p_value;
end;
$$;

create or replace function ingest.bound_admin_json(p_value jsonb, p_max_bytes integer default 65536)
returns jsonb
language plpgsql
stable
parallel safe
set search_path = pg_catalog, ingest
as $$
declare
  v_redacted jsonb;
  v_limit integer := greatest(256, least(coalesce(p_max_bytes, 65536), 65536));
begin
  if p_value is null then
    return null;
  end if;
  v_redacted := ingest.redact_sensitive_json(p_value);
  if octet_length(v_redacted::text) <= v_limit then
    return v_redacted;
  end if;
  return jsonb_build_object(
    '_redacted', 'payload exceeds the administrative inspection limit',
    'payload_bytes', octet_length(v_redacted::text),
    'limit_bytes', v_limit
  );
end;
$$;

-- The legacy raw-record screen remains useful, but it must not turn into an
-- unbounded privileged data export.
create or replace function public.api_admin_raw_records(p_limit integer default 50)
returns table (
  raw_record_id uuid,
  source_name text,
  record_type text,
  external_record_id text,
  payload jsonb,
  parse_status text,
  observed_at timestamptz,
  crawl_run_id uuid
)
language sql
stable
security definer
set search_path = public, ingest
as $$
select rr.id,
       s.name,
       rr.record_type,
       rr.external_record_id,
       ingest.bound_admin_json(rr.payload),
       rr.parse_status,
       rr.observed_at,
       rr.crawl_run_id
from ingest.raw_records rr
join ingest.sources s on s.id = rr.source_id
order by rr.observed_at desc, rr.id desc
limit greatest(1, least(coalesce(p_limit, 50), 50));
$$;

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
  left(nr.raw_text, 4000),
  left(nr.normalized_input, 200),
  nr.provider_brand_id,
  b.name,
  nr.status,
  left(nr.engine_version, 100),
  nr.created_at,
  (select count(*) from ingest.normalization_candidates nc where nc.normalization_run_id = nr.id),
  d.decision_type,
  left(d.reason, 1000),
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
    'raw_text', left(nr.raw_text, 4000),
    'normalized_input', left(nr.normalized_input, 200),
    'provider_brand_id', nr.provider_brand_id,
    'provider_brand_name', b.name,
    'status', nr.status,
    'engine_version', left(nr.engine_version, 100),
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
    'source_url', case
      when coalesce(rd.source_url, rr.payload->>'source_url') ~* '^https?://'
      then left(coalesce(rd.source_url, rr.payload->>'source_url'), 2048)
      else null
    end,
    'payload_bytes', octet_length(rr.payload::text),
    'payload', case when p_include_raw_payload then ingest.bound_admin_json(rr.payload) else null::jsonb end
  ) end,
  'candidates', coalesce((
    select jsonb_agg(jsonb_build_object(
      'candidate_id', candidate.id,
      'catalog_item_id', candidate.catalog_item_id,
      'display_name', coalesce((
        select n.name
        from catalog.item_names n
        where n.item_id = candidate.catalog_item_id and n.is_primary
        order by n.locale = 'es-MX' desc, n.created_at desc
        limit 1
      ), candidate.catalog_item_id::text),
      'rank', candidate.rank,
      'score', candidate.score,
      'method', candidate.method,
      'explanation', ingest.bound_admin_json(candidate.explanation_data, 8192)
    ) order by candidate.rank, candidate.id)
    from (
      select nc.*
      from ingest.normalization_candidates nc
      where nc.normalization_run_id = nr.id
      order by nc.rank, nc.id
      limit 50
    ) candidate
  ), '[]'::jsonb),
  'decision', (
    select jsonb_build_object(
      'decision_id', nd.id,
      'selected_item_id', nd.selected_item_id,
      'decision_type', nd.decision_type,
      'reviewer_user_id', nd.reviewer_user_id,
      'reason', left(nd.reason, 1000),
      'decided_at', nd.decided_at,
      'metadata', ingest.bound_admin_json(nd.metadata, 8192)
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

-- New public-search captures carry the domain and the candidate set into the
-- deduplication key.  The two-argument wrapper preserves existing callers.
create or replace function public.api_record_resolution_review(
  p_payload jsonb,
  p_input_type text default 'search',
  p_scope_key text default 'default'
)
returns jsonb
language plpgsql
security definer
set search_path = public, ingest, catalog, core, health
as $$
declare
  v_status text;
  v_normalized text;
  v_engine text;
  v_scope text := left(coalesce(nullif(trim(p_scope_key), ''), 'default'), 128);
  v_candidates jsonb;
  v_candidate_fingerprint text;
  v_run ingest.normalization_runs%rowtype;
  v_candidate jsonb;
  v_item_id uuid;
  v_method text;
  v_rank smallint;
  v_score numeric;
begin
  if jsonb_typeof(coalesce(p_payload, '{}'::jsonb)) <> 'object' then
    raise exception 'Resolution payload must be an object';
  end if;
  if octet_length(p_payload::text) > 262144 then
    raise exception 'Resolution payload is too large';
  end if;
  if p_input_type <> 'search' then
    raise exception 'Only search review capture is supported';
  end if;

  v_status := p_payload->>'status';
  v_normalized := core.normalized_text(left(coalesce(p_payload->>'normalized_query', ''), 200));
  v_engine := left(coalesce(p_payload->>'engine_version', 'unknown'), 100);
  v_candidates := case when jsonb_typeof(p_payload->'candidates') = 'array' then p_payload->'candidates' else '[]'::jsonb end;
  v_candidate_fingerprint := md5(coalesce((
    select string_agg(
      concat_ws(':', value->>'service_id', value->>'match_method', left(value->>'confidence', 32)),
      '|' order by ordinal
    )
    from jsonb_array_elements(v_candidates) with ordinality as candidate(value, ordinal)
    where value->>'service_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  ), ''));

  if v_scope !~ '^[a-z][a-z0-9_]{0,127}$' then
    raise exception 'Review scope is invalid';
  end if;
  if v_status not in ('ambiguous', 'no_match') then
    return jsonb_build_object('captured', false, 'status', coalesce(v_status, 'invalid'));
  end if;
  if v_normalized = '' then
    raise exception 'A normalized query is required for review capture';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_scope || '|' || v_normalized || '|' || v_engine || '|' || v_candidate_fingerprint, 0));
  select * into v_run
  from ingest.normalization_runs
  where input_type = 'search'
    and review_scope = v_scope
    and normalized_input = v_normalized
    and engine_version = v_engine
    and candidate_fingerprint = v_candidate_fingerprint
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

  -- A bounded circuit breaker protects Supabase if the optional edge rate
  -- limiter is absent or temporarily unavailable.  Reviewed/closed rows do
  -- not consume this capacity.
  if exists (
    select 1
    from ingest.normalization_runs nr
    where nr.input_type = 'search'
      and nr.status in ('pending', 'ambiguous', 'no_match')
      and not exists (
        select 1
        from ingest.normalization_decisions nd
        where nd.normalization_run_id = nr.id
          and nd.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
      )
    offset 9999
    limit 1
  ) then
    return jsonb_build_object('captured', false, 'status', 'capacity', 'reason', 'review_queue_capacity');
  end if;

  insert into ingest.normalization_runs(
    input_type, raw_record_id, provider_brand_id, raw_text,
    normalized_input, engine_version, status, review_scope, candidate_fingerprint
  ) values (
    'search', null, null, null, v_normalized, v_engine, v_status, v_scope, v_candidate_fingerprint
  ) returning * into v_run;

  for v_candidate, v_rank in
    select value, greatest(1, least(32767, ordinal::integer))::smallint
    from jsonb_array_elements(v_candidates) with ordinality as candidates(value, ordinal)
    where ordinal <= 20
    order by ordinal
  loop
    if not (v_candidate->>'service_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then
      continue;
    end if;
    v_item_id := (v_candidate->>'service_id')::uuid;
    begin
      v_score := greatest(0, least(1, coalesce(left(v_candidate->>'confidence', 32)::numeric, 0)));
    exception when others then
      v_score := 0;
    end;
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
      continue;
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
        'matched_term', left(v_candidate->>'matched_term', 500),
        'term_source', left(v_candidate->>'term_source', 100),
        'explanation', ingest.bound_admin_json(coalesce(v_candidate->'explanation', '{}'::jsonb), 4096),
        'offers', coalesce((
          select jsonb_agg(ingest.bound_admin_json(offer.value, 2048) order by offer.ordinal)
          from jsonb_array_elements(coalesce(v_candidate->'offers', '[]'::jsonb)) with ordinality offer(value, ordinal)
          where offer.ordinal <= 5
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

create or replace function public.api_record_resolution_review(p_payload jsonb, p_input_type text default 'search')
returns jsonb
language plpgsql
security definer
set search_path = public, ingest
as $$
begin
  return public.api_record_resolution_review(p_payload, p_input_type, 'default');
end;
$$;

-- Prevent a second final decision even if a future privileged process inserts
-- directly instead of using the review RPC.  Historical duplicate decisions
-- are left untouched and remain readable for audit.
create or replace function ingest.prevent_duplicate_final_normalization_decision()
returns trigger
language plpgsql
set search_path = pg_catalog, ingest
as $$
begin
  if new.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
     and exists (
       select 1
       from ingest.normalization_decisions nd
       where nd.normalization_run_id = new.normalization_run_id
         and nd.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
    ) then
    raise exception 'Normalization run already has a final decision';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_normalization_decisions_one_final on ingest.normalization_decisions;
create trigger trg_normalization_decisions_one_final
before insert on ingest.normalization_decisions
for each row execute function ingest.prevent_duplicate_final_normalization_decision();

create or replace function ingest.validate_normalization_candidate_scope()
returns trigger
language plpgsql
set search_path = pg_catalog, ingest, catalog
as $$
declare
  v_scope text;
begin
  select review_scope into v_scope
  from ingest.normalization_runs
  where id = new.normalization_run_id;
  if v_scope is null then
    raise exception 'Normalization run does not exist';
  end if;
  if v_scope <> 'default' and not exists (
    select 1
    from catalog.items i
    join catalog.domains d on d.id = i.domain_id
    where i.id = new.catalog_item_id
      and d.code = v_scope
  ) then
    raise exception 'Normalization candidate does not belong to the review scope';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_normalization_candidates_scope on ingest.normalization_candidates;
create trigger trg_normalization_candidates_scope
before insert or update on ingest.normalization_candidates
for each row execute function ingest.validate_normalization_candidate_scope();

-- Validate the review scope for manual catalog additions and approvals when a
-- search capture supplied a domain.  Existing crawler rows use the neutral
-- 'default' scope and preserve their provider-specific behavior.
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
  if p_reviewer_user_id is null or not exists (select 1 from auth.users where id = p_reviewer_user_id) then raise exception 'Reviewer is required'; end if;
  if p_catalog_item_id is null then raise exception 'Catalog item is required'; end if;
  if nullif(trim(coalesce(p_reason, '')), '') is null then raise exception 'A reason is required for a manual candidate'; end if;
  if length(coalesce(p_reason, '')) > 1000 or length(coalesce(p_request_id, '')) > 128 then raise exception 'Reason or request id is too long'; end if;

  select * into v_run from ingest.normalization_runs where id = p_normalization_run_id for update;
  if not found then raise exception 'Normalization run does not exist'; end if;
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
  values (v_run.id, p_catalog_item_id, v_rank, 0, 'manual', jsonb_build_object('reason', left(trim(p_reason), 1000), 'added_by', p_reviewer_user_id, 'request_id', p_request_id))
  returning * into v_candidate;

  insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, after_data, request_id, metadata)
  values (p_reviewer_user_id, 'admin', 'normalization.manual_candidate_added', 'ingest', 'normalization_candidates', v_candidate.id,
    jsonb_build_object('normalization_run_id', v_run.id, 'catalog_item_id', v_candidate.catalog_item_id, 'rank', v_candidate.rank), p_request_id,
    jsonb_build_object('reason', left(trim(p_reason), 1000), 'request_id', p_request_id));
  return jsonb_build_object('normalization_run_id', v_run.id, 'candidate_id', v_candidate.id, 'catalog_item_id', v_candidate.catalog_item_id, 'created', true, 'method', v_candidate.method);
end;
$$;

-- Replace the review RPC only to add the same review-scope guard while
-- retaining the transaction and alias conflict checks from migration 129.
-- The function body is intentionally delegated through a small wrapper below
-- only for the legacy alias route; the main review RPC remains the canonical
-- implementation from migration 129.

create or replace function public.api_admin_update_alias(
  p_normalization_run_id uuid,
  p_selected_item_id uuid,
  p_alias text,
  p_provider_brand_id uuid,
  p_reason text,
  p_reviewer_user_id uuid,
  p_request_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public, ingest, catalog, core
as $$
declare
  v_candidate_id uuid;
  v_run_provider_brand_id uuid;
begin
  select provider_brand_id into v_run_provider_brand_id from ingest.normalization_runs where id = p_normalization_run_id for update;
  if not found then raise exception 'Normalization run does not exist'; end if;
  if p_provider_brand_id is not null and p_provider_brand_id is distinct from v_run_provider_brand_id then raise exception 'Provider brand does not match normalization run'; end if;
  select nc.id into v_candidate_id from ingest.normalization_candidates nc where nc.normalization_run_id = p_normalization_run_id and nc.catalog_item_id = p_selected_item_id order by nc.rank, nc.id limit 1;
  if v_candidate_id is null then raise exception 'Selected service must be a candidate for this normalization run'; end if;
  return public.api_admin_review_normalization(p_normalization_run_id, 'approve_candidate', v_candidate_id, p_alias, p_reason, p_reviewer_user_id, p_request_id);
end;
$$;

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
begin
  return public.api_admin_update_alias(p_normalization_run_id, p_selected_item_id, p_alias, p_provider_brand_id, p_reason, p_reviewer_user_id, null);
end;
$$;

revoke all on function public.api_record_resolution_review(jsonb, text, text) from public, anon, authenticated;
revoke all on function public.api_record_resolution_review(jsonb, text) from public, anon, authenticated;
revoke all on function public.api_admin_update_alias(uuid, uuid, text, uuid, text, uuid, text) from public, anon, authenticated;
revoke all on function public.api_admin_update_alias(uuid, uuid, text, uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.api_record_resolution_review(jsonb, text, text) to service_role;
grant execute on function public.api_record_resolution_review(jsonb, text) to service_role;
grant execute on function public.api_admin_update_alias(uuid, uuid, text, uuid, text, uuid, text) to service_role;
grant execute on function public.api_admin_update_alias(uuid, uuid, text, uuid, text, uuid) to service_role;

-- These helpers are implementation details. PostgreSQL grants EXECUTE to
-- PUBLIC by default, so close that implicit surface explicitly.
revoke all on function ingest.redact_sensitive_json(jsonb) from public, anon, authenticated;
revoke all on function ingest.bound_admin_json(jsonb, integer) from public, anon, authenticated;
revoke all on function ingest.prevent_duplicate_final_normalization_decision() from public, anon, authenticated;
revoke all on function ingest.validate_normalization_candidate_scope() from public, anon, authenticated;
grant execute on function ingest.redact_sensitive_json(jsonb) to service_role;
grant execute on function ingest.bound_admin_json(jsonb, integer) to service_role;

commit;
