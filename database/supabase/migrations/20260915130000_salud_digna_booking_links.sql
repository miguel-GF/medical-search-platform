-- Salud Digna's public booking flow accepts the laboratory service and study
-- label in the URL.  Treat that booking link as a study link for the public
-- capability aggregate while preserving booking_url for clients that support
-- a dedicated appointment action.

begin;

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
    max(url) filter (where link_target in ('study', 'booking') and target_rank = 1) as study_url,
    max(url) filter (where link_target = 'location' and target_rank = 1) as location_url,
    max(url) filter (where link_target = 'booking' and target_rank = 1) as booking_url,
    bool_or(link_target = 'provider') as has_provider_link,
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

revoke all on function supply.resolve_offer_link_metadata(uuid, uuid) from public, anon, authenticated;
grant execute on function supply.resolve_offer_link_metadata(uuid, uuid) to service_role;

commit;
