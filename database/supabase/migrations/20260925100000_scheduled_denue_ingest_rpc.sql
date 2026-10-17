-- Allow only the production Worker to append bounded DENUE location evidence.
-- Source approval is rechecked here; this RPC never creates canonical entities.

begin;

create function public.api_system_ingest_denue_locations(
  p_request_key text,
  p_records jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, ingest, extensions, pg_temp
as $$
declare
  v_source_id uuid;
  v_endpoint_id uuid;
  v_source_count integer;
  v_record_count integer;
  v_run_id uuid;
  v_existing_run record;
  v_record jsonb;
  v_observation jsonb;
  v_raw_id uuid;
  v_external_id text;
  v_payload jsonb;
  v_observation_count integer := 0;
  v_record_bytes bigint;
  v_source_endpoint record;
begin
  if p_request_key is null
     or p_request_key !~ '^denue-locations-[0-9]{4}-(0[1-9]|1[0-2])-v[0-9]{1,3}$' then
    raise exception 'Invalid DENUE request key';
  end if;
  if p_records is null or jsonb_typeof(p_records) <> 'array' then
    raise exception 'DENUE records must be an array';
  end if;
  v_record_count := jsonb_array_length(p_records);
  if v_record_count < 1 or v_record_count > 1000 or pg_column_size(p_records) > 3145728 then
    raise exception 'DENUE batch is outside the allowed size';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_records) as row(value)
    where jsonb_typeof(row.value) <> 'object'
  ) then
    raise exception 'DENUE records must be objects';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_records) as row(value)
    where jsonb_typeof(row.value->'payload') is distinct from 'object'
       or jsonb_typeof(row.value->'observations') is distinct from 'array'
  ) then
    raise exception 'DENUE record payload or observations are invalid';
  end if;
  if exists (
    select 1
    from jsonb_array_elements(p_records) as row(value)
    where jsonb_array_length(row.value->'observations') < 1
       or jsonb_array_length(row.value->'observations') > 12
       or nullif(btrim(row.value->>'external_record_id'), '') is null
       or length(row.value->>'external_record_id') > 256
       or row.value->>'external_record_id' !~ '^[A-Za-z0-9_-]+$'
       or row.value->>'source_url' is distinct from
          ('https://www.inegi.org.mx/app/api/denue/v1/consulta/Ficha/' || (row.value->>'external_record_id'))
       or pg_column_size(row.value->'payload') > 65536
  ) then
    raise exception 'DENUE record failed validation';
  end if;
  if exists (
    select 1
    from jsonb_array_elements(p_records) as row(value)
    cross join lateral jsonb_array_elements(row.value->'observations') as obs(value)
    where jsonb_typeof(obs.value) <> 'object'
       or obs.value->>'entity_type' <> 'provider_location'
       or obs.value->>'status' <> 'candidate'
       or obs.value->>'attribute_name' is null
       or obs.value->>'attribute_name' not in (
         'name','legal_name','activity_code','phone','email','website_url',
         'postal_code','latitude','longitude','address','coordinates'
       )
       or obs.value->'observed_value' is null
       or jsonb_typeof(obs.value->'observed_value') = 'null'
       or pg_column_size(obs.value->'observed_value') > 32768
  ) then
    raise exception 'DENUE observation failed validation';
  end if;
  if exists (
    select 1 from (
      select row.value->>'external_record_id' as external_id
      from jsonb_array_elements(p_records) as row(value)
      group by row.value->>'external_record_id'
      having count(*) > 1
    ) duplicates
  ) then
    raise exception 'DENUE batch contains duplicate IDs';
  end if;
  if exists (
    select 1
    from jsonb_array_elements(p_records) as row(value)
    cross join lateral jsonb_array_elements(row.value->'observations') as obs(value)
    group by row.value->>'external_record_id'
    having count(*) <> count(distinct obs.value->>'attribute_name')
  ) then
    raise exception 'DENUE record contains duplicate observation attributes';
  end if;

  for v_source_endpoint in
    select s.id as source_id, se.id as endpoint_id
    from ingest.sources s
    join ingest.source_endpoints se on se.source_id = s.id
    where s.name = 'INEGI DENUE'
      and s.source_type = 'government'
      and s.provider_brand_id is null
      and s.status = 'active'
      and s.usage_policy_status = 'approved'
      and se.name = 'INEGI DENUE collector endpoint'
      and se.endpoint_type = 'api'
      and se.url = 'https://www.inegi.org.mx/app/api/denue/v1/consulta'
      and se.status = 'active'
    for share of s, se
  loop
    v_source_count := coalesce(v_source_count, 0) + 1;
    v_source_id := v_source_endpoint.source_id;
    v_endpoint_id := v_source_endpoint.endpoint_id;
  end loop;
  if coalesce(v_source_count, 0) <> 1 then
    raise exception 'DENUE source or endpoint is not approved';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('pruevia:denue-location-ingest', 0));
  select id, records_received, records_valid into v_existing_run
  from ingest.crawl_runs
  where source_endpoint_id = v_endpoint_id
    and metadata->>'scheduled_job' = 'denue_locations_monthly'
    and metadata->>'request_key' = p_request_key
  order by created_at desc
  limit 1;
  if found then
    return jsonb_build_object(
      'status', 'ingested', 'replayed', true,
      'run_id', v_existing_run.id,
      'records_received', v_existing_run.records_received,
      'records_valid', v_existing_run.records_valid,
      'records_published', 0
    );
  end if;

  insert into ingest.crawl_runs(
    source_endpoint_id, started_at, finished_at, status,
    records_received, records_valid, records_rejected, records_published,
    parser_version, metadata
  ) values (
    v_endpoint_id, now(), now(), 'succeeded',
    v_record_count, v_record_count, 0, 0,
    'denue-worker-v1',
    jsonb_build_object(
      'scheduled_job', 'denue_locations_monthly',
      'request_key', p_request_key,
      'coverage_mode', 'sampled_centers_not_exhaustive',
      'source_citation', 'Fuente: INEGI, DENUE',
      'catalog_or_offer_writes', false
    )
  ) returning id into v_run_id;

  for v_record in select value from jsonb_array_elements(p_records)
  loop
    v_external_id := v_record->>'external_record_id';
    v_payload := v_record->'payload';
    v_record_bytes := pg_column_size(v_payload);
    if v_record_bytes > 65536 then
      raise exception 'DENUE record payload exceeds the size limit';
    end if;
    insert into ingest.raw_records(
      crawl_run_id, source_id, external_record_id, record_type,
      payload, record_hash, observed_at, parse_status
    ) values (
      v_run_id, v_source_id, v_external_id, 'provider_location_discovered',
      v_payload,
      encode(extensions.digest(convert_to(v_payload::text, 'UTF8'), 'sha256'), 'hex'),
      now(), 'parsed'
    ) returning id into v_raw_id;

    for v_observation in select value from jsonb_array_elements(v_record->'observations')
    loop
      insert into ingest.source_observations(
        source_id, raw_record_id, entity_type, attribute_name,
        observed_value, confidence, status
      ) values (
        v_source_id, v_raw_id, 'provider_location',
        v_observation->>'attribute_name', v_observation->'observed_value',
        1.0000, 'candidate'
      );
      v_observation_count := v_observation_count + 1;
    end loop;
  end loop;

  return jsonb_build_object(
    'status', 'ingested', 'replayed', false,
    'run_id', v_run_id,
    'records_received', v_record_count,
    'records_valid', v_record_count,
    'observations', v_observation_count,
    'records_published', 0
  );
end;
$$;

revoke all on function public.api_system_ingest_denue_locations(text, jsonb)
  from public, anon, authenticated;
grant execute on function public.api_system_ingest_denue_locations(text, jsonb)
  to service_role;

commit;
