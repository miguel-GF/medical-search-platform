-- Reusable normalized catalog + Pruevia health-diagnostics domain.

begin;

create table catalog.domains (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (code ~ '^[a-z][a-z0-9_]*$')
);

create table catalog.items (
  id uuid primary key default gen_random_uuid(),
  domain_id uuid not null references catalog.domains(id) on delete restrict,
  item_type text not null check (item_type in ('service','product','package','concept','other')),
  status text not null default 'draft' check (status in ('draft','active','deprecated','merged','split','hidden')),
  default_locale text not null default 'es-MX',
  redirect_to_item_id uuid references catalog.items(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  row_version bigint not null default 1,
  check (redirect_to_item_id is null or redirect_to_item_id <> id)
);

create index catalog_items_domain_status_idx on catalog.items(domain_id, status, item_type);

create table catalog.item_names (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references catalog.items(id) on delete cascade,
  locale text not null default 'es-MX',
  name text not null,
  normalized_name text not null,
  name_type text not null default 'canonical' check (name_type in ('canonical','display','historical','technical')),
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  unique (item_id, locale, normalized_name)
);

create unique index catalog_item_names_one_primary_per_locale_uq
  on catalog.item_names(item_id, locale)
  where is_primary;
create index catalog_item_names_normalized_btree_idx on catalog.item_names(normalized_name);
create index catalog_item_names_trgm_idx on catalog.item_names using gin (normalized_name extensions.gin_trgm_ops);

create table catalog.item_aliases (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references catalog.items(id) on delete cascade,
  alias text not null,
  normalized_alias text not null,
  alias_type text not null default 'synonym' check (alias_type in (
    'abbreviation','synonym','commercial_name','provider_name','common_misspelling','historical','colloquial','ocr_variant','other'
  )),
  locale text not null default 'es-MX',
  provider_brand_id uuid references core.provider_brands(id) on delete cascade,
  confidence numeric(5,4) not null default 1.0000 check (confidence between 0 and 1),
  status text not null default 'approved' check (status in ('candidate','approved','rejected','deprecated')),
  source_note text,
  approved_by uuid,
  approved_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index catalog_item_aliases_global_uq
  on catalog.item_aliases(item_id, locale, normalized_alias)
  where provider_brand_id is null and status <> 'rejected';
create unique index catalog_item_aliases_provider_uq
  on catalog.item_aliases(item_id, locale, provider_brand_id, normalized_alias)
  where provider_brand_id is not null and status <> 'rejected';
create index catalog_item_aliases_trgm_idx on catalog.item_aliases using gin (normalized_alias extensions.gin_trgm_ops);
create index catalog_item_aliases_provider_idx on catalog.item_aliases(provider_brand_id, normalized_alias);

create table catalog.categories (
  id uuid primary key default gen_random_uuid(),
  domain_id uuid not null references catalog.domains(id) on delete cascade,
  parent_id uuid references catalog.categories(id) on delete restrict,
  code text not null,
  name text not null,
  slug text not null,
  sort_order integer not null default 0,
  status text not null default 'active' check (status in ('active','inactive','deprecated')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (domain_id, code),
  unique (domain_id, slug),
  check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

create table catalog.item_categories (
  item_id uuid not null references catalog.items(id) on delete cascade,
  category_id uuid not null references catalog.categories(id) on delete cascade,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (item_id, category_id)
);

create unique index catalog_item_categories_one_primary_uq
  on catalog.item_categories(item_id)
  where is_primary;

create table catalog.item_identifiers (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references catalog.items(id) on delete cascade,
  system text not null,
  code text not null,
  version text not null default '',
  mapping_type text not null default 'exact' check (mapping_type in ('exact','narrower','broader','related','local')),
  status text not null default 'active' check (status in ('active','deprecated','rejected')),
  source_note text,
  created_at timestamptz not null default now(),
  unique (item_id, system, code, version)
);

create index catalog_item_identifiers_lookup_idx on catalog.item_identifiers(system, code, version);

create table catalog.item_relations (
  id uuid primary key default gen_random_uuid(),
  from_item_id uuid not null references catalog.items(id) on delete cascade,
  to_item_id uuid not null references catalog.items(id) on delete cascade,
  relation_type text not null check (relation_type in (
    'variant_of','includes','included_in','related_to','superseded_by','possible_alternative','requires','other'
  )),
  confidence numeric(5,4) not null default 1.0000 check (confidence between 0 and 1),
  status text not null default 'verified' check (status in ('candidate','verified','rejected','deprecated')),
  created_at timestamptz not null default now(),
  check (from_item_id <> to_item_id),
  unique (from_item_id, to_item_id, relation_type)
);

create index catalog_item_relations_to_idx on catalog.item_relations(to_item_id, relation_type);

create or replace function catalog.validate_category_parent_domain()
returns trigger
language plpgsql
as $$
declare
  v_parent_domain uuid;
begin
  if new.parent_id is not null then
    select domain_id into v_parent_domain from catalog.categories where id = new.parent_id;
    if v_parent_domain is distinct from new.domain_id then
      raise exception 'Category parent must belong to the same domain';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_catalog_categories_validate_parent
before insert or update on catalog.categories
for each row execute function catalog.validate_category_parent_domain();

create or replace function catalog.validate_item_category_domain()
returns trigger
language plpgsql
as $$
declare
  v_item_domain uuid;
  v_category_domain uuid;
begin
  select domain_id into v_item_domain from catalog.items where id = new.item_id;
  select domain_id into v_category_domain from catalog.categories where id = new.category_id;
  if v_item_domain is distinct from v_category_domain then
    raise exception 'Catalog item and category must belong to the same domain';
  end if;
  return new;
end;
$$;

create trigger trg_catalog_item_categories_validate
before insert or update on catalog.item_categories
for each row execute function catalog.validate_item_category_domain();

-- Health-specific model ------------------------------------------------------

create table health.anatomical_sites (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references health.anatomical_sites(id) on delete restrict,
  code text,
  name text not null,
  normalized_name text not null,
  laterality_applicable boolean not null default false,
  status text not null default 'active' check (status in ('active','inactive','deprecated')),
  created_at timestamptz not null default now()
);

create unique index health_anatomical_sites_code_uq on health.anatomical_sites(code) where code is not null;
create index health_anatomical_sites_name_trgm_idx on health.anatomical_sites using gin (normalized_name extensions.gin_trgm_ops);

create table health.services (
  catalog_item_id uuid primary key references catalog.items(id) on delete cascade,
  service_type text not null check (service_type in (
    'lab_test','lab_panel','imaging','neurophysiology','cardiology','endoscopy','pathology','functional_test','other'
  )),
  modality text,
  laterality text not null default 'not_applicable' check (laterality in (
    'not_applicable','none','left','right','bilateral','unspecified'
  )),
  contrast_mode text not null default 'not_applicable' check (contrast_mode in (
    'not_applicable','none','with','without','with_and_without','unknown'
  )),
  default_requires_appointment boolean,
  default_requires_order boolean,
  clinical_equivalence_policy text not null default 'manual_if_ambiguous' check (clinical_equivalence_policy in (
    'strict','manual_if_ambiguous','terminology_backed','custom'
  )),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function health.validate_service_catalog_item()
returns trigger
language plpgsql
as $$
declare
  v_domain_code text;
  v_item_type text;
begin
  select d.code, i.item_type into v_domain_code, v_item_type
  from catalog.items i
  join catalog.domains d on d.id = i.domain_id
  where i.id = new.catalog_item_id;

  if v_domain_code is distinct from 'health_diagnostics' then
    raise exception 'health.services can only reference health_diagnostics catalog items';
  end if;
  if v_item_type not in ('service','package') then
    raise exception 'health.services requires a service/package catalog item';
  end if;
  return new;
end;
$$;

create trigger trg_health_services_validate_domain
before insert or update on health.services
for each row execute function health.validate_service_catalog_item();

create table health.service_anatomy (
  service_id uuid not null references health.services(catalog_item_id) on delete cascade,
  anatomical_site_id uuid not null references health.anatomical_sites(id) on delete restrict,
  role text not null default 'target' check (role in ('target','source','region','other')),
  laterality_override text check (laterality_override is null or laterality_override in ('none','left','right','bilateral','unspecified')),
  created_at timestamptz not null default now(),
  primary key (service_id, anatomical_site_id, role)
);

create table health.specimen_types (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  normalized_name text not null,
  status text not null default 'active' check (status in ('active','inactive','deprecated')),
  created_at timestamptz not null default now()
);

create table health.service_specimens (
  service_id uuid not null references health.services(catalog_item_id) on delete cascade,
  specimen_type_id uuid not null references health.specimen_types(id) on delete restrict,
  is_primary boolean not null default false,
  notes text,
  created_at timestamptz not null default now(),
  primary key (service_id, specimen_type_id)
);

create unique index health_service_specimens_one_primary_uq
  on health.service_specimens(service_id)
  where is_primary;

create table health.service_components (
  parent_service_id uuid not null references health.services(catalog_item_id) on delete cascade,
  child_service_id uuid not null references health.services(catalog_item_id) on delete restrict,
  is_required boolean not null default true,
  quantity numeric(10,3) not null default 1 check (quantity > 0),
  component_order integer not null default 0,
  notes text,
  created_at timestamptz not null default now(),
  primary key (parent_service_id, child_service_id),
  check (parent_service_id <> child_service_id)
);

create or replace function health.prevent_service_component_cycle()
returns trigger
language plpgsql
as $$
begin
  if new.parent_service_id = new.child_service_id then
    raise exception 'A service cannot contain itself';
  end if;

  if exists (
    with recursive descendants(service_id) as (
      select sc.child_service_id
      from health.service_components sc
      where sc.parent_service_id = new.child_service_id
      union
      select sc.child_service_id
      from health.service_components sc
      join descendants d on d.service_id = sc.parent_service_id
    )
    select 1 from descendants where service_id = new.parent_service_id
  ) then
    raise exception 'Service component relation would create a cycle';
  end if;

  return new;
end;
$$;

create trigger trg_health_service_components_no_cycles
before insert or update on health.service_components
for each row execute function health.prevent_service_component_cycle();

create table health.service_preparations (
  id uuid primary key default gen_random_uuid(),
  service_id uuid not null references health.services(catalog_item_id) on delete cascade,
  preparation_type text not null default 'general' check (preparation_type in (
    'general','fasting','medication','hydration','timing','clothing','other'
  )),
  fasting_hours_min numeric(5,2),
  fasting_hours_max numeric(5,2),
  instructions text,
  locale text not null default 'es-MX',
  source_note text,
  verified_at timestamptz,
  status text not null default 'active' check (status in ('active','deprecated','needs_review')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (fasting_hours_min is null or fasting_hours_min >= 0),
  check (fasting_hours_max is null or fasting_hours_max >= 0),
  check (fasting_hours_max is null or fasting_hours_min is null or fasting_hours_max >= fasting_hours_min)
);

create trigger trg_catalog_domains_touch_updated_at
before update on catalog.domains for each row execute function core.touch_updated_at();
create trigger trg_catalog_items_touch_updated_at
before update on catalog.items for each row execute function core.touch_updated_at_version();
create trigger trg_catalog_categories_touch_updated_at
before update on catalog.categories for each row execute function core.touch_updated_at();
create trigger trg_health_services_touch_updated_at
before update on health.services for each row execute function core.touch_updated_at();
create trigger trg_health_service_preparations_touch_updated_at
before update on health.service_preparations for each row execute function core.touch_updated_at();

commit;
