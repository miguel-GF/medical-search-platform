-- Keep the legacy admin alias route compatible while validating its optional
-- provider parameter instead of silently ignoring it.

begin;

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
  v_run_provider_brand_id uuid;
begin
  select provider_brand_id into v_run_provider_brand_id
  from ingest.normalization_runs
  where id = p_normalization_run_id
  for update;
  if not found then
    raise exception 'Normalization run does not exist';
  end if;
  if p_provider_brand_id is not null and p_provider_brand_id is distinct from v_run_provider_brand_id then
    raise exception 'Provider brand does not match normalization run';
  end if;

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

commit;
