-- Make offer hand-offs explicit.  A details URL is not necessarily a study
-- URL: some providers expose only a branch page and require the visitor to
-- select the study in a client-side flow.  Keep source_url in the public
-- contract, but expose the verified link capabilities separately.

begin;

alter table supply.offer_links
  add column if not exists link_target text,
  add column if not exists link_capability text,
  add column if not exists handoff_data jsonb;

update supply.offer_links
set link_target = case
  when link_type = 'booking' then 'booking'
  when link_type in ('details', 'purchase') then 'study'
  when link_type in ('whatsapp', 'phone') then 'provider'
  else 'provider'
end
where link_target is null;

update supply.offer_links
set handoff_data = '{}'::jsonb
where handoff_data is null;

-- Salud Digna's old details URL is a branch page, not a study deep-link.  It
-- is classified as provider-only first; rows that can be tied to their exact
-- location are repaired below and become location links.
update supply.offer_links l
set link_target = 'provider'
from supply.offer_scopes os
join supply.offers o on o.id = os.offer_id
join core.provider_brands b on b.id = o.provider_brand_id
where l.offer_scope_id = os.id
  and b.slug = 'salud-digna'
  and l.link_type = 'details';

update supply.offer_links
set link_capability = case link_target
  when 'study' then 'study_only'
  when 'location' then 'location_only'
  when 'study_and_location' then 'study_and_location'
  when 'provider' then 'provider_only'
  when 'booking' then 'provider_only'
  when 'handoff' then 'none'
  else 'none'
end
where link_capability is null;

alter table supply.offer_links
  alter column link_target set default 'study',
  alter column link_target set not null,
  alter column link_capability set default 'study_only',
  alter column link_capability set not null,
  alter column handoff_data set default '{}'::jsonb,
  alter column handoff_data set not null;

alter table supply.offer_links
  add constraint supply_offer_links_target_ck
  check (link_target in ('study', 'location', 'booking', 'provider', 'handoff'));

alter table supply.offer_links
  add constraint supply_offer_links_capability_ck
  check (link_capability in (
    'study_only', 'location_only', 'study_and_location', 'provider_only', 'none'
  ));

alter table supply.offer_links
  add constraint supply_offer_links_handoff_object_ck
  check (jsonb_typeof(handoff_data) = 'object');

create index if not exists supply_offer_links_target_idx
  on supply.offer_links(offer_scope_id, link_target, status);

create or replace function supply.validate_offer_link_metadata()
returns trigger
language plpgsql
set search_path = supply, core, public
as $$
declare
  v_scope_type text;
begin
  select scope_type into v_scope_type
  from supply.offer_scopes
  where id = new.offer_scope_id;

  if v_scope_type is null then
    raise exception 'Offer link scope does not exist';
  end if;

  -- A location link must belong to that concrete location.  This prevents a
  -- market-level URL from being shown as if it represented every branch.
  if new.link_target = 'location' and v_scope_type <> 'location' then
    raise exception 'Location links require a location offer scope';
  end if;

  if new.link_target = 'handoff' and jsonb_typeof(new.handoff_data) <> 'object' then
    raise exception 'Handoff metadata must be a JSON object';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_supply_offer_links_validate_metadata on supply.offer_links;
create trigger trg_supply_offer_links_validate_metadata
before insert or update on supply.offer_links
for each row execute function supply.validate_offer_link_metadata();

-- The reviewed Salud Digna mapping represented branch 332, but its old market
-- scope expanded the price and page to all branches.  Convert only scopes
-- whose observed URL matches one (and only one) official location.  Unknown
-- market scopes are closed instead of publishing unverified availability.
with matching_scopes as (
  select os.id as scope_id, (array_agg(pl.id order by pl.id))[1] as location_id
  from supply.offer_scopes os
  join supply.offers o on o.id = os.offer_id
  join core.provider_brands b on b.id = o.provider_brand_id
  join supply.offer_links ol on ol.offer_scope_id = os.id
  join core.provider_locations pl
    on pl.provider_brand_id = o.provider_brand_id
   and pl.status = 'active'
   and (
     pl.website_url = ol.url
     or exists (
       select 1
       from core.location_external_ids lei
       where lei.provider_location_id = pl.id
         and lei.external_url = ol.url
     )
   )
  where b.slug = 'salud-digna'
    and os.scope_type = 'market'
    and os.status = 'active'
    and ol.link_type = 'details'
    and ol.status = 'active'
    and ol.url is not null
  group by os.id
  having count(distinct pl.id) = 1
)
update supply.offer_scopes os
set scope_type = 'location',
    provider_market_id = null,
    provider_location_id = ms.location_id
