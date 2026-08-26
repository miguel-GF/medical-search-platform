-- Hardening for aliases, provenance and manual normalization decisions.

begin;

-- A provider label may resolve to only one canonical item within that provider.
create unique index if not exists catalog_item_aliases_provider_term_uq
  on catalog.item_aliases(provider_brand_id, locale, normalized_alias)
  where provider_brand_id is not null and status <> 'rejected';

create or replace function ingest.validate_raw_record_provenance()
returns trigger
language plpgsql
as $$
declare
  v_source_id uuid;
begin
  select se.source_id into v_source_id
  from ingest.crawl_runs cr
  join ingest.source_endpoints se on se.id = cr.source_endpoint_id
  where cr.id = new.crawl_run_id;
  if v_source_id is distinct from new.source_id then
    raise exception 'Raw record source must match its crawl endpoint source';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_ingest_raw_records_validate_provenance on ingest.raw_records;
create trigger trg_ingest_raw_records_validate_provenance
before insert or update on ingest.raw_records
for each row execute function ingest.validate_raw_record_provenance();

create or replace function ingest.validate_observation_provenance()
returns trigger
language plpgsql
as $$
declare
  v_source_id uuid;
begin
  if new.raw_record_id is not null then
    select source_id into v_source_id from ingest.raw_records where id = new.raw_record_id;
    if v_source_id is distinct from new.source_id then
      raise exception 'Observation source must match its raw record source';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_ingest_observations_validate_provenance on ingest.source_observations;
create trigger trg_ingest_observations_validate_provenance
before insert or update on ingest.source_observations
for each row execute function ingest.validate_observation_provenance();

drop function if exists public.api_admin_update_alias(uuid, uuid, text, uuid, text);

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
set search_path = public, ingest, catalog, core, health, audit
as $$
declare
  v_alias text := trim(coalesce(p_alias, ''));
  v_normalized text;
  v_brand_id uuid;
  v_previous_status text;
begin
  if p_normalization_run_id is null or p_selected_item_id is null or v_alias = '' or p_reviewer_user_id is null then
    raise exception 'normalization run, selected item, alias and reviewer are required';
  end if;
  if length(v_alias) > 200 or length(coalesce(p_reason, '')) > 1000 then
    raise exception 'alias or reason is too long';
  end if;

  select provider_brand_id, status into v_brand_id, v_previous_status
  from ingest.normalization_runs
  where id = p_normalization_run_id
  for update;
  if not found then
    raise exception 'Normalization run does not exist';
  end if;
  if v_previous_status not in ('pending', 'ambiguous', 'no_match') then
    raise exception 'Normalization run is not awaiting review';
  end if;
  if p_provider_brand_id is not null and p_provider_brand_id is distinct from v_brand_id then
    raise exception 'Provider brand does not match normalization run';
  end if;
  v_brand_id := coalesce(p_provider_brand_id, v_brand_id);
  v_normalized := core.normalized_text(v_alias);
  if v_normalized = '' then
    raise exception 'Alias must contain letters or numbers';
  end if;
  if not exists (
    select 1
    from catalog.items i
    join health.services s on s.catalog_item_id = i.id
    where i.id = p_selected_item_id and i.status = 'active'
  ) then
    raise exception 'Selected item must be an active health service';
  end if;
  if exists (
    select 1 from catalog.item_aliases a
    where a.provider_brand_id is not distinct from v_brand_id
      and a.locale = 'es-MX'
      and a.normalized_alias = v_normalized
      and a.status <> 'rejected'
      and a.item_id <> p_selected_item_id
  ) then
    raise exception 'Alias is already assigned to another canonical item';
  end if;
  if exists (
    select 1 from ingest.normalization_decisions d
    where d.normalization_run_id = p_normalization_run_id
      and d.decision_type in ('automatic', 'manual', 'ambiguous', 'rejected', 'no_match')
  ) then
    raise exception 'Normalization run already has a final decision';
  end if;

  insert into catalog.item_aliases(
    item_id, alias, normalized_alias, alias_type, provider_brand_id,
    confidence, status, source_note, approved_by, approved_at
  ) values (
    p_selected_item_id, v_alias, v_normalized, 'provider_name', v_brand_id,
    1.0000, 'approved', coalesce(p_reason, 'Manual admin review'), p_reviewer_user_id, now()
  ) on conflict do nothing;
  update ingest.normalization_runs
  set status = 'resolved', resolved_at = now()
  where id = p_normalization_run_id;
  insert into ingest.normalization_decisions(
    normalization_run_id, selected_item_id, decision_type, reviewer_user_id, reason
  ) values (p_normalization_run_id, p_selected_item_id, 'manual', p_reviewer_user_id, p_reason);
  insert into audit.events(
    actor_user_id, actor_type, action, entity_schema, entity_table, entity_id,
    before_data, after_data, metadata
  ) values (
    p_reviewer_user_id, 'admin', 'normalization.resolve', 'catalog', 'item_aliases', p_selected_item_id,
    jsonb_build_object('normalization_run_id', p_normalization_run_id, 'status', v_previous_status),
    jsonb_build_object('alias', v_alias, 'normalized_alias', v_normalized, 'provider_brand_id', v_brand_id),
    jsonb_build_object('reason', p_reason)
  );
  return jsonb_build_object(
    'normalization_run_id', p_normalization_run_id,
    'selected_item_id', p_selected_item_id,
    'normalized_alias', v_normalized,
    'status', 'resolved'
  );
end;
$$;

revoke all on function public.api_admin_update_alias(uuid, uuid, text, uuid, text, uuid) from public;
grant execute on function public.api_admin_update_alias(uuid, uuid, text, uuid, text, uuid) to service_role;

commit;
