-- Safe bulk reprocessing for normalization exceptions.
--
-- This deliberately handles only a unique, complete match against an active
-- canonical service name or an already-approved alias.  It never guesses with
-- trigram/word-fuzzy/LLM evidence, never creates an alias, and leaves any
-- ambiguous or uncovered input in the review queue.

begin;

create or replace function ingest.admin_exact_normalization_matches()
returns table (
  normalization_run_id uuid,
  catalog_item_id uuid,
  match_method text,
  matched_term text,
  normalized_input text,
  created_at timestamptz
)
language sql
stable
parallel safe
security definer
set search_path = ingest, catalog, core, health
as $$
with awaiting as (
  select nr.id, nr.normalized_input, nr.provider_brand_id, nr.created_at
  from ingest.normalization_runs nr
  where nr.status in ('pending', 'ambiguous', 'no_match')
    and nullif(nr.normalized_input, '') is not null
    and not exists (
      select 1
      from ingest.normalization_decisions nd
      where nd.normalization_run_id = nr.id
        and nd.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
    )
), exact_options as (
  select
    a.id as normalization_run_id,
    i.id as catalog_item_id,
    'exact'::text as match_method,
    n.name as matched_term,
    a.normalized_input,
    a.created_at
  from awaiting a
  join catalog.item_names n on n.normalized_name = a.normalized_input
  join catalog.items i on i.id = n.item_id and i.status = 'active'
  join catalog.domains d on d.id = i.domain_id and d.code = 'health_diagnostics'
  join health.services hs on hs.catalog_item_id = i.id
  union all
  select
    a.id as normalization_run_id,
    i.id as catalog_item_id,
    case when ia.provider_brand_id is null then 'alias' else 'provider_alias' end,
    ia.alias,
    a.normalized_input,
    a.created_at
  from awaiting a
  join catalog.item_aliases ia on ia.normalized_alias = a.normalized_input
    and ia.status = 'approved'
    and (ia.provider_brand_id is null or ia.provider_brand_id = a.provider_brand_id)
  join catalog.items i on i.id = ia.item_id and i.status = 'active'
  join catalog.domains d on d.id = i.domain_id and d.code = 'health_diagnostics'
  join health.services hs on hs.catalog_item_id = i.id
), unique_items as (
  select normalization_run_id, count(distinct catalog_item_id) as item_count
  from exact_options
  group by normalization_run_id
), chosen as (
  select distinct on (eo.normalization_run_id)
    eo.normalization_run_id,
    eo.catalog_item_id,
    eo.match_method,
    eo.matched_term,
    eo.normalized_input,
    eo.created_at
  from exact_options eo
  join unique_items ui using (normalization_run_id)
  where ui.item_count = 1
    -- A curated disambiguation term is intentionally never auto-approved,
    -- even if one of its candidates also happens to share an exact name.
    and not exists (
      select 1
      from catalog.disambiguation_terms dt
      where dt.status = 'approved'
        and dt.normalized_term = eo.normalized_input
    )
  order by eo.normalization_run_id,
    case eo.match_method when 'exact' then 1 when 'provider_alias' then 2 else 3 end,
    eo.matched_term,
    eo.catalog_item_id
)
select normalization_run_id, catalog_item_id, match_method, matched_term,
       normalized_input, created_at
from chosen;
$$;

revoke all on function ingest.admin_exact_normalization_matches() from public, anon, authenticated;
grant execute on function ingest.admin_exact_normalization_matches() to service_role;

