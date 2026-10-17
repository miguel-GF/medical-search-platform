-- Minimal local PostgreSQL 12 execution smoke for the pending crawler-only
-- and search-initialism migrations. This is not a substitute for the Supabase
-- contract on the full schema; it tests SQL compilation and guarded behavior.

create role anon;
create role authenticated;
create role service_role;
create schema auth;
create schema ingest;
create schema catalog;
create schema core;
create schema health;
create schema audit;
create schema extensions;

create function core.normalized_text(input text)
returns text language sql immutable as $$
  select lower(trim(coalesce(input, '')))
$$;

create function extensions.similarity(left_text text, right_text text)
returns real language sql immutable as $$
  select 0.0::real
$$;

create table catalog.domains (id uuid primary key, code text);
create table catalog.items (id uuid primary key, domain_id uuid, status text);
create table catalog.item_names (
  item_id uuid, name text, normalized_name text, is_primary boolean, locale text
);
create table health.services (catalog_item_id uuid);

create table auth.users (id uuid primary key);
create table ingest.normalization_runs (
  id uuid primary key default md5(random()::text)::uuid,
  input_type text, raw_record_id uuid, provider_brand_id uuid,
  raw_text text, normalized_input text, engine_version text, status text,
  review_scope text not null default 'default', candidate_fingerprint text not null default '',
  created_at timestamptz default now(), resolved_at timestamptz
);
create table ingest.normalization_decisions (
  normalization_run_id uuid, selected_item_id uuid, decision_type text,
  reviewer_user_id uuid, reason text, metadata jsonb
);
create table ingest.normalization_candidates (
  id uuid default md5(random()::text)::uuid, normalization_run_id uuid,
  catalog_item_id uuid, rank smallint, score numeric, method text,
  explanation_data jsonb
);
create table ingest.raw_records (
  id uuid primary key, crawl_run_id uuid, source_id uuid, parse_status text,
  record_type text, payload jsonb, observed_at timestamptz default now()
);
create table ingest.source_observations (
  source_id uuid, raw_record_id uuid, entity_type text, attribute_name text,
  observed_value jsonb, status text
);
create table ingest.crawl_runs (id uuid primary key, source_endpoint_id uuid, status text);
create table ingest.source_endpoints (id uuid primary key, source_id uuid, status text);
create table ingest.sources (
  id uuid primary key, provider_brand_id uuid, status text,
  usage_policy_status text, source_type text
);
create table audit.events (
  id uuid default md5(random()::text)::uuid, actor_user_id uuid, actor_type text,
  action text, entity_schema text, entity_table text, entity_id uuid,
  before_data jsonb, after_data jsonb, request_id text, metadata jsonb,
  created_at timestamptz default now()
);

-- The real matcher has its own contract; the stub reproduces its key open-row
-- property so the new source gate and write path can be exercised locally.
create function ingest.admin_exact_normalization_matches()
returns table (
  normalization_run_id uuid, catalog_item_id uuid, match_method text,
  matched_term text, normalized_input text, created_at timestamptz
)
language sql stable as $$
select nr.id, '00000000-0000-0000-0000-000000008002'::uuid,
       'exact'::text, 'Smoke exact'::text, nr.normalized_input, nr.created_at
from ingest.normalization_runs nr
where nr.normalized_input = 'smoke exact'
  and nr.status in ('pending', 'ambiguous', 'no_match')
  and not exists (
    select 1 from ingest.normalization_decisions d
    where d.normalization_run_id = nr.id
  );
$$;

\i supabase/migrations/20260924100000_exact_approved_crawler_reprocessing.sql
\i supabase/migrations/20260924110000_search_initialism_suggestions.sql

insert into catalog.domains values
  ('00000000-0000-0000-0000-000000008020', 'health_diagnostics');
insert into catalog.items values
  ('00000000-0000-0000-0000-000000008021', '00000000-0000-0000-0000-000000008020', 'active');
insert into catalog.item_names values
  ('00000000-0000-0000-0000-000000008021', 'Biometría hemática', 'biometria hematica', true, 'es-MX');
insert into health.services values ('00000000-0000-0000-0000-000000008021');

insert into auth.users values ('00000000-0000-0000-0000-000000008001');
insert into ingest.sources values
  ('00000000-0000-0000-0000-000000008003', '00000000-0000-0000-0000-000000008004',
   'active', 'approved', 'provider_official'),
  ('00000000-0000-0000-0000-000000008005', '00000000-0000-0000-0000-000000008004',
   'active', 'review_required', 'provider_official');
insert into ingest.source_endpoints values
  ('00000000-0000-0000-0000-000000008006', '00000000-0000-0000-0000-000000008003', 'active'),
  ('00000000-0000-0000-0000-000000008007', '00000000-0000-0000-0000-000000008005', 'active');
insert into ingest.crawl_runs values
  ('00000000-0000-0000-0000-000000008008', '00000000-0000-0000-0000-000000008006', 'succeeded'),
  ('00000000-0000-0000-0000-000000008009', '00000000-0000-0000-0000-000000008007', 'succeeded');
