-- Provenance, crawlers, raw evidence, normalization and data-quality controls.

begin;

create table ingest.sources (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  source_type text not null check (source_type in (
    'provider_official','official_api','government','provider_portal','public_website','directory','user_report','manual_admin','other'
  )),
  provider_brand_id uuid references core.provider_brands(id) on delete set null,
  trust_rank smallint not null default 50 check (trust_rank between 0 and 100),
  usage_policy_status text not null default 'review_required' check (usage_policy_status in (
    'approved','review_required','restricted','blocked'
  )),
  status text not null default 'active' check (status in ('active','inactive','blocked')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table ingest.source_endpoints (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references ingest.sources(id) on delete cascade,
  name text not null,
  endpoint_type text not null check (endpoint_type in ('api','html','pdf','graphql','csv','xlsx','json','xml','manual','other')),
  url text,
  refresh_interval_minutes integer check (refresh_interval_minutes is null or refresh_interval_minutes > 0),
  max_staleness_minutes integer check (max_staleness_minutes is null or max_staleness_minutes > 0),
  parser_name text,
  parser_version text,
  expected_min_records integer check (expected_min_records is null or expected_min_records >= 0),
  expected_max_records integer check (expected_max_records is null or expected_max_records >= 0),
  max_negative_deviation_pct numeric(6,2) not null default 50.00 check (max_negative_deviation_pct between 0 and 100),
  status text not null default 'active' check (status in ('active','paused','broken','blocked')),
  last_success_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table ingest.crawl_runs (
  id uuid primary key default gen_random_uuid(),
  source_endpoint_id uuid not null references ingest.source_endpoints(id) on delete restrict,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running' check (status in (
    'running','succeeded','failed','quarantined','cancelled','partial'
  )),
  records_received integer not null default 0 check (records_received >= 0),
  records_valid integer not null default 0 check (records_valid >= 0),
  records_rejected integer not null default 0 check (records_rejected >= 0),
  records_published integer not null default 0 check (records_published >= 0),
  previous_success_count integer check (previous_success_count is null or previous_success_count >= 0),
  deviation_percentage numeric(9,4),
  parser_version text,
  git_commit text,
  error_summary text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (finished_at is null or finished_at >= started_at),
  check (records_valid + records_rejected <= records_received)
);

create index ingest_crawl_runs_endpoint_started_idx on ingest.crawl_runs(source_endpoint_id, started_at desc);
create index ingest_crawl_runs_status_idx on ingest.crawl_runs(status, started_at desc);

create table ingest.raw_documents (
  id uuid primary key default gen_random_uuid(),
  crawl_run_id uuid not null references ingest.crawl_runs(id) on delete cascade,
  r2_object_key text not null,
  mime_type text,
  sha256 char(64) not null,
  source_url text,
  etag text,
  last_modified_at timestamptz,
  retrieved_at timestamptz not null default now(),
  byte_size bigint check (byte_size is null or byte_size >= 0),
  metadata jsonb not null default '{}'::jsonb,
  unique (crawl_run_id, sha256)
);

create index ingest_raw_documents_sha_idx on ingest.raw_documents(sha256);

create table ingest.raw_records (
  id uuid primary key default gen_random_uuid(),
  crawl_run_id uuid not null references ingest.crawl_runs(id) on delete cascade,
  source_id uuid not null references ingest.sources(id) on delete restrict,
  raw_document_id uuid references ingest.raw_documents(id) on delete set null,
  external_record_id text,
  record_type text not null,
  payload jsonb not null,
  record_hash char(64) not null,
  observed_at timestamptz not null default now(),
  parse_status text not null default 'parsed' check (parse_status in ('parsed','invalid','ignored','quarantined')),
  error_detail text,
  created_at timestamptz not null default now()
);

create unique index ingest_raw_records_dedupe_uq
  on ingest.raw_records(crawl_run_id, record_hash);
create index ingest_raw_records_run_type_idx on ingest.raw_records(crawl_run_id, record_type, parse_status);
create index ingest_raw_records_external_idx on ingest.raw_records(source_id, external_record_id) where external_record_id is not null;
create index ingest_raw_records_observed_brin_idx on ingest.raw_records using brin(observed_at);

create table ingest.source_observations (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references ingest.sources(id) on delete restrict,
  raw_record_id uuid references ingest.raw_records(id) on delete set null,
  entity_type text not null check (entity_type in (
    'provider_brand','provider_location','catalog_item','offer','offer_scope','price','availability','link','other'
  )),
  entity_id uuid,
  attribute_name text,
  observed_value jsonb,
  observed_at timestamptz not null default now(),
  confidence numeric(5,4) not null default 1.0000 check (confidence between 0 and 1),
  status text not null default 'accepted' check (status in ('accepted','candidate','rejected','superseded','quarantined')),
  created_at timestamptz not null default now()
);

create index ingest_source_observations_entity_idx on ingest.source_observations(entity_type, entity_id, observed_at desc);
create index ingest_source_observations_source_idx on ingest.source_observations(source_id, observed_at desc);

create table ingest.normalization_runs (
  id uuid primary key default gen_random_uuid(),
  input_type text not null check (input_type in ('crawler','search','ocr','manual','import')),
  raw_record_id uuid references ingest.raw_records(id) on delete set null,
  provider_brand_id uuid references core.provider_brands(id) on delete set null,
  raw_text text,
  normalized_input text,
  locale text not null default 'es-MX',
  engine_version text not null,
  status text not null default 'pending' check (status in ('pending','resolved','ambiguous','no_match','failed')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index ingest_normalization_runs_status_idx on ingest.normalization_runs(status, created_at);
create index ingest_normalization_runs_input_trgm_idx on ingest.normalization_runs using gin (normalized_input extensions.gin_trgm_ops);

create table ingest.normalization_candidates (
  id uuid primary key default gen_random_uuid(),
  normalization_run_id uuid not null references ingest.normalization_runs(id) on delete cascade,
  catalog_item_id uuid not null references catalog.items(id) on delete restrict,
  rank smallint not null check (rank > 0),
  score numeric(6,5) not null check (score between 0 and 1),
  method text not null check (method in (
    'exact','alias','provider_alias','trigram','terminology','rules','embedding','llm','manual'
  )),
  explanation_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (normalization_run_id, catalog_item_id),
  unique (normalization_run_id, rank)
);

create table ingest.normalization_decisions (
  id uuid primary key default gen_random_uuid(),
  normalization_run_id uuid not null references ingest.normalization_runs(id) on delete cascade,
  selected_item_id uuid references catalog.items(id) on delete restrict,
  decision_type text not null check (decision_type in ('automatic','manual','ambiguous','rejected','no_match')),
  reviewer_user_id uuid,
  reason text,
  decided_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create index ingest_normalization_decisions_run_idx on ingest.normalization_decisions(normalization_run_id, decided_at desc);

create table ingest.data_quality_issues (
  id uuid primary key default gen_random_uuid(),
  source_id uuid references ingest.sources(id) on delete set null,
  crawl_run_id uuid references ingest.crawl_runs(id) on delete set null,
  entity_type text,
  entity_id uuid,
  issue_code text not null,
  severity text not null default 'warning' check (severity in ('info','warning','critical')),
  status text not null default 'open' check (status in ('open','acknowledged','resolved','ignored')),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid
);

create index ingest_data_quality_open_idx on ingest.data_quality_issues(status, severity, created_at desc);
create index ingest_data_quality_entity_idx on ingest.data_quality_issues(entity_type, entity_id) where entity_id is not null;

-- Once observations exist, tie price/availability provenance to them.
alter table supply.price_versions
  add constraint supply_price_versions_source_observation_fk
  foreign key (source_observation_id) references ingest.source_observations(id) on delete set null;

alter table supply.availability_current
  add constraint supply_availability_source_observation_fk
  foreign key (source_observation_id) references ingest.source_observations(id) on delete set null;

create trigger trg_ingest_sources_touch_updated_at
before update on ingest.sources for each row execute function core.touch_updated_at();
create trigger trg_ingest_source_endpoints_touch_updated_at
before update on ingest.source_endpoints for each row execute function core.touch_updated_at();

commit;