from matching_scopes ms
where os.id = ms.scope_id;

update supply.offer_links ol
set link_target = 'location'
from supply.offer_scopes os
join core.provider_locations pl on pl.id = os.provider_location_id
where ol.offer_scope_id = os.id
  and os.scope_type = 'location'
  and os.status = 'active'
  and ol.link_type = 'details'
  and ol.status = 'active'
  and (
    pl.website_url = ol.url
    or exists (
      select 1
      from core.location_external_ids lei
      where lei.provider_location_id = pl.id
        and lei.external_url = ol.url
    )
  );

update supply.offer_scopes os
set status = 'inactive'
from supply.offers o
join core.provider_brands b on b.id = o.provider_brand_id
where os.offer_id = o.id
  and b.slug = 'salud-digna'
  and os.scope_type = 'market'
  and os.status = 'active';

-- The automatic brand scope is also unsafe for this per-branch feed: it would
-- re-expand the offer when a caller asks for a different branch.  Keep it as
-- history, but require a concrete location scope for published Salud Digna
-- offers until a future run proves market-wide availability.
update supply.offer_scopes os
set status = 'inactive'
from supply.offers o
join core.provider_brands b on b.id = o.provider_brand_id
where os.offer_id = o.id
  and b.slug = 'salud-digna'
  and os.scope_type = 'brand'
  and os.status = 'active';

-- The capability column describes the individual link.  The RPC helper below
-- computes the aggregate capability after applying location > market > brand
-- scope precedence.
update supply.offer_links
set link_capability = case link_target
  when 'study' then 'study_only'
  when 'location' then 'location_only'
  when 'study_and_location' then 'study_and_location'
  when 'provider' then 'provider_only'
  when 'booking' then 'provider_only'
  when 'handoff' then 'none'
  else 'none'
end;

create or replace function supply.resolve_offer_link_metadata(
  p_offer_id uuid,
  p_provider_location_id uuid default null
)
returns table (
  study_url text,
  location_url text,
  booking_url text,
  link_capability text,
  handoff_data jsonb
)
language sql
stable
parallel safe
security definer
set search_path = supply, core, public
as $$
with eligible_scopes as (
  select os.id,
    case os.scope_type when 'location' then 3 when 'market' then 2 else 1 end::smallint as specificity
  from supply.offer_scopes os
  where os.offer_id = p_offer_id
    and os.status = 'active'
    and (
      os.scope_type = 'brand'
      or (os.scope_type = 'location' and os.provider_location_id = p_provider_location_id)
      or (
        os.scope_type = 'market'
        and (
          p_provider_location_id is null
          or exists (
            select 1
            from core.provider_market_locations pml
            where pml.provider_market_id = os.provider_market_id
              and pml.provider_location_id = p_provider_location_id
          )
        )
      )
    )
), ranked_links as (
  select l.id, l.url, l.link_target, l.handoff_data,
    row_number() over (
      partition by l.link_target
      order by es.specificity desc, l.verified_at desc nulls last, l.created_at desc, l.id
    ) as target_rank
  from supply.offer_links l
  join eligible_scopes es on es.id = l.offer_scope_id
  where l.status = 'active'
    and (l.url is not null or l.link_target = 'handoff')
), selected as (
  select
    max(url) filter (where link_target = 'study' and target_rank = 1) as study_url,
    max(url) filter (where link_target = 'location' and target_rank = 1) as location_url,
    max(url) filter (where link_target = 'booking' and target_rank = 1) as booking_url,
    bool_or(link_target in ('provider', 'booking')) as has_provider_link,
    (array_agg(handoff_data order by target_rank) filter (where link_target = 'handoff' and target_rank = 1))[1] as handoff_data
  from ranked_links
)
select
  s.study_url,
  s.location_url,
  s.booking_url,
  case
    when s.study_url is not null and s.location_url is not null then 'study_and_location'
    when s.study_url is not null then 'study_only'
    when s.location_url is not null then 'location_only'
    when coalesce(s.has_provider_link, false) then 'provider_only'
    else 'none'
  end,
  coalesce(s.handoff_data, '{}'::jsonb)