insert into ingest.raw_records(id, crawl_run_id, source_id, parse_status, record_type, payload) values
  ('00000000-0000-0000-0000-000000008010', '00000000-0000-0000-0000-000000008008',
   '00000000-0000-0000-0000-000000008003', 'parsed', 'catalog_item', '{}'::jsonb),
  ('00000000-0000-0000-0000-000000008011', '00000000-0000-0000-0000-000000008009',
   '00000000-0000-0000-0000-000000008005', 'parsed', 'catalog_item', '{}'::jsonb),
  ('00000000-0000-0000-0000-000000008015', '00000000-0000-0000-0000-000000008008',
   '00000000-0000-0000-0000-000000008003', 'parsed', 'provider_offer_price',
   '{"provider_display_name":"Smoke exact"}'::jsonb);
insert into ingest.source_observations(
  source_id, raw_record_id, entity_type, attribute_name, observed_value, status
) values (
  '00000000-0000-0000-0000-000000008003', '00000000-0000-0000-0000-000000008015',
  'offer', 'provider_display_name', to_jsonb('Smoke exact'::text), 'candidate'
);
insert into ingest.normalization_runs(id, input_type, raw_record_id, provider_brand_id, normalized_input, status)
values
  ('00000000-0000-0000-0000-000000008012', 'crawler', '00000000-0000-0000-0000-000000008010',
   '00000000-0000-0000-0000-000000008004', 'smoke exact', 'no_match'),
  ('00000000-0000-0000-0000-000000008013', 'crawler', '00000000-0000-0000-0000-000000008011',
   '00000000-0000-0000-0000-000000008004', 'smoke exact', 'no_match'),
  ('00000000-0000-0000-0000-000000008014', 'search', null,
   '00000000-0000-0000-0000-000000008004', 'smoke exact', 'no_match');

do $$
declare
  v_result jsonb;
begin
  if (select count(*) from public.api_search_spelling_suggestions('BH', 5)
      where display_name = 'Biometría hemática'
        and similarity_score > 0.9) <> 1 then
    raise exception 'generated initials must be returned as an explicit search suggestion: %',
      (select coalesce(jsonb_agg(to_jsonb(s)), '[]'::jsonb)
       from public.api_search_spelling_suggestions('BH', 5) s);
  end if;
  if (select count(*) from public.api_search_spelling_suggestions('metieron sangre', 5)) <> 0 then
    raise exception 'broad blood phrase must not guess a study';
  end if;
  if (select count(*) from ingest.admin_exact_approved_crawler_matches()) <> 1 then
    raise exception 'approved crawler gate did not exclude other inputs';
  end if;
  v_result := public.api_admin_reprocess_exact_crawler_normalizations(
    '00000000-0000-0000-0000-000000008001', 2, false, null
  );
  if (v_result->>'processed')::integer <> 0
     or (v_result->>'materialized')::integer <> 0 then
    raise exception 'preview wrote unexpectedly: %', v_result;
  end if;
  v_result := public.api_admin_reprocess_exact_crawler_normalizations(
    '00000000-0000-0000-0000-000000008001', 2, true, 'pg12-smoke'
  );
  if (v_result->>'processed')::integer <> 2
     or (v_result->>'materialized')::integer <> 1 then
    raise exception 'approved crawler apply failed: %', v_result;
  end if;
  if (select count(*) from ingest.normalization_runs
      where id in ('00000000-0000-0000-0000-000000008013',
                   '00000000-0000-0000-0000-000000008014') and status = 'no_match') <> 2 then
    raise exception 'unreviewed crawler or search was changed';
  end if;
  v_result := public.api_admin_reprocess_exact_crawler_normalizations(
    '00000000-0000-0000-0000-000000008001', 2, true, 'pg12-smoke'
  );
  if (v_result->>'replayed')::boolean is not true then
    raise exception 'idempotency replay failed';
  end if;
  if (select count(*) from ingest.normalization_decisions) <> 2 then
    raise exception 'decision count changed on replay';
  end if;
end;
$$;

select 'PASS local PostgreSQL 12 crawler migration smoke' as result;

-- Compile and exercise the DENUE-only Worker RPC against the same disposable
-- PostgreSQL cluster. The production contract is in supabase/tests.
create extension if not exists pgcrypto with schema extensions;
set search_path = public, extensions;
alter table ingest.crawl_runs alter column id set default gen_random_uuid();
alter table ingest.raw_records alter column id set default gen_random_uuid();
alter table ingest.sources add column name text;
alter table ingest.source_endpoints add column name text;
alter table ingest.source_endpoints add column endpoint_type text;
alter table ingest.source_endpoints add column url text;
alter table ingest.crawl_runs add column started_at timestamptz default now();
alter table ingest.crawl_runs add column finished_at timestamptz;
alter table ingest.crawl_runs add column records_received integer default 0;
alter table ingest.crawl_runs add column records_valid integer default 0;
alter table ingest.crawl_runs add column records_rejected integer default 0;
alter table ingest.crawl_runs add column records_published integer default 0;
alter table ingest.crawl_runs add column parser_version text;
alter table ingest.crawl_runs add column metadata jsonb default '{}'::jsonb;
alter table ingest.crawl_runs add column created_at timestamptz default now();
alter table ingest.raw_records add column external_record_id text;
alter table ingest.raw_records add column record_hash char(64);
alter table ingest.source_observations add column id uuid default gen_random_uuid();
alter table ingest.source_observations add column confidence numeric(5,4) default 1.0;
alter table ingest.source_observations add primary key (id);

