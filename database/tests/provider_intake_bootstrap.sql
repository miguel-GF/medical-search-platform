-- Isolated PostgreSQL fixture, NOT a production/Supabase migration.
do $$ begin
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon; end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
  if not exists (select 1 from pg_roles where rolname='service_role') then create role service_role; end if;
end $$;
create schema if not exists auth; create schema if not exists core; create schema if not exists identity; create schema if not exists ingest; create schema if not exists audit; create schema if not exists extensions; create schema if not exists storage;
create extension pgcrypto with schema extensions;
create function public.gen_random_uuid() returns uuid language sql as $$select extensions.gen_random_uuid()$$;
create function pg_catalog.gen_random_uuid() returns uuid language sql as $$select extensions.gen_random_uuid()$$;
create table auth.users(id uuid primary key,email text,is_anonymous boolean default false);
create table auth.mfa_factors(user_id uuid,status text);
create function auth.jwt() returns jsonb language sql as $$select coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}')$$;
create function auth.uid() returns uuid language sql as $$select (auth.jwt()->>'sub')::uuid$$;
create function core.touch_updated_at() returns trigger language plpgsql as $$begin new.updated_at=now();return new;end$$;
create function core.normalized_text(text) returns text language sql immutable as $$select lower($1)$$;
create table core.organizations(id uuid primary key default gen_random_uuid(),legal_name text,organization_type text default 'company',status text default 'active');
create table core.provider_brands(id uuid primary key default gen_random_uuid(),name text,status text default 'active');
create table core.provider_locations(id uuid primary key default gen_random_uuid(),provider_brand_id uuid references core.provider_brands,name text,status text default 'active');
create table core.provider_brand_organizations(provider_brand_id uuid,organization_id uuid,relationship_type text,valid_from date default current_date,valid_to date,primary key(provider_brand_id,organization_id,relationship_type,valid_from));
create table audit.events(actor_user_id uuid,actor_type text,action text,entity_schema text,entity_table text,entity_id uuid,before_data jsonb,after_data jsonb,metadata jsonb);
create table ingest.sources(id uuid primary key default gen_random_uuid(),name text);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text,owner_id text);
alter table storage.objects enable row level security;
create policy provider_documents_internal_freeze on storage.objects as restrictive for all to anon,authenticated using(bucket_id<>'provider-claims') with check(bucket_id<>'provider-claims');
