-- Surface exact initialisms such as BH as explicit search suggestions.
-- This remains a read-only suggestion: it never selects or resolves a study.
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
), active_names as (
  select n.item_id,
         n.normalized_name,
         (
           select string_agg(left(parts.token, 1), '' order by parts.ordinality)
           from regexp_split_to_table(n.normalized_name, '\s+')
                with ordinality as parts(token, ordinality)
           where length(parts.token) >= 3
             and parts.token ~ '^[a-z]+$'
             and parts.token not in (
               'a', 'al', 'como', 'con', 'de', 'del', 'desde', 'el', 'en',
               'entre', 'esta', 'este', 'estos', 'la', 'las', 'los', 'para',
               'por', 'que', 'sin', 'sobre', 'sus', 'un', 'una', 'uno', 'y'
             )
         ) as generated_initialism
  from catalog.item_names n
  join catalog.items i on i.id = n.item_id and i.status = 'active'
  join catalog.domains d on d.id = i.domain_id and d.code = 'health_diagnostics'
  join health.services hs on hs.catalog_item_id = i.id
  where n.locale = 'es-MX'
), scored as (
  select n.item_id,
         max(case
           when length(q.value) between 2 and 8
            and q.value ~ '^[a-z]+$'
            and n.generated_initialism = q.value then 0.95::real
           else extensions.similarity(n.normalized_name, q.value)
         end) as score
  from active_names n
  cross join q
  where (
      length(q.value) between 4 and 200
      and extensions.similarity(n.normalized_name, q.value) >= 0.55
    ) or (
      length(q.value) between 2 and 8
      and q.value ~ '^[a-z]+$'
      and n.generated_initialism = q.value
    )
  group by n.item_id
)
select s.item_id,
       primary_name.name,
       s.score
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
