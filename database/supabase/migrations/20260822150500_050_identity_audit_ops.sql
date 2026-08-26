-- Minimal identity, audit and operations foundation. Marketplace/billing grow later.

begin;

create table identity.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  locale text not null default 'es-MX',
  timezone text not null default 'America/Mexico_City',
  status text not null default 'active' check (status in ('active','suspended','deleted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table audit.events (
  id bigint generated always as identity primary key,
  actor_user_id uuid,
  actor_type text not null default 'user' check (actor_type in ('user','system','crawler','integration','admin')),
  action text not null,
  entity_schema text,
  entity_table text,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  request_id text,
  ip_hash text,
  user_agent text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index audit_events_entity_idx on audit.events(entity_schema, entity_table, entity_id, created_at desc);
create index audit_events_actor_idx on audit.events(actor_user_id, created_at desc) where actor_user_id is not null;
create index audit_events_created_brin_idx on audit.events using brin(created_at);

create table ops.system_alerts (
  id uuid primary key default gen_random_uuid(),
  alert_code text not null,
  severity text not null default 'warning' check (severity in ('info','warning','critical')),
  status text not null default 'open' check (status in ('open','acknowledged','resolved','ignored')),
  source text,
  entity_type text,
  entity_id uuid,
  title text not null,
  detail text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  acknowledged_at timestamptz,
  acknowledged_by uuid,
  resolved_at timestamptz,
  resolved_by uuid
);

create index ops_system_alerts_open_idx on ops.system_alerts(status, severity, created_at desc);

create table ops.feature_flags (
  key text primary key,
  description text,
  enabled boolean not null default false,
  config jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create trigger trg_identity_user_profiles_touch_updated_at
before update on identity.user_profiles for each row execute function core.touch_updated_at();

-- Keep internal schemas inaccessible to direct Supabase client roles unless we
-- explicitly expose something later. Worker/server connections use privileged
-- DB credentials and application-level authorization.
do $$
declare
  s text;
begin
  foreach s in array array['geo','core','catalog','health','supply','ingest','identity','audit','ops','analytics','marketplace','sensitive','billing']
  loop
    if exists (select 1 from pg_roles where rolname = 'anon') then
      execute format('revoke all on schema %I from anon', s);
    end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
      execute format('revoke all on schema %I from authenticated', s);
    end if;
  end loop;
end $$;

commit;