from selected s;
$$;

revoke all on function supply.validate_offer_link_metadata() from public, anon, authenticated;
revoke all on function supply.resolve_offer_link_metadata(uuid, uuid) from public, anon, authenticated;
grant execute on function supply.resolve_offer_link_metadata(uuid, uuid) to service_role;

-- Preserve source_url while adding typed link metadata to the tabular API.
alter function public.api_search(text, text, double precision, double precision, uuid, integer)
  rename to api_search_links_legacy_v1;

create function public.api_search(
  p_query text,
  p_domain_code text default 'health_diagnostics',
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_location_id uuid default null,
  p_limit integer default 20
)
returns table (
  service_id uuid,
  display_name text,
  matched_term text,
  term_source text,
  confidence numeric,
  offer_id uuid,
  provider_brand_id uuid,
  provider_name text,
  provider_location_id uuid,
  provider_location_name text,
  latitude double precision,
  longitude double precision,
  distance_meters double precision,
  source_url text,
  study_url text,
  location_url text,
  booking_url text,
  link_capability text,
  link_handoff jsonb,
  price_type text,
  price_key text,
  amount_minor bigint,
  currency char(3),
  price_last_seen_at timestamptz
)
language sql
stable
parallel safe
security definer
set search_path = public, supply
as $$
with rows as materialized (
  select * from public.api_search_links_legacy_v1(
    p_query, p_domain_code, p_latitude, p_longitude, p_location_id, p_limit * 3
  )
), preferred as (
  select r.*
  from rows r
  where r.provider_location_id is not null
     or not exists (
       select 1
       from supply.offer_scopes concrete
       where concrete.offer_id = r.offer_id
         and concrete.scope_type = 'location'
         and concrete.status = 'active'
     )
)
select
  r.service_id,
  r.display_name,
  r.matched_term,
  r.term_source,
  r.confidence,
  r.offer_id,
  r.provider_brand_id,
  r.provider_name,
  r.provider_location_id,
  r.provider_location_name,
  r.latitude,
  r.longitude,
  r.distance_meters,
  r.source_url,
  lm.study_url,
  lm.location_url,
  lm.booking_url,
  lm.link_capability,
  lm.handoff_data,
  r.price_type,
  r.price_key,
  r.amount_minor,
  r.currency,
  r.price_last_seen_at
from preferred r
left join lateral supply.resolve_offer_link_metadata(r.offer_id, r.provider_location_id) lm on true
order by r.confidence desc, r.distance_meters nulls last, r.provider_name, r.display_name
limit greatest(1, least(coalesce(p_limit, 20), 100));
$$;

revoke all on function public.api_search_links_legacy_v1(text, text, double precision, double precision, uuid, integer) from public, anon, authenticated;
revoke all on function public.api_search(text, text, double precision, double precision, uuid, integer) from public, anon, authenticated;
grant execute on function public.api_search(text, text, double precision, double precision, uuid, integer) to service_role;

-- Resolve-search and package wrappers retain their established contracts and
-- enrich only each concrete offer with the same typed link metadata.
alter function public.api_resolve_search_v4(text, text, double precision, double precision, uuid, integer)
  rename to api_resolve_search_v4_links_legacy;

