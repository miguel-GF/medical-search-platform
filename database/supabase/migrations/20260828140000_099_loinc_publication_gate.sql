-- Store the review state in the identifier itself and make the public
-- resolver fail closed when an exact LOINC mapping was inserted without
-- approval evidence.

begin;

alter table catalog.item_identifiers
  add column if not exists verified boolean not null default false,
  add column if not exists approved_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'catalog.item_identifiers'::regclass
      and conname = 'catalog_item_identifiers_approval_consistency_ck'
  ) then
    alter table catalog.item_identifiers
      add constraint catalog_item_identifiers_approval_consistency_ck
      check (approved_at is null or verified);
  end if;
end;
$$;

drop index if exists catalog.catalog_item_identifiers_loinc_exact_active_idx;
create index catalog_item_identifiers_loinc_verified_active_idx
  on catalog.item_identifiers (lower(trim(system)), lower(trim(code)))
  where lower(trim(system)) = 'http://loinc.org'
    and mapping_type = 'exact'
    and status = 'active'
    and verified = true
    and approved_at is not null;

create or replace function catalog.resolve_items_v6(
  p_query text,
  p_domain_code text default 'health_diagnostics',
  p_provider_brand_id uuid default null,
  p_limit integer default 10
)
returns table (
  item_id uuid,
  display_name text,
  matched_term text,
  term_source text,
  provider_brand_id uuid,
  confidence numeric,
  resolution_status text,
  match_method text,
  explanation_data jsonb,
  result_rank bigint
)
language sql
stable
parallel safe
as $$
with identifier_candidates as materialized (
  select
    i.id as item_id,
    coalesce((
      select n.name
      from catalog.item_names n
      where n.item_id = i.id and n.is_primary
      order by n.locale = 'es-MX' desc, n.created_at desc
      limit 1
    ), i.id::text) as display_name,
    ii.code as matched_term,
    'loinc'::text as term_source,
    null::uuid as provider_brand_id,
    1.0000::numeric as confidence,
    ii.code,
    ii.version,
    ii.mapping_type,
    row_number() over (
      partition by i.id
      order by ii.created_at desc, ii.version desc, ii.id
    ) as item_version_rank
  from catalog.item_identifiers ii
  join catalog.items i on i.id = ii.item_id
  join catalog.domains d on d.id = i.domain_id
  where lower(trim(ii.system)) = 'http://loinc.org'
    and lower(trim(ii.code)) = lower(trim(coalesce(p_query, '')))
    and ii.mapping_type = 'exact'
    and ii.status = 'active'
    and ii.verified = true
    and ii.approved_at is not null
    and i.status = 'active'
    and d.code = p_domain_code
), identifier_matches as materialized (
  select
    c.item_id,
    c.display_name,
    c.matched_term,
    c.term_source,
    c.provider_brand_id,
    c.confidence,
    c.code,
    c.version,
    c.mapping_type,
    count(*) over () as candidate_count,
    row_number() over (order by c.version desc, c.item_id) as result_rank
  from identifier_candidates c
  where c.item_version_rank = 1
), fallback as materialized (
  select r.*
  from catalog.resolve_items_v5(
    p_query,
    p_domain_code,
    p_provider_brand_id,
    greatest(1, least(coalesce(p_limit, 10), 50))
  ) r
)
select
  m.item_id,
  m.display_name,
  m.matched_term,
  m.term_source,
  m.provider_brand_id,
  m.confidence,
  case when m.candidate_count > 1 then 'ambiguous' else 'resolved' end,
  'loinc_exact'::text,
  jsonb_build_object(
    'terminology', 'LOINC',
    'code', m.code,
    'version', m.version,
    'mapping_type', m.mapping_type
  ),
  m.result_rank
from identifier_matches m
union all
select
  f.item_id,
  f.display_name,
  f.matched_term,
  f.term_source,
  f.provider_brand_id,
  f.confidence,
  f.resolution_status,
  f.match_method,
  f.explanation_data,
  f.result_rank
from fallback f
where not exists (select 1 from identifier_matches)
order by result_rank
limit greatest(1, least(coalesce(p_limit, 10), 50));
$$;

revoke all on function catalog.resolve_items_v6(text,text,uuid,integer) from public, anon, authenticated;
grant execute on function catalog.resolve_items_v6(text,text,uuid,integer) to service_role;

commit;
