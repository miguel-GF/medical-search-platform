-- Geography, organizations, brands, physical locations and provider markets.

begin;

create table geo.areas (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references geo.areas(id) on delete restrict,
  country_code char(2) not null,
  area_type text not null check (area_type in (
    'country','state','province','municipality','county','city','district','borough','neighborhood','postal_zone','other'
  )),
  official_code text,
  name text not null,
  normalized_name text not null,
  slug text not null,
  timezone text,
  centroid gis.geography(Point,4326),
  boundary gis.geometry(MultiPolygon,4326),
  status text not null default 'active' check (status in ('active','inactive','deprecated')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (length(country_code) = 2),
  check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

create unique index geo_areas_official_code_uq
  on geo.areas(country_code, official_code)
  where official_code is not null;
create index geo_areas_parent_idx on geo.areas(parent_id);
create index geo_areas_name_trgm_idx on geo.areas using gin (normalized_name extensions.gin_trgm_ops);
create index geo_areas_centroid_gist_idx on geo.areas using gist (centroid);
create index geo_areas_boundary_gist_idx on geo.areas using gist (boundary);

create table core.organizations (
  id uuid primary key default gen_random_uuid(),
  legal_name text not null,
  trade_name text,
  tax_country char(2),
  tax_identifier text,
  organization_type text not null default 'company' check (organization_type in (
    'company','nonprofit','public_entity','individual_business','other'
  )),
  status text not null default 'active' check (status in ('active','inactive','suspended','merged')),
  merged_into_organization_id uuid references core.organizations(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  row_version bigint not null default 1,
  check (merged_into_organization_id is null or merged_into_organization_id <> id)
);

create unique index core_organizations_tax_uq
  on core.organizations(tax_country, tax_identifier)
  where tax_identifier is not null;

create table core.provider_brands (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  normalized_name text not null,
  slug text not null unique,
  description text,
  website_url text,
  logo_object_key text,
  status text not null default 'active' check (status in ('active','inactive','suspended','merged','closed')),
  verification_status text not null default 'unverified' check (verification_status in (
    'unverified','claimed','verification_pending','verified','rejected'
  )),
  redirect_to_brand_id uuid references core.provider_brands(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  row_version bigint not null default 1,
  check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  check (redirect_to_brand_id is null or redirect_to_brand_id <> id)
);

create index core_provider_brands_name_trgm_idx
  on core.provider_brands using gin (normalized_name extensions.gin_trgm_ops);

create table core.provider_brand_organizations (
  provider_brand_id uuid not null references core.provider_brands(id) on delete cascade,
  organization_id uuid not null references core.organizations(id) on delete restrict,
  relationship_type text not null check (relationship_type in ('owner','operator','franchisee','billing_entity','other')),
  valid_from date not null default current_date,
  valid_to date,
  created_at timestamptz not null default now(),
  primary key (provider_brand_id, organization_id, relationship_type, valid_from),
  check (valid_to is null or valid_from is null or valid_to >= valid_from)
);

create table core.provider_locations (
  id uuid primary key default gen_random_uuid(),
  provider_brand_id uuid not null references core.provider_brands(id) on delete restrict,
  operating_organization_id uuid references core.organizations(id) on delete restrict,
  geo_area_id uuid references geo.areas(id) on delete restrict,
  name text not null,
  normalized_name text not null,
  location_code text,
  location_type text not null default 'branch' check (location_type in (
    'branch','hospital','clinic','lab','diagnostic_center','office','collection_point','mobile_unit','other'
  )),
  address_line_1 text,
  address_line_2 text,
  locality_text text,
  postal_code text,
  coordinates gis.geography(Point,4326),
  timezone text not null default 'America/Mexico_City',
  phone text,
  whatsapp text,
  email text,
  website_url text,
  status text not null default 'active' check (status in ('active','inactive','temporarily_closed','closed','moved','pending')),
  opened_at date,
  closed_at date,
  moved_to_location_id uuid references core.provider_locations(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  row_version bigint not null default 1,
  check (closed_at is null or opened_at is null or closed_at >= opened_at),
  check (moved_to_location_id is null or moved_to_location_id <> id)
);

create unique index core_provider_location_code_uq
  on core.provider_locations(provider_brand_id, location_code)
  where location_code is not null;
create index core_provider_locations_brand_idx on core.provider_locations(provider_brand_id, status);
create index core_provider_locations_geo_area_idx on core.provider_locations(geo_area_id);
create index core_provider_locations_coordinates_gist_idx on core.provider_locations using gist (coordinates);
create index core_provider_locations_name_trgm_idx on core.provider_locations using gin (normalized_name extensions.gin_trgm_ops);

create table core.provider_location_hours (
  id uuid primary key default gen_random_uuid(),
  provider_location_id uuid not null references core.provider_locations(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 1 and 7),
  opens_at time not null,
  closes_at time not null,
  effective_from date,
  effective_to date,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_from is null or effective_to >= effective_from)
);

create index core_provider_location_hours_lookup_idx
  on core.provider_location_hours(provider_location_id, day_of_week, effective_from, effective_to);

create table core.provider_location_closures (
  id uuid primary key default gen_random_uuid(),
  provider_location_id uuid not null references core.provider_locations(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  reason text,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create index core_provider_location_closures_lookup_idx
  on core.provider_location_closures(provider_location_id, starts_at, ends_at);

create table core.provider_markets (
  id uuid primary key default gen_random_uuid(),
  provider_brand_id uuid not null references core.provider_brands(id) on delete cascade,
  name text not null,
  normalized_name text not null,
  slug text not null,
  market_type text not null default 'commercial_region' check (market_type in (
    'commercial_region','state','metro','city','custom'
  )),
  geo_area_id uuid references geo.areas(id) on delete restrict,
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider_brand_id, slug),
  check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

create table core.provider_market_locations (
  provider_market_id uuid not null references core.provider_markets(id) on delete cascade,
  provider_location_id uuid not null references core.provider_locations(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (provider_market_id, provider_location_id)
);

create or replace function core.validate_provider_market_location()
returns trigger
language plpgsql
as $$
declare
  v_market_brand uuid;
  v_location_brand uuid;
begin
  select provider_brand_id into v_market_brand from core.provider_markets where id = new.provider_market_id;
  select provider_brand_id into v_location_brand from core.provider_locations where id = new.provider_location_id;
  if v_market_brand is distinct from v_location_brand then
    raise exception 'Provider market and location must belong to the same brand';
  end if;
  return new;
end;
$$;

create trigger trg_core_provider_market_locations_validate
before insert or update on core.provider_market_locations
for each row execute function core.validate_provider_market_location();

create table core.provider_external_ids (
  id uuid primary key default gen_random_uuid(),
  provider_brand_id uuid not null references core.provider_brands(id) on delete cascade,
  source_system text not null,
  external_id text not null,
  external_url text,
  created_at timestamptz not null default now(),
  unique (source_system, external_id)
);

create table core.location_external_ids (
  id uuid primary key default gen_random_uuid(),
  provider_location_id uuid not null references core.provider_locations(id) on delete cascade,
  source_system text not null,
  external_id text not null,
  external_url text,
  created_at timestamptz not null default now(),
  unique (source_system, external_id)
);

create trigger trg_geo_areas_touch_updated_at
before update on geo.areas for each row execute function core.touch_updated_at();
create trigger trg_core_organizations_touch_updated_at
before update on core.organizations for each row execute function core.touch_updated_at_version();
create trigger trg_core_provider_brands_touch_updated_at
before update on core.provider_brands for each row execute function core.touch_updated_at_version();
create trigger trg_core_provider_locations_touch_updated_at
before update on core.provider_locations for each row execute function core.touch_updated_at_version();
create trigger trg_core_provider_markets_touch_updated_at
before update on core.provider_markets for each row execute function core.touch_updated_at();

commit;
