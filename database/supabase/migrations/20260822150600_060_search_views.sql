-- Search-friendly views and helper functions. No app-specific UI logic here.

begin;

create or replace view catalog.search_terms as
select
  n.item_id,
  n.locale,
  n.name as term,
  n.normalized_name as normalized_term,
  'name'::text as term_source,
  null::uuid as provider_brand_id,
  case when n.is_primary then 1.00::numeric else 0.98::numeric end as weight
from catalog.item_names n
join catalog.items i on i.id = n.item_id
where i.status = 'active'
union all
select
  a.item_id,
  a.locale,
  a.alias as term,
  a.normalized_alias as normalized_term,
  'alias'::text as term_source,
  a.provider_brand_id,
  a.confidence as weight
from catalog.item_aliases a
join catalog.items i on i.id = a.item_id
where a.status = 'approved' and i.status = 'active';

create or replace function catalog.search_items(
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
  similarity_score real,
  weighted_score numeric
)
language sql
stable
as $$
with q as (
  select core.normalized_text(p_query) as normalized_query
),
ranked as (
  select
    st.item_id,
    coalesce(
      (select n.name from catalog.item_names n where n.item_id = st.item_id and n.is_primary order by n.locale = 'es-MX' desc limit 1),
      st.term
    ) as display_name,
    st.term as matched_term,
    st.term_source,
    st.provider_brand_id,
    extensions.similarity(st.normalized_term, q.normalized_query) as similarity_score,
    (extensions.similarity(st.normalized_term, q.normalized_query)::numeric * st.weight) as weighted_score,
    row_number() over (
      partition by st.item_id
      order by
        case when st.provider_brand_id = p_provider_brand_id then 0 when st.provider_brand_id is null then 1 else 2 end,
        (extensions.similarity(st.normalized_term, q.normalized_query)::numeric * st.weight) desc
    ) as rn
  from catalog.search_terms st
  join catalog.items i on i.id = st.item_id
  join catalog.domains d on d.id = i.domain_id
  cross join q
  where d.code = p_domain_code
    and (st.provider_brand_id is null or st.provider_brand_id = p_provider_brand_id)
    and (
      st.normalized_term = q.normalized_query
      or extensions.similarity(st.normalized_term, q.normalized_query) >= 0.25
      or st.normalized_term like '%' || q.normalized_query || '%'
    )
)
select item_id, display_name, matched_term, term_source, provider_brand_id,
       similarity_score, weighted_score
from ranked
where rn = 1
order by weighted_score desc, display_name
limit greatest(1, least(p_limit, 50));
$$;

create or replace view supply.current_price_versions as
select *
from supply.price_versions
where is_current
  and (valid_from is null or now() >= valid_from)
  and (valid_to is null or now() < valid_to);

commit;
