-- Provider offers, scope hierarchy, price history, links and availability.

begin;

create table supply.offers (
  id uuid primary key default gen_random_uuid(),
  provider_brand_id uuid not null references core.provider_brands(id) on delete restrict,
  catalog_item_id uuid not null references catalog.items(id) on delete restrict,
  provider_display_name text not null,
  normalized_provider_name text not null,
  provider_sku text,
  offer_type text not null default 'standard' check (offer_type in ('standard','package','express','promotion','other')),
  is_primary boolean not null default true,
  requires_quote boolean not null default false,
  is_bookable boolean not null default false,
  status text not null default 'active' check (status in ('active','inactive','discontinued','pending','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  row_version bigint not null default 1
);

create unique index supply_offers_provider_sku_uq
  on supply.offers(provider_brand_id, provider_sku)
  where provider_sku is not null;
create unique index supply_offers_one_primary_uq
  on supply.offers(provider_brand_id, catalog_item_id)
  where is_primary and status = 'active';
create index supply_offers_brand_item_idx on supply.offers(provider_brand_id, catalog_item_id, status);
create index supply_offers_item_idx on supply.offers(catalog_item_id, status);
create index supply_offers_name_trgm_idx on supply.offers using gin (normalized_provider_name extensions.gin_trgm_ops);

create table supply.offer_scopes (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid not null references supply.offers(id) on delete cascade,
  scope_type text not null check (scope_type in ('brand','market','location')),
  provider_market_id uuid references core.provider_markets(id) on delete cascade,
  provider_location_id uuid references core.provider_locations(id) on delete cascade,
  parent_scope_id uuid references supply.offer_scopes(id) on delete restrict,
  status text not null default 'active' check (status in ('active','inactive','unavailable')),
  appointment_required boolean,
  turnaround_min_hours numeric(10,2),
  turnaround_max_hours numeric(10,2),
  preparation_override text,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (turnaround_min_hours is null or turnaround_min_hours >= 0),
  check (turnaround_max_hours is null or turnaround_max_hours >= 0),
  check (turnaround_max_hours is null or turnaround_min_hours is null or turnaround_max_hours >= turnaround_min_hours),
  check (parent_scope_id is null or parent_scope_id <> id),
  check (
    (scope_type = 'brand' and provider_market_id is null and provider_location_id is null)
    or (scope_type = 'market' and provider_market_id is not null and provider_location_id is null)
    or (scope_type = 'location' and provider_market_id is null and provider_location_id is not null)
  )
);

create unique index supply_offer_scopes_brand_uq on supply.offer_scopes(offer_id) where scope_type = 'brand';
create unique index supply_offer_scopes_market_uq on supply.offer_scopes(offer_id, provider_market_id) where scope_type = 'market';
create unique index supply_offer_scopes_location_uq on supply.offer_scopes(offer_id, provider_location_id) where scope_type = 'location';
create index supply_offer_scopes_market_idx on supply.offer_scopes(provider_market_id) where provider_market_id is not null;
create index supply_offer_scopes_location_idx on supply.offer_scopes(provider_location_id) where provider_location_id is not null;

create table supply.price_versions (
  id uuid primary key default gen_random_uuid(),
  offer_scope_id uuid not null references supply.offer_scopes(id) on delete cascade,
  price_type text not null default 'regular' check (price_type in (
    'regular','online','promo','member','cash','from','insurance','other'
  )),
  channel text not null default 'any' check (channel in ('any','web','in_person','app','phone','whatsapp','partner')),
  price_key text not null default 'default',
  amount_minor bigint not null check (amount_minor >= 0),
  currency char(3) not null default 'MXN',
  valid_from timestamptz,
  valid_to timestamptz,
  day_time_from time,
  day_time_to time,
  weekdays smallint[],
  conditions jsonb not null default '{}'::jsonb,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  is_current boolean not null default true,
  source_observation_id uuid,
  confidence numeric(5,4) not null default 1.0000 check (confidence between 0 and 1),
  created_at timestamptz not null default now(),
  check (valid_to is null or valid_from is null or valid_to > valid_from),
  check (weekdays is null or weekdays <@ array[1,2,3,4,5,6,7]::smallint[]),
  check (char_length(currency) = 3)
);

create unique index supply_price_versions_current_series_uq
  on supply.price_versions(offer_scope_id, price_type, channel, price_key)
  where is_current;
create index supply_price_versions_scope_current_idx on supply.price_versions(offer_scope_id, is_current, valid_from, valid_to);
create index supply_price_versions_amount_idx on supply.price_versions(currency, amount_minor) where is_current;

create table supply.offer_links (
  id uuid primary key default gen_random_uuid(),
  offer_scope_id uuid not null references supply.offer_scopes(id) on delete cascade,
  link_type text not null check (link_type in ('details','purchase','booking','whatsapp','phone','instructions','other')),
  url text,
  phone text,
  label text,
  status text not null default 'active' check (status in ('active','inactive','broken')),
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (url is not null or phone is not null)
);

create index supply_offer_links_scope_type_idx on supply.offer_links(offer_scope_id, link_type, status);

create table supply.availability_current (
  offer_scope_id uuid primary key references supply.offer_scopes(id) on delete cascade,
  availability_status text not null default 'unknown' check (availability_status in ('available','unavailable','limited','unknown','appointment_required')),
  quantity_available numeric(14,3),
  next_available_at timestamptz,
  checked_at timestamptz,
  source_observation_id uuid,
  notes text,
  updated_at timestamptz not null default now(),
  check (quantity_available is null or quantity_available >= 0)
);

create or replace function supply.validate_offer_scope()
returns trigger
language plpgsql
as $$
declare
  v_brand_id uuid;
  v_scope_brand uuid;
begin
  select provider_brand_id into v_brand_id
  from supply.offers
  where id = new.offer_id;

  if new.scope_type = 'market' then
    select provider_brand_id into v_scope_brand
    from core.provider_markets
    where id = new.provider_market_id;
  elsif new.scope_type = 'location' then
    select provider_brand_id into v_scope_brand
    from core.provider_locations
    where id = new.provider_location_id;
  else
    v_scope_brand := v_brand_id;
  end if;

  if v_scope_brand is distinct from v_brand_id then
    raise exception 'Offer scope belongs to a different provider brand';
  end if;

  if new.parent_scope_id is not null and not exists (
    select 1 from supply.offer_scopes p
    where p.id = new.parent_scope_id and p.offer_id = new.offer_id
  ) then
    raise exception 'Parent scope must belong to the same offer';
  end if;

  return new;
end;
$$;

create trigger trg_supply_offer_scopes_validate
before insert or update on supply.offer_scopes
for each row execute function supply.validate_offer_scope();

create or replace function supply.create_default_brand_scope()
returns trigger
language plpgsql
as $$
begin
  insert into supply.offer_scopes(offer_id, scope_type, status)
  values (new.id, 'brand', 'active')
  on conflict do nothing;
  return new;
end;
$$;

create trigger trg_supply_offers_default_brand_scope
after insert on supply.offers
for each row execute function supply.create_default_brand_scope();

create or replace function supply.resolve_prices(
  p_offer_id uuid,
  p_location_id uuid,
  p_at timestamptz default now()
)
returns table (
  price_version_id uuid,
  offer_scope_id uuid,
  price_type text,
  channel text,
  price_key text,
  amount_minor bigint,
  currency char(3),
  scope_type text,
  specificity smallint,
  valid_from timestamptz,
  valid_to timestamptz,
  conditions jsonb
)
language sql
stable
as $$
with loc as (
  select l.id, l.provider_brand_id, l.timezone
  from core.provider_locations l
  where l.id = p_location_id
),
market_ids as (
  select pml.provider_market_id
  from core.provider_market_locations pml
  where pml.provider_location_id = p_location_id
),
candidates as (
  select
    pv.*,
    os.scope_type,
    case os.scope_type when 'location' then 3 when 'market' then 2 else 1 end::smallint as specificity,
    ((p_at at time zone loc.timezone)::time) as local_time,
    extract(isodow from (p_at at time zone loc.timezone))::smallint as local_dow
  from supply.price_versions pv
  join supply.offer_scopes os on os.id = pv.offer_scope_id
  cross join loc
  where os.offer_id = p_offer_id
    and exists (
      select 1 from supply.offers o
      where o.id = p_offer_id and o.provider_brand_id = loc.provider_brand_id
    )
    and os.status = 'active'
    and pv.is_current
    and (pv.valid_from is null or p_at >= pv.valid_from)
    and (pv.valid_to is null or p_at < pv.valid_to)
    and (
      os.scope_type = 'brand'
      or (os.scope_type = 'location' and os.provider_location_id = p_location_id)
      or (os.scope_type = 'market' and os.provider_market_id in (select provider_market_id from market_ids))
    )
),
eligible as (
  select *
  from candidates c
  where (c.weekdays is null or c.local_dow = any(c.weekdays))
    and (
      c.day_time_from is null or c.day_time_to is null
      or (c.day_time_from <= c.day_time_to and c.local_time >= c.day_time_from and c.local_time < c.day_time_to)
      or (c.day_time_from > c.day_time_to and (c.local_time >= c.day_time_from or c.local_time < c.day_time_to))
    )
),
ranked as (
  select e.*,
    row_number() over (
      partition by e.price_type, e.channel, e.price_key
      order by e.specificity desc, e.valid_from desc nulls last, e.created_at desc
    ) as rn
  from eligible e
)
select
  id,
  offer_scope_id,
  price_type,
  channel,
  price_key,
  amount_minor,
  currency,
  scope_type,
  specificity,
  valid_from,
  valid_to,
  conditions
from ranked
where rn = 1;
$$;

create trigger trg_supply_offers_touch_updated_at
before update on supply.offers for each row execute function core.touch_updated_at_version();
create trigger trg_supply_offer_scopes_touch_updated_at
before update on supply.offer_scopes for each row execute function core.touch_updated_at();
create trigger trg_supply_offer_links_touch_updated_at
before update on supply.offer_links for each row execute function core.touch_updated_at();
create trigger trg_supply_availability_touch_updated_at
before update on supply.availability_current for each row execute function core.touch_updated_at();

commit;
