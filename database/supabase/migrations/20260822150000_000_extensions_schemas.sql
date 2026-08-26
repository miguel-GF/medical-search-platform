-- Pruevia DB V1
-- Foundation: extensions, schemas and shared helpers.

begin;

create schema if not exists extensions;
create schema if not exists gis;

create extension if not exists postgis with schema gis;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;
create extension if not exists pgcrypto with schema extensions;

create schema if not exists geo;
create schema if not exists core;
create schema if not exists catalog;
create schema if not exists health;
create schema if not exists supply;
create schema if not exists ingest;
create schema if not exists identity;
create schema if not exists audit;
create schema if not exists ops;
create schema if not exists analytics;
create schema if not exists marketplace;
create schema if not exists sensitive;
create schema if not exists billing;

create or replace function core.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function core.touch_updated_at_version()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  new.row_version = old.row_version + 1;
  return new;
end;
$$;

create or replace function core.normalized_text(input text)
returns text
language sql
stable
parallel safe
as $$
  select trim(
    regexp_replace(
      lower(extensions.unaccent(coalesce(input, ''))),
      '[^a-z0-9]+',
      ' ',
      'g'
    )
  );
$$;

commit;
