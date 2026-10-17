-- Spelling help is deliberately separate from clinical resolution. A candidate
-- here is never a confirmed study or an offer; the patient must choose/search it.
begin;

create or replace function public.api_search_spelling_suggestions(
  p_query text,
  p_limit integer default 5
)
returns table (
  item_id uuid,
  display_name text,
  similarity_score real
)
language sql
stable
security definer
set search_path = public, catalog, core, health, extensions
as $$
with q as (
  select core.normalized_text(left(coalesce(p_query, ''), 200)) as value
), scored as (
  select n.item_id,
         max(extensions.similarity(n.normalized_name, q.value)) as score
  from catalog.item_names n
  join catalog.items i on i.id = n.item_id and i.status = 'active'
  join catalog.domains d on d.id = i.domain_id and d.code = 'health_diagnostics'
  join health.services hs on hs.catalog_item_id = i.id
  cross join q
  where n.locale = 'es-MX'
    and length(q.value) between 4 and 200
    and extensions.similarity(n.normalized_name, q.value) >= 0.55
  group by n.item_id
)
select s.item_id,
       primary_name.name,
       s.score::real
from scored s
join catalog.item_names primary_name on primary_name.item_id = s.item_id
  and primary_name.is_primary and primary_name.locale = 'es-MX'
order by s.score desc, s.item_id
limit greatest(1, least(coalesce(p_limit, 5), 5));
$$;

revoke all on function public.api_search_spelling_suggestions(text, integer)
  from public, anon, authenticated;
grant execute on function public.api_search_spelling_suggestions(text, integer)
  to service_role;

commit;
