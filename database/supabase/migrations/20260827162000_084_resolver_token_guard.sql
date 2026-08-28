-- Resolver guard: whole-string similarity must be supported by meaningful token
-- overlap. This prevents audiometria/aluminio from matching unrelated queries
-- merely because they share short substrings or stop words.

begin;

insert into health.query_lexicon(phrase, normalized_phrase, attribute_type, attribute_value, source_note)
values
  ('extremidades inferiore','extremidades inferiore','anatomical_site','lower_extremity','Resolver Gate B OCR variant')
on conflict do nothing;

create or replace function catalog.resolve_items_v2(
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
with q as (
  select core.normalized_text(p_query) as normalized_query
), candidates as materialized (
  select r.*
  from catalog.resolve_items(p_query, p_domain_code, p_provider_brand_id, greatest(50, coalesce(p_limit,10) * 4)) r
), guarded as (
  select c.*,
    (
      select count(*)
      from unnest(string_to_array(q.normalized_query, ' ')) as qt(token)
      where length(qt.token) >= 4
        and qt.token not in ('para','como','desde','entre','sobre','este','esta','estos','estas','con','sin','del','las','los','una','uno','por','que','sus','en','de','el','la','y')
        and exists (
          select 1
          from unnest(string_to_array(core.normalized_text(c.matched_term), ' ')) as mt(token)
          where mt.token = qt.token
             or mt.token like qt.token || '%'
             or qt.token like mt.token || '%'
             or extensions.word_similarity(mt.token, qt.token) >= 0.80
        )
    )::integer as meaningful_token_matches,
    (
      select count(*)
      from unnest(string_to_array(q.normalized_query, ' ')) as qt(token)
      where length(qt.token) >= 4
        and qt.token not in ('para','como','desde','entre','sobre','este','esta','estos','estas','con','sin','del','las','los','una','uno','por','que','sus','en','de','el','la','y')
    )::integer as meaningful_token_count
  from candidates c
  cross join q
), accepted as (
  select g.*
  from guarded g
  where g.match_method in ('exact','alias','disambiguation')
     or g.meaningful_token_matches >= greatest(1, ceil(g.meaningful_token_count / 2.0)::integer)
), ranked as (
  select a.*,
    count(*) over () as candidate_count,
    row_number() over (order by a.confidence desc, a.display_name) as safe_rank
  from accepted a
)
select
  r.item_id,
  r.display_name,
  r.matched_term,
  r.term_source,
  r.provider_brand_id,
  r.confidence,
  case when r.candidate_count > 1 then 'ambiguous' else r.resolution_status end as resolution_status,
  r.match_method,
  r.explanation_data || jsonb_build_object(
    'meaningful_token_matches', r.meaningful_token_matches,
    'meaningful_token_count', r.meaningful_token_count
  ) as explanation_data,
  r.safe_rank as result_rank
from ranked r
where r.safe_rank <= greatest(1, least(coalesce(p_limit,10),50))
order by r.safe_rank;
$$;

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
select r.item_id, r.display_name, r.matched_term, r.term_source,
       r.provider_brand_id, r.confidence::real, r.confidence
from catalog.resolve_items_v2(p_query, p_domain_code, p_provider_brand_id, p_limit) r
where r.resolution_status in ('resolved','ambiguous')
order by r.confidence desc, r.display_name
limit greatest(1, least(coalesce(p_limit,10),50));
$$;

revoke all on function catalog.resolve_items_v2(text,text,uuid,integer) from public;
grant execute on function catalog.resolve_items_v2(text,text,uuid,integer) to anon, authenticated, service_role;

commit;