create function public.api_resolve_search_v4(
  p_query text,
  p_domain_code text default 'health_diagnostics',
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_location_id uuid default null,
  p_limit integer default 20
)
returns jsonb
language sql
stable
parallel safe
security definer
set search_path = public, supply
as $$
with base as (
  select public.api_resolve_search_v4_links_legacy(
    p_query, p_domain_code, p_latitude, p_longitude, p_location_id, p_limit
  ) as payload
), candidates as (
  select c.ordinality,
    c.value || jsonb_build_object(
      'offers', coalesce((
        select jsonb_agg(
          o.value || jsonb_build_object(
            'study_url', lm.study_url,
            'location_url', lm.location_url,
            'booking_url', lm.booking_url,
            'link_capability', lm.link_capability,
            'link_handoff', lm.handoff_data
          ) order by o.ordinality
        )
        from jsonb_array_elements(
          case when jsonb_typeof(c.value->'offers') = 'array' then c.value->'offers' else '[]'::jsonb end
        ) with ordinality o(value, ordinality)
        left join lateral supply.resolve_offer_link_metadata(
          (o.value->>'offer_id')::uuid,
          nullif(o.value->>'provider_location_id', '')::uuid
        ) lm on true
        where not exists (
          -- The renamed legacy resolver is bound to the pre-metadata search
          -- function.  Suppress its broad brand fallback when a concrete
          -- location scope exists for a different branch.
          select 1
          from supply.offer_scopes concrete
          where concrete.offer_id = (o.value->>'offer_id')::uuid
            and concrete.scope_type = 'location'
            and concrete.status = 'active'
            and concrete.provider_location_id is distinct from
              nullif(o.value->>'provider_location_id', '')::uuid
        )
      ), '[]'::jsonb)
    ) as value
  from base b
  cross join jsonb_array_elements(
    case when jsonb_typeof(b.payload->'candidates') = 'array' then b.payload->'candidates' else '[]'::jsonb end
  ) with ordinality c(value, ordinality)
)
select b.payload || jsonb_build_object(
  'candidates', coalesce((select jsonb_agg(c.value order by c.ordinality) from candidates c), '[]'::jsonb)
)
from base b;
$$;

revoke all on function public.api_resolve_search_v4_links_legacy(text, text, double precision, double precision, uuid, integer) from public, anon, authenticated;
revoke all on function public.api_resolve_search_v4(text, text, double precision, double precision, uuid, integer) from public, anon, authenticated;
grant execute on function public.api_resolve_search_v4(text, text, double precision, double precision, uuid, integer) to service_role;

alter function public.api_resolve_package_internal(jsonb, text, double precision, double precision, uuid, integer)
  rename to api_resolve_package_links_legacy;

create function public.api_resolve_package_internal(
  p_items jsonb,
  p_domain_code text default 'health_diagnostics',
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_location_id uuid default null,
  p_limit integer default 10
)
returns jsonb
language sql
stable
parallel safe
security definer
set search_path = public, supply
as $$
with base as (
  select public.api_resolve_package_links_legacy(
    p_items, p_domain_code, p_latitude, p_longitude, p_location_id, p_limit
  ) as payload
), offers as (
  select o.ordinality,
    o.value || jsonb_build_object(
      'study_url', lm.study_url,
      'location_url', lm.location_url,
      'booking_url', lm.booking_url,
      'link_capability', lm.link_capability,
      'link_handoff', lm.handoff_data
    ) as value
  from base b
  cross join jsonb_array_elements(
    case when jsonb_typeof(b.payload->'offers') = 'array' then b.payload->'offers' else '[]'::jsonb end
  ) with ordinality o(value, ordinality)
  left join lateral supply.resolve_offer_link_metadata(
    (o.value->>'offer_id')::uuid,
    nullif(o.value->>'provider_location_id', '')::uuid
  ) lm on true
  where not exists (
    -- A concrete location scope wins over the legacy brand expansion.  This
    -- is essential for providers whose catalog was observed at one branch:
    -- a brand fallback must not manufacture availability at every branch.
    select 1
    from supply.offer_scopes concrete
    where concrete.offer_id = (o.value->>'offer_id')::uuid
      and concrete.scope_type = 'location'
      and concrete.status = 'active'
      and concrete.provider_location_id is distinct from
        nullif(o.value->>'provider_location_id', '')::uuid
  )
)
select b.payload || jsonb_build_object(
  'offers', coalesce((select jsonb_agg(o.value order by o.ordinality) from offers o), '[]'::jsonb)
)
from base b;
$$;

revoke all on function public.api_resolve_package_links_legacy(jsonb, text, double precision, double precision, uuid, integer) from public, anon, authenticated;
revoke all on function public.api_resolve_package_internal(jsonb, text, double precision, double precision, uuid, integer) from public, anon, authenticated;
grant execute on function public.api_resolve_package_internal(jsonb, text, double precision, double precision, uuid, integer) to service_role;

commit;
