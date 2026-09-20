-- Minimal dependency graph for syntax/behavior smoke-testing migration
-- 20260919100000 without requiring the full Supabase/PostGIS stack.

create extension if not exists pgcrypto;
create role anon;
create role authenticated;
create role service_role;
create schema auth;
create schema research;
create schema analytics;
create schema supply;
create schema catalog;
create schema core;
create schema identity;
create schema audit;

create table auth.users (id uuid primary key, is_anonymous boolean not null default false);
create table research.pilot_settings (
  id boolean primary key default true check (id),
  feedback_enabled boolean not null default false,
  tester_intake_enabled boolean not null default false,
  pilot_key text not null default 'android-puebla-2026-v1',
  pilot_starts_at timestamptz,
  pilot_ends_at timestamptz,
  controller_name text not null default '',
  controller_address text not null default '',
  privacy_email text not null default '',
  notice_version text not null default 'android-testers-2026-09-v1',
  retention_days integer not null default 90,
  updated_at timestamptz not null default now()
);
insert into research.pilot_settings(id) values (true);

create table research.tester_candidates (
  id uuid primary key default gen_random_uuid(),
  pilot_key text not null,
  email text not null,
  municipality text not null,
  android_version text,
  device_model text,
  age_confirmed boolean not null,
  notice_version text not null,
  notice_accepted_at timestamptz not null default now(),
  status text not null default 'pending',
  internal_note text,
  reviewed_by uuid,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  retention_until timestamptz not null,
  unique (pilot_key, email)
);
create function research.purge_expired() returns void language plpgsql as $$
begin
  delete from research.tester_candidates where retention_until <= now();
end;
$$;

create table core.organizations (id uuid primary key, legal_name text not null);
create table core.provider_brands (id uuid primary key, name text not null);
create table core.provider_locations (
  id uuid primary key,
  provider_brand_id uuid not null references core.provider_brands(id),
  name text not null,
  status text not null default 'active'
);
create table core.provider_brand_organizations (
  provider_brand_id uuid not null references core.provider_brands(id),
  organization_id uuid not null references core.organizations(id),
  valid_from date not null default current_date,
  valid_to date
);
create table core.provider_location_organizations (
  provider_location_id uuid not null references core.provider_locations(id),
  organization_id uuid not null references core.organizations(id),
  status text not null default 'active',
  valid_from date not null default current_date,
  valid_to date
);
create function core.set_verified_provider_actor(p_actor_user_id uuid, p_actor_aal text)
returns void language plpgsql as $$
begin
  if p_actor_aal <> 'aal2' or not exists (select 1 from auth.users where id = p_actor_user_id) then
    raise exception 'verified provider actor required';
  end if;
end;
$$;

create table catalog.items (id uuid primary key);
create table catalog.item_names (
  item_id uuid not null references catalog.items(id),
  locale text not null default 'es-MX',
  name text not null,
  name_type text not null default 'canonical',
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);
create table supply.offers (
  id uuid primary key,
  provider_brand_id uuid not null references core.provider_brands(id),
  catalog_item_id uuid not null references catalog.items(id),
  status text not null default 'active'
);
create table identity.provider_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  organization_id uuid not null references core.organizations(id),
  scope_type text not null,
  provider_brand_id uuid,
  provider_location_id uuid,
  status text not null default 'active'
);
create table audit.events (
  id bigint generated always as identity primary key,
  actor_user_id uuid,
  actor_type text not null,
  action text not null,
  entity_schema text,
  entity_table text,
  entity_id uuid,
  after_data jsonb,
  created_at timestamptz not null default now()
);