create or replace function public.api_admin_reprocess_exact_normalizations(
  p_reviewer_user_id uuid,
  p_limit integer default 100,
  p_apply boolean default false,
  p_request_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, ingest, catalog, core, health, audit
as $$
declare
  v_backlog bigint;
  v_eligible bigint;
  v_processed bigint := 0;
  v_skipped bigint := 0;
  v_selected bigint;
  v_remaining bigint;
  v_request text := nullif(trim(coalesce(p_request_id, '')), '');
  v_replay jsonb;
  v_row record;
  v_run ingest.normalization_runs%rowtype;
  v_candidate ingest.normalization_candidates%rowtype;
  v_rank integer;
  v_result jsonb;
begin
  if p_reviewer_user_id is null
     or not exists (select 1 from auth.users where id = p_reviewer_user_id) then
    raise exception 'Reviewer is required';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 200 then
    raise exception 'Limit must be between 1 and 200';
  end if;
  if length(coalesce(p_request_id, '')) > 128 then
    raise exception 'Request id is too long';
  end if;

  -- One global lock serializes previews/applies, so two operators cannot
  -- select the same exception rows at the same time.
  perform pg_advisory_xact_lock(hashtextextended('pruevia:admin:exact-reprocess', 0));

  -- A retried request returns the original result and performs no second
  -- write.  The API scopes p_request_id to the authenticated administrator.
  if v_request is not null then
    select e.metadata into v_replay
    from audit.events e
    where e.actor_user_id = p_reviewer_user_id
      and e.actor_type = 'admin'
      and e.action = 'normalization.exact_reprocess_batch'
      and e.request_id = v_request
    order by e.created_at desc, e.id desc
    limit 1;
    if v_replay is not null then
      return v_replay || jsonb_build_object('replayed', true);
    end if;
  end if;

  select count(*) into v_backlog
  from ingest.normalization_runs nr
  where nr.status in ('pending', 'ambiguous', 'no_match')
    and not exists (
      select 1 from ingest.normalization_decisions nd
      where nd.normalization_run_id = nr.id
        and nd.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
    );

  select count(*) into v_eligible
  from ingest.admin_exact_normalization_matches();
  v_selected := least(v_eligible, p_limit::bigint);

  if coalesce(p_apply, false) then
    for v_row in
      select *
      from ingest.admin_exact_normalization_matches()
      order by created_at, normalization_run_id
      limit p_limit
    loop
      select * into v_run
      from ingest.normalization_runs
      where id = v_row.normalization_run_id
      for update;

      if not found or v_run.status not in ('pending', 'ambiguous', 'no_match')
         or exists (
           select 1 from ingest.normalization_decisions nd
           where nd.normalization_run_id = v_run.id
             and nd.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
         ) then
        v_skipped := v_skipped + 1;
        continue;
      end if;

      select * into v_candidate
      from ingest.normalization_candidates nc
      where nc.normalization_run_id = v_run.id
        and nc.catalog_item_id = v_row.catalog_item_id
      for update;

      if found then
        update ingest.normalization_candidates
        set score = 1.00000,
            method = v_row.match_method,
            explanation_data = jsonb_build_object(
              'matched_term', v_row.matched_term,
              'normalized_input', v_row.normalized_input,
              'source', 'approved_catalog_exact',
              'confidence', 1.00000
            )
        where id = v_candidate.id;
      else
        select coalesce(max(nc.rank), 0) + 1 into v_rank
        from ingest.normalization_candidates nc
        where nc.normalization_run_id = v_run.id;
        if v_rank > 32767 then
          raise exception 'Normalization run has too many candidates';
        end if;
        insert into ingest.normalization_candidates(
          normalization_run_id, catalog_item_id, rank, score, method, explanation_data
        ) values (
          v_run.id, v_row.catalog_item_id, v_rank::smallint, 1.00000, v_row.match_method,
          jsonb_build_object(
            'matched_term', v_row.matched_term,
            'normalized_input', v_row.normalized_input,
            'source', 'approved_catalog_exact',
            'confidence', 1.00000
          )
        ) returning * into v_candidate;
      end if;

      update ingest.normalization_runs
      set status = 'resolved', resolved_at = now()
      where id = v_run.id;

      insert into ingest.normalization_decisions(
        normalization_run_id, selected_item_id, decision_type,
        reviewer_user_id, reason, metadata
      ) values (
        v_run.id, v_row.catalog_item_id, 'automatic', p_reviewer_user_id,
        'Coincidencia exacta con catálogo o alias aprobado',
        jsonb_build_object(
          'method', v_row.match_method,
          'matched_term', v_row.matched_term,
          'request_id', v_request,
          'safe_reprocess', true
        )
      );

      insert into audit.events(
        actor_user_id, actor_type, action, entity_schema, entity_table, entity_id,
        before_data, after_data, request_id, metadata
      ) values (
        p_reviewer_user_id, 'admin', 'normalization.exact_reprocess',
        'ingest', 'normalization_runs', v_run.id,
        jsonb_build_object('status', v_run.status, 'normalized_input', v_row.normalized_input),
        jsonb_build_object('status', 'resolved', 'catalog_item_id', v_row.catalog_item_id,
                           'method', v_row.match_method),
        v_request,
        jsonb_build_object('safe_reprocess', true, 'request_id', v_request)
      );
      v_processed := v_processed + 1;
    end loop;
  end if;

  select count(*) into v_remaining
  from ingest.admin_exact_normalization_matches();

  v_result := jsonb_build_object(
    'applied', coalesce(p_apply, false),
    'replayed', false,
    'backlog_total', v_backlog,
    'eligible_total', v_eligible,
    'selected', v_selected,
    'processed', v_processed,
    'skipped', v_skipped,
    'remaining_eligible', v_remaining,
    'request_id', v_request
  );

  if coalesce(p_apply, false) and v_request is not null then
    insert into audit.events(
      actor_user_id, actor_type, action, entity_schema, entity_table,
      request_id, metadata
    ) values (
      p_reviewer_user_id, 'admin', 'normalization.exact_reprocess_batch',
      'ingest', 'normalization_runs', v_request, v_result
    );
  end if;

  return v_result;
end;
$$;

revoke all on function public.api_admin_reprocess_exact_normalizations(uuid, integer, boolean, text) from public, anon, authenticated;
grant execute on function public.api_admin_reprocess_exact_normalizations(uuid, integer, boolean, text) to service_role;

-- The original dashboard/queue counted rows whose final no_match decision was
-- already recorded.  Keep those rows in audit history, but do not present
-- them as open work: otherwise operators see hundreds of false backlog items.
create or replace function public.api_admin_dashboard()
returns jsonb
language sql
stable
security definer
set search_path = public, ingest, catalog, supply, core, ops
as $$
with awaiting as materialized (
  select nr.id, nr.status
  from ingest.normalization_runs nr
  where nr.status in ('pending', 'ambiguous', 'no_match')
    and not exists (
      select 1
      from ingest.normalization_decisions nd
      where nd.normalization_run_id = nr.id
        and nd.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
    )
)
select jsonb_build_object(
  'sources', (select count(*) from ingest.sources where status = 'active'),
  'crawl_runs', (select count(*) from ingest.crawl_runs),
  'failed_or_quarantined_runs', (select count(*) from ingest.crawl_runs where status in ('failed','quarantined','partial')),
  'normalization_pending', (select count(*) from awaiting),
  'normalization_ambiguous', (select count(*) from awaiting where status = 'ambiguous'),
  'normalization_no_match', (select count(*) from awaiting where status = 'no_match'),
  'normalization_closed_no_match', (select count(*)
    from ingest.normalization_runs nr
    where nr.status = 'no_match'
      and exists (
        select 1 from ingest.normalization_decisions nd
        where nd.normalization_run_id = nr.id and nd.decision_type = 'no_match'
      )),
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

revoke all on function public.api_admin_dashboard() from public, anon, authenticated;
grant execute on function public.api_admin_dashboard() to service_role;

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
  and not exists (
    select 1
    from ingest.normalization_decisions nd_open_guard
    where nd_open_guard.normalization_run_id = nr.id
      and nd_open_guard.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
  )
  and (
    (p_before_created_at is null and p_before_id is null)
    or (p_before_created_at is not null and p_before_id is not null
      and (nr.created_at, nr.id) < (p_before_created_at, p_before_id))
  )
order by nr.created_at desc, nr.id desc
limit greatest(1, least(coalesce(p_limit, 50), 200));
$$;

revoke all on function public.api_admin_normalization_queue_v2(text, text, integer, timestamptz, uuid) from public, anon, authenticated;
grant execute on function public.api_admin_normalization_queue_v2(text, text, integer, timestamptz, uuid) to service_role;

commit;
