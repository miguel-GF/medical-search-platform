-- ISOLATED DRAFT, NOT ACTIVATED. Specific critical-change approval required.
-- Keep outside migrations and the local terminology queue. Revalidate dependencies and caller permissions.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
select pg_advisory_xact_lock(hashtextextended('pruevia:clinical:resolver-review',0));
do $$ begin
 if md5(pg_get_functiondef('catalog.resolve_items(text,text,uuid,integer)'::regprocedure)) <> '999a96985e1f847b51f5c685cfb80c35' then raise exception 'Resolver changed; rebase isolated reviewed draft before activation or recovery'; end if;
end $$;
CREATE OR REPLACE FUNCTION catalog.resolve_items(p_query text, p_domain_code text DEFAULT 'health_diagnostics'::text, p_provider_brand_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 10)
 RETURNS TABLE(item_id uuid, display_name text, matched_term text, term_source text, provider_brand_id uuid, confidence numeric, resolution_status text, match_method text, explanation_data jsonb, result_rank bigint)
 LANGUAGE sql
 STABLE PARALLEL SAFE
 SET search_path TO 'pg_catalog'
AS $function$
with q as (
  select core.normalized_text(p_query) as normalized_query
), qattrs as (
  select distinct l.attribute_type, l.attribute_value
  from health.query_lexicon l
  cross join q
  where l.status = 'approved'
    and q.normalized_query like '%' || l.normalized_phrase || '%'
), disambiguation as (
  select distinct t.id as term_id, t.normalized_term
  from catalog.disambiguation_terms t
  cross join q
  where t.status = 'approved'
    and (q.normalized_query = t.normalized_term
      or extensions.word_similarity(t.normalized_term, q.normalized_query) >= 0.70)
), terms as (
  select n.item_id, n.locale, n.name as term, n.normalized_name as normalized_term,
         'name'::text as term_source, null::uuid as provider_brand_id,
         case when n.is_primary then 1.00::numeric else 0.98::numeric end as weight
  from catalog.item_names n
  join catalog.items i on i.id = n.item_id and i.status = 'active'
  join catalog.domains d on d.id = i.domain_id and d.code = p_domain_code
  union all
  select a.item_id, a.locale, a.alias, a.normalized_alias, 'alias'::text,
         a.provider_brand_id, a.confidence
  from catalog.item_aliases a
  join catalog.items i on i.id = a.item_id and i.status = 'active'
  join catalog.domains d on d.id = i.domain_id and d.code = p_domain_code
  where a.status = 'approved'
    and (a.provider_brand_id is null or a.provider_brand_id = p_provider_brand_id)
  union all
  select d.item_id, d.locale, d.description, d.normalized_description, 'description'::text,
         null::uuid, 0.90::numeric
  from catalog.item_descriptions d
  join catalog.items i on i.id = d.item_id and i.status = 'active'
  join catalog.domains dm on dm.id = i.domain_id and dm.code = p_domain_code
  where d.status = 'approved'
  union all
  select dc.item_id, t.locale, t.term, t.normalized_term, 'disambiguation'::text,
         null::uuid, 0.90::numeric
  from disambiguation dx
  join catalog.disambiguation_terms t on t.id = dx.term_id
  join catalog.disambiguation_candidates dc on dc.term_id = t.id
  join catalog.items i on i.id = dc.item_id and i.status = 'active'
), scored as (
  select
    t.item_id,
    coalesce((select n.name from catalog.item_names n where n.item_id = t.item_id and n.is_primary order by n.locale = 'es-MX' desc limit 1), t.term) as display_name,
    t.term as matched_term,
    t.term_source,
    t.provider_brand_id,
    extensions.similarity(t.normalized_term, q.normalized_query)::numeric as similarity_score,
    extensions.word_similarity(t.normalized_term, q.normalized_query)::numeric as word_score,
    case when t.normalized_term = q.normalized_query then 1.00::numeric
         when t.term_source = 'disambiguation' then 0.92::numeric
         when q.normalized_query like '%' || t.normalized_term || '%' then 0.88::numeric
         else greatest(extensions.similarity(t.normalized_term, q.normalized_query)::numeric * t.weight,
                       extensions.word_similarity(t.normalized_term, q.normalized_query)::numeric * t.weight)
    end as lexical_score,
    t.weight,
    row_number() over (partition by t.item_id order by
      case when t.normalized_term = q.normalized_query then 0 else 1 end,
      t.weight desc,
      extensions.word_similarity(t.normalized_term, q.normalized_query) desc,
      extensions.similarity(t.normalized_term, q.normalized_query) desc
    ) as term_rank
  from terms t
  cross join q
  where q.normalized_query <> ''
    and (t.normalized_term = q.normalized_query
      or t.term_source = 'disambiguation'
      or q.normalized_query like '%' || t.normalized_term || '%'
      or t.normalized_term like '%' || q.normalized_query || '%'
      or extensions.similarity(t.normalized_term, q.normalized_query) >= 0.35
      or extensions.word_similarity(t.normalized_term, q.normalized_query) >= 0.45)
), best as (
  select * from scored where term_rank = 1
), enriched as (
  select
    b.*,
    coalesce((select count(*) from qattrs),0)::integer as attribute_count,
    coalesce((select count(*) from qattrs qa where
      (qa.attribute_type = 'service_type' and exists (
        select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.service_type = qa.attribute_value
      )) or (qa.attribute_type = 'method' and exists (
        select 1 from health.service_methods sm where sm.service_id = b.item_id and sm.status = 'approved' and sm.method_code = qa.attribute_value
      )) or (qa.attribute_type = 'modality' and exists (
        select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.modality = qa.attribute_value
      )) or (qa.attribute_type = 'anatomical_site' and exists (
        select 1 from health.service_anatomy sa join health.anatomical_sites an on an.id = sa.anatomical_site_id where sa.service_id = b.item_id and an.code = qa.attribute_value
      )) or (qa.attribute_type = 'laterality' and exists (
        select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.laterality = qa.attribute_value
      )) or (qa.attribute_type = 'contrast_mode' and exists (
        select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.contrast_mode = qa.attribute_value
      )) or (qa.attribute_type = 'specimen' and exists (
        select 1 from health.service_specimens ss join health.specimen_types sp on sp.id = ss.specimen_type_id where ss.service_id = b.item_id and (sp.code = qa.attribute_value or sp.normalized_name = qa.attribute_value)
      ))
    ),0)::integer as attribute_matches,
    exists (select 1 from qattrs qa where
      (qa.attribute_type = 'service_type' and not exists (select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.service_type = qa.attribute_value))
      or (qa.attribute_type = 'method' and not exists (select 1 from health.service_methods sm where sm.service_id = b.item_id and sm.status = 'approved' and sm.method_code = qa.attribute_value))
      or (qa.attribute_type = 'modality' and not exists (select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.modality = qa.attribute_value))
      or (qa.attribute_type = 'anatomical_site' and not exists (select 1 from health.service_anatomy sa join health.anatomical_sites an on an.id = sa.anatomical_site_id where sa.service_id = b.item_id and an.code = qa.attribute_value))
      or (qa.attribute_type = 'laterality' and not exists (select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.laterality = qa.attribute_value))
      or (qa.attribute_type = 'contrast_mode' and not exists (select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.contrast_mode = qa.attribute_value))
    ) as hard_conflict
  from best b
), accepted as (
  select e.*,
    least(1.00::numeric, greatest(e.lexical_score, 0) + case when e.attribute_count = 0 then 0 else e.attribute_matches::numeric / e.attribute_count::numeric * 0.12 end) as final_score
  from enriched e
  where not e.hard_conflict
    and (e.lexical_score >= 0.45 or e.term_source in ('name','alias','disambiguation'))
    and (e.attribute_count = 0 or e.attribute_matches::numeric / e.attribute_count::numeric >= 0.80)
), ranked as (
  select a.*, row_number() over (order by a.final_score desc, a.display_name) as result_rank,
    lead(a.final_score) over (order by a.final_score desc, a.display_name) as next_score,
    exists (select 1 from disambiguation) as has_disambiguation
  from accepted a
)
select
  r.item_id,
  r.display_name,
  r.matched_term,
  r.term_source,
  r.provider_brand_id,
  r.final_score as confidence,
  case when r.has_disambiguation or (r.next_score is not null and r.final_score - r.next_score < 0.15)
       then 'ambiguous' else 'resolved' end as resolution_status,
  case when r.term_source = 'disambiguation' then 'disambiguation'
       when r.lexical_score >= 0.999 then 'exact'
       when r.term_source = 'alias' then 'alias'
       when r.word_score >= r.similarity_score then 'word_fuzzy'
       else 'trigram' end as match_method,
  jsonb_build_object(
    'lexical_score', r.lexical_score,
    'similarity_score', r.similarity_score,
    'word_score', r.word_score,
    'attribute_count', r.attribute_count,
    'attribute_matches', r.attribute_matches,
    'hard_conflict', r.hard_conflict,
    'next_score', r.next_score
  ) as explanation_data
  ,r.result_rank
from ranked r
where r.result_rank <= greatest(1, least(coalesce(p_limit,10),50))
order by r.result_rank;
$function$
do $$ begin
 if md5(pg_get_functiondef('catalog.resolve_items(text,text,uuid,integer)'::regprocedure)) <> '067b7a2fe0826ccaa48ece0a5dfd8d1d' then raise exception 'Resolver changed; rebase isolated reviewed draft before activation or recovery'; end if;
end $$;
insert into audit.events(actor_type,action,entity_schema,entity_table,entity_id,request_id,metadata) values('system','catalog.clinical_constraint_recovery','catalog','items','acd5b4eb-8d9d-5e17-88b8-8f7eaa568138'::uuid,'pruevia:proposal:antibody-class-conflict:20261011:recovery',jsonb_build_object('restored_md5','067b7a2fe0826ccaa48ece0a5dfd8d1d'));
commit;