insert into ingest.sources(id, name, source_type, provider_brand_id, status, usage_policy_status)
values ('00000000-0000-0000-0000-000000008100', 'INEGI DENUE', 'government', null, 'active', 'approved');
insert into ingest.source_endpoints(id, source_id, name, endpoint_type, url, status)
values (
  '00000000-0000-0000-0000-000000008101',
  '00000000-0000-0000-0000-000000008100',
  'INEGI DENUE collector endpoint', 'api',
  'https://www.inegi.org.mx/app/api/denue/v1/consulta', 'active'
);

\i supabase/migrations/20260925100000_scheduled_denue_ingest_rpc.sql

do $$
declare
  v_result jsonb;
  v_records jsonb := jsonb_build_array(jsonb_build_object(
    'external_record_id','PG12_DENUE_001',
    'source_url','https://www.inegi.org.mx/app/api/denue/v1/consulta/Ficha/PG12_DENUE_001',
    'payload',jsonb_build_object('Id','PG12_DENUE_001','Nombre','DENUE smoke'),
    'observations',jsonb_build_array(jsonb_build_object(
      'entity_type','provider_location','attribute_name','name',
      'observed_value','DENUE smoke','status','candidate'
    ))
  ));
begin
  v_result := public.api_system_ingest_denue_locations('denue-locations-2099-01-v1', v_records);
  if v_result->>'status' <> 'ingested'
     or (v_result->>'records_received')::integer <> 1
     or (v_result->>'records_published')::integer <> 0 then
    raise exception 'DENUE batch did not remain RAW only: %', v_result;
  end if;
  v_result := public.api_system_ingest_denue_locations('denue-locations-2099-01-v1', v_records);
  if (v_result->>'replayed')::boolean is not true then
    raise exception 'DENUE replay was not idempotent: %', v_result;
  end if;
  if (select count(*) from ingest.raw_records rr
      join ingest.crawl_runs cr on cr.id=rr.crawl_run_id
      where cr.metadata->>'request_key'='denue-locations-2099-01-v1') <> 1 then
    raise exception 'DENUE replay inserted duplicate evidence';
  end if;
  if (select count(*) from ingest.source_observations so
      join ingest.raw_records rr on rr.id=so.raw_record_id
      join ingest.crawl_runs cr on cr.id=rr.crawl_run_id
      where cr.metadata->>'request_key'='denue-locations-2099-01-v1'
        and so.status='candidate' and so.entity_type='provider_location') <> 1 then
    raise exception 'DENUE observation was not stored as a candidate location';
  end if;
  if (select count(*) from ingest.normalization_runs nr
      join ingest.raw_records rr on rr.id=nr.raw_record_id
      join ingest.crawl_runs cr on cr.id=rr.crawl_run_id
      where cr.metadata->>'request_key'='denue-locations-2099-01-v1') <> 0 then
    raise exception 'DENUE location unexpectedly entered clinical normalization';
  end if;

  update ingest.sources set usage_policy_status='review_required'
  where id='00000000-0000-0000-0000-000000008100';
  begin
    perform public.api_system_ingest_denue_locations('denue-locations-2099-02-v1', v_records);
    raise exception 'unapproved DENUE source unexpectedly wrote data';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'DENUE source or endpoint is not approved' then raise; end if;
  end;
  update ingest.sources set usage_policy_status='approved'
  where id='00000000-0000-0000-0000-000000008100';

  begin
    perform public.api_system_ingest_denue_locations(
      'denue-locations-2099-03-v1',
      jsonb_build_array(jsonb_build_object(
        'external_record_id','PG12_DENUE_BAD',
        'source_url','https://www.inegi.org.mx/app/api/denue/v1/consulta/Ficha/PG12_DENUE_BAD',
        'payload',jsonb_build_object('Id','PG12_DENUE_BAD'),
        'observations',jsonb_build_array(jsonb_build_object(
          'entity_type','offer','attribute_name','price','observed_value',0,'status','accepted'
        ))
      ))
    );
    raise exception 'invalid DENUE offer observation unexpectedly passed';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'DENUE observation failed validation' then raise; end if;
  end;
end;
$$;

select 'PASS local PostgreSQL 12 DENUE source gate, RAW-only write and replay smoke' as result;
