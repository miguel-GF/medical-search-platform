-- A separate, fail-closed scheduled path for exact crawler reprocessing.
-- PREPARED ONLY: do not apply or enable the cron without the approval and
-- source-policy review recorded in ADR-004. The existing Admin RPC remains
-- unchanged for interactive review of non-crawler inputs.

begin;

-- Turn only a single, explicit offer display-name observation from an
-- approved official crawl into a review-queue item. This does not publish an
-- offer or assert clinical equivalence; it only makes fresh capture evidence
-- visible to the existing normalization workflow.
create function ingest.admin_materialize_approved_crawler_normalizations(p_limit integer)
returns integer
language plpgsql
security definer
set search_path = ingest, core, catalog, health
as $$
declare
  v_inserted integer := 0;
begin
  if p_limit is null or p_limit < 1 or p_limit > 200 then
    raise exception 'Limit must be between 1 and 200';
  end if;

  -- Serialize with the scheduled exact reprocessor and any other materializer.
  perform pg_advisory_xact_lock(hashtextextended('pruevia:admin:exact-reprocess', 0));

  with eligible as (
    select rr.id as raw_record_id,
           s.provider_brand_id,
           btrim(rr.payload->>'provider_display_name') as raw_text,
           core.normalized_text(btrim(rr.payload->>'provider_display_name')) as normalized_input
    from ingest.raw_records rr
    join ingest.crawl_runs cr on cr.id = rr.crawl_run_id
      and cr.status = 'succeeded'
    join ingest.source_endpoints se on se.id = cr.source_endpoint_id
      and se.source_id = rr.source_id
      and se.status = 'active'
    join ingest.sources s on s.id = rr.source_id
      and s.status = 'active'
      and s.usage_policy_status = 'approved'
      and s.source_type in ('provider_official', 'official_api')
      and s.provider_brand_id is not null
    cross join lateral (
      select count(distinct core.normalized_text(btrim(so.observed_value #>> '{}'))) as label_count,
             min(core.normalized_text(btrim(so.observed_value #>> '{}'))) as normalized_observation
      from ingest.source_observations so
      where so.raw_record_id = rr.id
        and so.source_id = rr.source_id
        and so.entity_type = 'offer'
        and so.attribute_name = 'provider_display_name'
        and so.status in ('accepted', 'candidate')
        and jsonb_typeof(so.observed_value) = 'string'
        and nullif(btrim(so.observed_value #>> '{}'), '') is not null
    ) labels
    where rr.parse_status = 'parsed'
      and rr.record_type in ('provider_offer_price', 'provider_offer_discovered')
      and jsonb_typeof(rr.payload->'provider_display_name') = 'string'
      and length(btrim(rr.payload->>'provider_display_name')) between 1 and 4000
      and labels.label_count = 1
      and labels.normalized_observation = core.normalized_text(btrim(rr.payload->>'provider_display_name'))
      and core.normalized_text(btrim(rr.payload->>'provider_display_name')) <> ''
      and not exists (
        select 1 from ingest.normalization_runs nr
        where nr.input_type = 'crawler' and nr.raw_record_id = rr.id
      )
    order by rr.observed_at, rr.id
    limit p_limit
  )
  insert into ingest.normalization_runs(
    input_type, raw_record_id, provider_brand_id, raw_text,
    normalized_input, engine_version, status, review_scope, candidate_fingerprint
  )
  select 'crawler', e.raw_record_id, e.provider_brand_id, e.raw_text,
         e.normalized_input, 'crawler_materializer_v1', 'pending', 'default', ''
  from eligible e;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;

revoke all on function ingest.admin_materialize_approved_crawler_normalizations(integer)
  from public, anon, authenticated;
grant execute on function ingest.admin_materialize_approved_crawler_normalizations(integer)
  to service_role;

create function ingest.admin_exact_approved_crawler_matches()
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
select m.normalization_run_id, m.catalog_item_id, m.match_method,
       m.matched_term, m.normalized_input, m.created_at
from ingest.admin_exact_normalization_matches() m
join ingest.normalization_runs nr on nr.id = m.normalization_run_id
  and nr.input_type = 'crawler'
  and nr.provider_brand_id is not null
join ingest.raw_records rr on rr.id = nr.raw_record_id
  and rr.parse_status = 'parsed'
join ingest.crawl_runs cr on cr.id = rr.crawl_run_id
  and cr.status = 'succeeded'
join ingest.source_endpoints se on se.id = cr.source_endpoint_id
  and se.source_id = rr.source_id
  and se.status = 'active'
join ingest.sources s on s.id = rr.source_id
  and s.provider_brand_id = nr.provider_brand_id
  and s.status = 'active'
  and s.usage_policy_status = 'approved'
  and s.source_type in ('provider_official', 'official_api');
$$;

revoke all on function ingest.admin_exact_approved_crawler_matches()
  from public, anon, authenticated;
grant execute on function ingest.admin_exact_approved_crawler_matches()
  to service_role;

create function public.api_admin_reprocess_exact_crawler_normalizations(
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
  v_materialized integer := 0;
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
  if coalesce(p_apply, false) and v_request is null then
    raise exception 'Request id is required for scheduled apply';
  end if;

  -- Share the interactive batch lock so two paths cannot select the same run.
  perform pg_advisory_xact_lock(hashtextextended('pruevia:admin:exact-reprocess', 0));

  if v_request is not null then
    select e.metadata into v_replay
    from audit.events e
    where e.actor_user_id = p_reviewer_user_id
      and e.actor_type = 'admin'
      and e.action = 'normalization.exact_crawler_reprocess_batch'
      and e.request_id = v_request
    order by e.created_at desc, e.id desc
    limit 1;
    if v_replay is not null then
      return v_replay || jsonb_build_object('replayed', true);
    end if;
  end if;

  if coalesce(p_apply, false) then
    v_materialized := ingest.admin_materialize_approved_crawler_normalizations(p_limit);
  end if;

  select count(*) into v_backlog
  from ingest.normalization_runs nr
  where nr.input_type = 'crawler'
    and nr.status in ('pending', 'ambiguous', 'no_match')
    and not exists (
      select 1 from ingest.normalization_decisions nd
      where nd.normalization_run_id = nr.id
        and nd.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
    );
  select count(*) into v_eligible
  from ingest.admin_exact_approved_crawler_matches();

  if coalesce(p_apply, false) then
    for v_row in
      select * from ingest.admin_exact_approved_crawler_matches()
      order by created_at, normalization_run_id
      limit p_limit
    loop
      select * into v_run
      from ingest.normalization_runs
      where id = v_row.normalization_run_id
      for update;

      if not found or v_run.input_type <> 'crawler'
         or v_run.status not in ('pending', 'ambiguous', 'no_match')
         or exists (
           select 1 from ingest.normalization_decisions nd
           where nd.normalization_run_id = v_run.id
             and nd.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
         )
         or not exists (
           select 1 from ingest.admin_exact_approved_crawler_matches() m
           where m.normalization_run_id = v_run.id
             and m.catalog_item_id = v_row.catalog_item_id
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
          v_run.id, v_row.catalog_item_id, v_rank::smallint, 1.00000,
          v_row.match_method,
          jsonb_build_object(
            'matched_term', v_row.matched_term,
            'normalized_input', v_row.normalized_input,
            'source', 'approved_catalog_exact',
            'confidence', 1.00000
          )
        );
      end if;

      update ingest.normalization_runs
      set status = 'resolved', resolved_at = now()
      where id = v_run.id;
      insert into ingest.normalization_decisions(
        normalization_run_id, selected_item_id, decision_type,
        reviewer_user_id, reason, metadata
      ) values (
        v_run.id, v_row.catalog_item_id, 'automatic', p_reviewer_user_id,
        'Coincidencia exacta de crawler con fuente aprobada',
        jsonb_build_object(
          'method', v_row.match_method,
          'matched_term', v_row.matched_term,
          'request_id', v_request,
          'scheduled_crawler_only', true
        )
      );
      insert into audit.events(
        actor_user_id, actor_type, action, entity_schema, entity_table, entity_id,
        before_data, after_data, request_id, metadata
      ) values (
        p_reviewer_user_id, 'admin', 'normalization.exact_crawler_reprocess',
        'ingest', 'normalization_runs', v_run.id,
        jsonb_build_object('status', v_run.status, 'normalized_input', v_row.normalized_input),
        jsonb_build_object('status', 'resolved', 'catalog_item_id', v_row.catalog_item_id,
                           'method', v_row.match_method),
        v_request,
        jsonb_build_object('scheduled_crawler_only', true, 'request_id', v_request)
      );
      v_processed := v_processed + 1;
    end loop;
  end if;

  select count(*) into v_remaining
  from ingest.admin_exact_approved_crawler_matches();
  v_result := jsonb_build_object(
    'scope', 'approved_crawler',
    'applied', coalesce(p_apply, false),
    'replayed', false,
    'materialized', v_materialized,
    'backlog_total', v_backlog,
    'eligible_total', v_eligible,
    'selected', least(v_eligible, p_limit::bigint),
    'processed', v_processed,
    'skipped', v_skipped,
    'remaining_eligible', v_remaining,
    'request_id', v_request
  );
  if coalesce(p_apply, false) then
    insert into audit.events(
      actor_user_id, actor_type, action, entity_schema, entity_table,
      request_id, metadata
    ) values (
      p_reviewer_user_id, 'admin', 'normalization.exact_crawler_reprocess_batch',
      'ingest', 'normalization_runs', v_request, v_result
    );
  end if;
  return v_result;
end;
$$;

revoke all on function public.api_admin_reprocess_exact_crawler_normalizations(uuid, integer, boolean, text)
  from public, anon, authenticated;
grant execute on function public.api_admin_reprocess_exact_crawler_normalizations(uuid, integer, boolean, text)
  to service_role;

commit;
