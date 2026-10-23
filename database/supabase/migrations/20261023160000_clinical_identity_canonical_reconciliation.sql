begin;
set local lock_timeout='250ms';
set local statement_timeout='10s';
create temporary table reconciliation_before on commit drop as select jsonb_build_object('services',(select jsonb_agg(to_jsonb(t)) from health.services t where catalog_item_id in ('a7496ee8-e33f-5bb7-a10a-9fea7975ed0e'::uuid,'11e0ac3a-e10e-5b21-99ec-ab557993664d'::uuid,'bef50d19-7f00-5057-9a3e-22d80b84cdba'::uuid,'4077cf47-4538-547a-a9d7-38f53aacf55f'::uuid,'224e7dcf-d6ff-54a2-9612-504ae9fca5e9'::uuid,'37bd6a75-04d4-57f7-9607-81aeef80755f'::uuid,'77b3d480-92ae-58e8-ac53-d97738b04394'::uuid,'faf3524d-76d3-5b37-8199-89e424f85e11'::uuid,'4dabc670-fd4f-565d-ac77-eb4e43c9d9c3'::uuid,'6280cf28-1d91-5ba0-8cf8-afef151b6105'::uuid,'d7bb634e-23b9-56e8-abd7-554af6d9ed36'::uuid,'c2322064-f938-5991-89f8-62d5452fb845'::uuid,'82fb01ce-3677-55a5-8423-c216a1f8c3cf'::uuid,'864084d2-d69f-5e79-86eb-cf26f6f0734e'::uuid,'1ea42453-02e1-5236-9783-fc259ef5c147'::uuid)),'lexicon',(select jsonb_agg(to_jsonb(t)) from health.query_lexicon t where id in ('6c6f85f6-9591-48e6-aa44-a2a9fbcc5ba5'::uuid,'bfd58a97-636b-411a-a25b-1c25037c61f1'::uuid,'0426f984-aefc-4ee1-b9b6-c4d1d2e353c9'::uuid)),'anatomy',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from health.service_anatomy t where service_id in ('a7496ee8-e33f-5bb7-a10a-9fea7975ed0e'::uuid,'11e0ac3a-e10e-5b21-99ec-ab557993664d'::uuid,'bef50d19-7f00-5057-9a3e-22d80b84cdba'::uuid,'4077cf47-4538-547a-a9d7-38f53aacf55f'::uuid,'224e7dcf-d6ff-54a2-9612-504ae9fca5e9'::uuid,'37bd6a75-04d4-57f7-9607-81aeef80755f'::uuid,'77b3d480-92ae-58e8-ac53-d97738b04394'::uuid,'faf3524d-76d3-5b37-8199-89e424f85e11'::uuid,'4dabc670-fd4f-565d-ac77-eb4e43c9d9c3'::uuid,'6280cf28-1d91-5ba0-8cf8-afef151b6105'::uuid,'d7bb634e-23b9-56e8-abd7-554af6d9ed36'::uuid,'c2322064-f938-5991-89f8-62d5452fb845'::uuid,'82fb01ce-3677-55a5-8423-c216a1f8c3cf'::uuid,'864084d2-d69f-5e79-86eb-cf26f6f0734e'::uuid,'1ea42453-02e1-5236-9783-fc259ef5c147'::uuid))) payload;
do $guard$ begin
if md5(pg_get_functiondef('catalog.resolve_items(text,text,uuid,integer)'::regprocedure)) <> '067b7a2fe0826ccaa48ece0a5dfd8d1d' then raise exception 'Function changed since preparation'; end if;
if md5(pg_get_functiondef('catalog.resolve_items_v3(text,text,uuid,integer)'::regprocedure)) <> '04a16e148fb6d3ee0838890818bdc6e9' then raise exception 'Function changed since preparation'; end if;
if md5(pg_get_functiondef('catalog.resolve_items_v4(text,text,uuid,integer)'::regprocedure)) <> '21964858bf258a1b49e83e93f371cf01' then raise exception 'Function changed since preparation'; end if;
if md5(pg_get_functiondef('catalog.resolve_items_v6(text,text,uuid,integer)'::regprocedure)) <> '62e3527a60897b7d01323e7bd83f3453' then raise exception 'Function changed since preparation'; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id='a7496ee8-e33f-5bb7-a10a-9fea7975ed0e'::uuid) is distinct from '{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "a7496ee8-e33f-5bb7-a10a-9fea7975ed0e", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}'::jsonb then raise exception 'Reviewed row changed'; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id='11e0ac3a-e10e-5b21-99ec-ab557993664d'::uuid) is distinct from '{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "11e0ac3a-e10e-5b21-99ec-ab557993664d", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}'::jsonb then raise exception 'Reviewed row changed'; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id='bef50d19-7f00-5057-9a3e-22d80b84cdba'::uuid) is distinct from '{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "bef50d19-7f00-5057-9a3e-22d80b84cdba", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}'::jsonb then raise exception 'Reviewed row changed'; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id='4077cf47-4538-547a-a9d7-38f53aacf55f'::uuid) is distinct from '{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "4077cf47-4538-547a-a9d7-38f53aacf55f", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}'::jsonb then raise exception 'Reviewed row changed'; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id='224e7dcf-d6ff-54a2-9612-504ae9fca5e9'::uuid) is distinct from '{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "224e7dcf-d6ff-54a2-9612-504ae9fca5e9", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}'::jsonb then raise exception 'Reviewed row changed'; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id='37bd6a75-04d4-57f7-9607-81aeef80755f'::uuid) is distinct from '{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "37bd6a75-04d4-57f7-9607-81aeef80755f", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}'::jsonb then raise exception 'Reviewed row changed'; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id='77b3d480-92ae-58e8-ac53-d97738b04394'::uuid) is distinct from '{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "77b3d480-92ae-58e8-ac53-d97738b04394", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}'::jsonb then raise exception 'Reviewed row changed'; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id='864084d2-d69f-5e79-86eb-cf26f6f0734e'::uuid) is distinct from '{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "864084d2-d69f-5e79-86eb-cf26f6f0734e", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}'::jsonb then raise exception 'Reviewed row changed'; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id='faf3524d-76d3-5b37-8199-89e424f85e11'::uuid) is distinct from '{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "faf3524d-76d3-5b37-8199-89e424f85e11", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}'::jsonb then raise exception 'Reviewed row changed'; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id='4dabc670-fd4f-565d-ac77-eb4e43c9d9c3'::uuid) is distinct from '{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "4dabc670-fd4f-565d-ac77-eb4e43c9d9c3", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}'::jsonb then raise exception 'Reviewed row changed'; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id='6280cf28-1d91-5ba0-8cf8-afef151b6105'::uuid) is distinct from '{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "6280cf28-1d91-5ba0-8cf8-afef151b6105", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}'::jsonb then raise exception 'Reviewed row changed'; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id='d7bb634e-23b9-56e8-abd7-554af6d9ed36'::uuid) is distinct from '{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "d7bb634e-23b9-56e8-abd7-554af6d9ed36", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}'::jsonb then raise exception 'Reviewed row changed'; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id='c2322064-f938-5991-89f8-62d5452fb845'::uuid) is distinct from '{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "c2322064-f938-5991-89f8-62d5452fb845", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}'::jsonb then raise exception 'Reviewed row changed'; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id='82fb01ce-3677-55a5-8423-c216a1f8c3cf'::uuid) is distinct from '{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "82fb01ce-3677-55a5-8423-c216a1f8c3cf", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}'::jsonb then raise exception 'Reviewed row changed'; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id='1ea42453-02e1-5236-9783-fc259ef5c147'::uuid) is distinct from '{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "1ea42453-02e1-5236-9783-fc259ef5c147", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}'::jsonb then raise exception 'Reviewed row changed'; end if;
if (select to_jsonb(t) from health.query_lexicon t where id='6c6f85f6-9591-48e6-aa44-a2a9fbcc5ba5'::uuid) is distinct from '{"id": "6c6f85f6-9591-48e6-aa44-a2a9fbcc5ba5", "locale": "es-MX", "phrase": "T3 libre", "status": "approved", "created_at": "2026-08-29T06:54:50.935691+00:00", "source_note": "Resolver benchmark v1: free T3 must not resolve to the reviewed total T3 or free T4 item.", "attribute_type": "service_type", "attribute_value": "__blocked_analyte_variant__", "normalized_phrase": "t3 libre"}'::jsonb then raise exception 'Reviewed row changed'; end if;
if (select to_jsonb(t) from health.query_lexicon t where id='bfd58a97-636b-411a-a25b-1c25037c61f1'::uuid) is distinct from '{"id": "bfd58a97-636b-411a-a25b-1c25037c61f1", "locale": "es-MX", "phrase": "Triyodotironina libre", "status": "approved", "created_at": "2026-08-29T06:54:50.935691+00:00", "source_note": "Resolver benchmark v1: free T3 is not the reviewed total T3 mapping.", "attribute_type": "service_type", "attribute_value": "__blocked_analyte_variant__", "normalized_phrase": "triyodotironina libre"}'::jsonb then raise exception 'Reviewed row changed'; end if;
if (select to_jsonb(t) from health.query_lexicon t where id='0426f984-aefc-4ee1-b9b6-c4d1d2e353c9'::uuid) is distinct from '{"id": "0426f984-aefc-4ee1-b9b6-c4d1d2e353c9", "locale": "es-MX", "phrase": "Triiodotironina libre", "status": "approved", "created_at": "2026-08-29T06:54:50.935691+00:00", "source_note": "Resolver benchmark v1: free T3 is not the reviewed total T3 mapping.", "attribute_type": "service_type", "attribute_value": "__blocked_analyte_variant__", "normalized_phrase": "triiodotironina libre"}'::jsonb then raise exception 'Reviewed row changed'; end if;
if exists(select 1 from health.service_anatomy where service_id in ('c2322064-f938-5991-89f8-62d5452fb845'::uuid,'864084d2-d69f-5e79-86eb-cf26f6f0734e'::uuid,'1ea42453-02e1-5236-9783-fc259ef5c147'::uuid)) then raise exception 'Anatomy baseline changed'; end if; end $guard$;
do $$ begin update health.services set modality='magnetic_resonance',contrast_mode='with' where catalog_item_id='a7496ee8-e33f-5bb7-a10a-9fea7975ed0e'::uuid and modality is not distinct from NULL and contrast_mode is not distinct from 'not_applicable'; if not found then raise exception 'Reviewed service attributes changed'; end if; end $$;
do $$ begin update health.services set modality='magnetic_resonance',contrast_mode='with' where catalog_item_id='11e0ac3a-e10e-5b21-99ec-ab557993664d'::uuid and modality is not distinct from NULL and contrast_mode is not distinct from 'not_applicable'; if not found then raise exception 'Reviewed service attributes changed'; end if; end $$;
do $$ begin update health.services set modality='magnetic_resonance',contrast_mode='with',laterality='right' where catalog_item_id='bef50d19-7f00-5057-9a3e-22d80b84cdba'::uuid and modality is not distinct from NULL and contrast_mode is not distinct from 'not_applicable' and laterality is not distinct from 'not_applicable'; if not found then raise exception 'Reviewed service attributes changed'; end if; end $$;
do $$ begin update health.services set modality='magnetic_resonance',contrast_mode='with',laterality='left' where catalog_item_id='4077cf47-4538-547a-a9d7-38f53aacf55f'::uuid and modality is not distinct from NULL and contrast_mode is not distinct from 'not_applicable' and laterality is not distinct from 'not_applicable'; if not found then raise exception 'Reviewed service attributes changed'; end if; end $$;
do $$ begin update health.services set modality='magnetic_resonance',contrast_mode='with' where catalog_item_id='224e7dcf-d6ff-54a2-9612-504ae9fca5e9'::uuid and modality is not distinct from NULL and contrast_mode is not distinct from 'not_applicable'; if not found then raise exception 'Reviewed service attributes changed'; end if; end $$;
do $$ begin update health.services set modality='magnetic_resonance',contrast_mode='with',laterality='right' where catalog_item_id='37bd6a75-04d4-57f7-9607-81aeef80755f'::uuid and modality is not distinct from NULL and contrast_mode is not distinct from 'not_applicable' and laterality is not distinct from 'not_applicable'; if not found then raise exception 'Reviewed service attributes changed'; end if; end $$;
do $$ begin update health.services set modality='magnetic_resonance',contrast_mode='with',laterality='left' where catalog_item_id='77b3d480-92ae-58e8-ac53-d97738b04394'::uuid and modality is not distinct from NULL and contrast_mode is not distinct from 'not_applicable' and laterality is not distinct from 'not_applicable'; if not found then raise exception 'Reviewed service attributes changed'; end if; end $$;
do $$ begin update health.services set modality='magnetic_resonance',contrast_mode='with',laterality='right' where catalog_item_id='faf3524d-76d3-5b37-8199-89e424f85e11'::uuid and modality is not distinct from NULL and contrast_mode is not distinct from 'not_applicable' and laterality is not distinct from 'not_applicable'; if not found then raise exception 'Reviewed service attributes changed'; end if; end $$;
do $$ begin update health.services set modality='magnetic_resonance',contrast_mode='with',laterality='left' where catalog_item_id='4dabc670-fd4f-565d-ac77-eb4e43c9d9c3'::uuid and modality is not distinct from NULL and contrast_mode is not distinct from 'not_applicable' and laterality is not distinct from 'not_applicable'; if not found then raise exception 'Reviewed service attributes changed'; end if; end $$;
do $$ begin update health.services set modality='magnetic_resonance',contrast_mode='with' where catalog_item_id='6280cf28-1d91-5ba0-8cf8-afef151b6105'::uuid and modality is not distinct from NULL and contrast_mode is not distinct from 'not_applicable'; if not found then raise exception 'Reviewed service attributes changed'; end if; end $$;
do $$ begin update health.services set modality='magnetic_resonance',contrast_mode='with' where catalog_item_id='d7bb634e-23b9-56e8-abd7-554af6d9ed36'::uuid and modality is not distinct from NULL and contrast_mode is not distinct from 'not_applicable'; if not found then raise exception 'Reviewed service attributes changed'; end if; end $$;
do $$ begin update health.services set modality='tomography' where catalog_item_id='c2322064-f938-5991-89f8-62d5452fb845'::uuid and modality is not distinct from NULL; if not found then raise exception 'Reviewed service attributes changed'; end if; end $$;
insert into health.service_anatomy(service_id,anatomical_site_id,role,laterality_override,created_at) values ('c2322064-f938-5991-89f8-62d5452fb845'::uuid,'fc59e391-f865-4a8e-aa63-93b1c66f2b01'::uuid,'target',NULL,now());
do $$ begin update health.services set modality='tomography',contrast_mode='with',laterality='right' where catalog_item_id='82fb01ce-3677-55a5-8423-c216a1f8c3cf'::uuid and modality is not distinct from NULL and contrast_mode is not distinct from 'not_applicable' and laterality is not distinct from 'not_applicable'; if not found then raise exception 'Reviewed service attributes changed'; end if; end $$;
do $$ begin update health.services set modality='ultrasound',laterality='bilateral' where catalog_item_id='864084d2-d69f-5e79-86eb-cf26f6f0734e'::uuid and modality is not distinct from NULL and laterality is not distinct from 'not_applicable'; if not found then raise exception 'Reviewed service attributes changed'; end if; end $$;
insert into health.service_anatomy(service_id,anatomical_site_id,role,laterality_override,created_at) values ('864084d2-d69f-5e79-86eb-cf26f6f0734e'::uuid,'fc59e391-f865-4a8e-aa63-93b1c66f2b01'::uuid,'target',NULL,now());
do $$ begin update health.services set modality='ultrasound',laterality='bilateral' where catalog_item_id='1ea42453-02e1-5236-9783-fc259ef5c147'::uuid and modality is not distinct from NULL and laterality is not distinct from 'not_applicable'; if not found then raise exception 'Reviewed service attributes changed'; end if; end $$;
insert into health.service_anatomy(service_id,anatomical_site_id,role,laterality_override,created_at) values ('1ea42453-02e1-5236-9783-fc259ef5c147'::uuid,'b2850360-bdaf-404a-b219-964aa530814b'::uuid,'target',NULL,now());
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
      )) or (qa.attribute_type = 'component' and exists (
        select 1 from health.lab_service_definitions ld where ld.service_id = b.item_id and ld.component = qa.attribute_value
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
      or (qa.attribute_type = 'component' and not exists (select 1 from health.lab_service_definitions ld where ld.service_id = b.item_id and ld.component = qa.attribute_value))
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
$function$;
update health.query_lexicon set attribute_type='component',attribute_value='Triiodothyronine.free' where id in ('6c6f85f6-9591-48e6-aa44-a2a9fbcc5ba5'::uuid,'bfd58a97-636b-411a-a25b-1c25037c61f1'::uuid,'0426f984-aefc-4ee1-b9b6-c4d1d2e353c9'::uuid);
CREATE OR REPLACE FUNCTION catalog.resolve_items_v3(p_query text, p_domain_code text DEFAULT 'health_diagnostics'::text, p_provider_brand_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 10)
 RETURNS TABLE(item_id uuid, display_name text, matched_term text, term_source text, provider_brand_id uuid, confidence numeric, resolution_status text, match_method text, explanation_data jsonb, result_rank bigint)
 LANGUAGE sql
 STABLE PARALLEL SAFE
 SET search_path TO 'pg_catalog'
AS $function$
with q as (
  select core.normalized_text(p_query) as normalized_query
), candidates as materialized (
  select r.*
  from catalog.resolve_items_v2(p_query, p_domain_code, p_provider_brand_id, greatest(50, coalesce(p_limit,10) * 4)) r
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
), lexical_accepted as materialized (
  select g.*
  from guarded g
  where g.match_method in ('exact','alias','disambiguation')
     or (g.meaningful_token_count > 0 and g.meaningful_token_matches = g.meaningful_token_count)
), requirement_checked as materialized (
  select a.*,
    not exists (
      select 1
      from unnest(string_to_array(core.normalized_text(p_query), ' ')) as qt(token)
      where qt.token <> ''
        and qt.token not in ('de','del','el','la','los','las','en')
        and not (qt.token = any(string_to_array(core.normalized_text(a.matched_term), ' ')))
    ) as literal_requirements_present,
    (a.term_source in ('name','alias') and a.match_method in ('exact','alias')
      and a.confidence = 1
      and core.normalized_text(a.matched_term)=core.normalized_text(p_query)) as exact_identity_literal,
    (core.normalized_text(p_query) ~ '^[a-z]{4,40}$'
      and not (core.normalized_text(p_query) = any(string_to_array(core.normalized_text(a.matched_term),' ')))
      and exists(select 1 from unnest(string_to_array(core.normalized_text(a.matched_term),' ')) mt(token)
                 where mt.token like core.normalized_text(p_query)||'%')) as prefix_discovery
  from lexical_accepted a
), accepted as (
  select a.*,
    (not a.exact_identity_literal and exists (select 1 from requirement_checked x where not x.literal_requirements_present)) as requirements_pruned
  from requirement_checked a
  where a.literal_requirements_present or a.prefix_discovery
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
  case when r.prefix_discovery or r.requirements_pruned or r.candidate_count > 1 then 'ambiguous' else r.resolution_status end as resolution_status,
  r.match_method,
  r.explanation_data || jsonb_build_object(
    'meaningful_token_matches', r.meaningful_token_matches,
    'meaningful_token_count', r.meaningful_token_count,
    'literal_requirements_present', r.literal_requirements_present,
    'requirements_pruned', r.requirements_pruned,
    'prefix_discovery', r.prefix_discovery,
    'exact_identity_literal', r.exact_identity_literal,
    'requirements_policy', 'literal-content-v2-LOCAL-EXPERIMENT'
  ) as explanation_data,
  r.safe_rank as result_rank
from ranked r
where r.safe_rank <= greatest(1, least(coalesce(p_limit,10),50))
order by r.safe_rank;
$function$;
CREATE OR REPLACE FUNCTION catalog.resolve_items_v4(p_query text, p_domain_code text DEFAULT 'health_diagnostics'::text, p_provider_brand_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 10)
 RETURNS TABLE(item_id uuid, display_name text, matched_term text, term_source text, provider_brand_id uuid, confidence numeric, resolution_status text, match_method text, explanation_data jsonb, result_rank bigint)
 LANGUAGE sql
 STABLE PARALLEL SAFE
 SET search_path TO 'pg_catalog'
AS $function$
with rows as materialized (
  select * from catalog.resolve_items_v3(p_query, p_domain_code, p_provider_brand_id, p_limit)
), ranked as (
  select rows.*, count(*) over () as safe_count
  from rows
)
select r.item_id, r.display_name, r.matched_term, r.term_source,
       r.provider_brand_id, r.confidence,
       case when not coalesce((r.explanation_data->>'exact_identity_literal')::boolean,false)
                 or coalesce((r.explanation_data->>'requirements_pruned')::boolean,false)
                 or coalesce((r.explanation_data->>'prefix_discovery')::boolean,false)
                 or r.safe_count > 1 or r.term_source = 'disambiguation' then 'ambiguous' else 'resolved' end,
       r.match_method,
       r.explanation_data || jsonb_build_object('automatic_identity_policy','exact-reviewed-identity-only-LOCAL'),
       r.result_rank
from ranked r
order by r.result_rank;
$function$;
CREATE OR REPLACE FUNCTION catalog.resolve_items_v6(p_query text, p_domain_code text DEFAULT 'health_diagnostics'::text, p_provider_brand_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 10)
 RETURNS TABLE(item_id uuid, display_name text, matched_term text, term_source text, provider_brand_id uuid, confidence numeric, resolution_status text, match_method text, explanation_data jsonb, result_rank bigint)
 LANGUAGE sql
 STABLE PARALLEL SAFE
 SET search_path TO 'pg_catalog'
AS $function$
with identifier_candidates as materialized (
  select
    i.id as item_id,
    coalesce((
      select n.name
      from catalog.item_names n
      where n.item_id = i.id and n.is_primary
      order by n.created_at desc
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
), fallback_raw as materialized (
  select r.*
  from catalog.resolve_items_v5(
    p_query,
    p_domain_code,
    p_provider_brand_id,
    greatest(1, least(coalesce(p_limit, 10), 50))
  ) r
), exact_items as materialized (
  select distinct item_id
  from fallback_raw
  where match_method = 'exact'
), fallback_filtered as materialized (
  select r.*
  from fallback_raw r
  where not exists (select 1 from exact_items)
     or r.item_id in (select e.item_id from exact_items e)
), fallback_ranked as (
  select
    f.*,
    count(*) over () as filtered_count,
    count(*) filter (where f.match_method = 'exact') over () as filtered_exact_count,
    row_number() over (order by f.confidence desc, f.display_name) as filtered_rank,
    lead(f.confidence) over (order by f.confidence desc, f.display_name) as next_filtered_confidence
  from fallback_filtered f
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
  case
    when coalesce((f.explanation_data->>'requirements_pruned')::boolean,false) then 'ambiguous'
    when f.filtered_exact_count > 1 then 'ambiguous'
    when f.filtered_exact_count = 1 then 'resolved'
    else f.resolution_status
  end,
  f.match_method,
  f.explanation_data || jsonb_build_object(
    'exact_dominance', f.filtered_exact_count = 1,
    'candidate_count_after_exact_filter', f.filtered_count
  ),
  f.filtered_rank
from fallback_ranked f
where not exists (select 1 from identifier_matches)
  and f.filtered_rank <= greatest(1, least(coalesce(p_limit, 10), 50))
order by result_rank
limit greatest(1, least(coalesce(p_limit, 10), 50));
$function$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('sin RESONANCIA MAGNÉTICA ABDOMEN INFERIOR O PELVIS CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['a7496ee8-e33f-5bb7-a10a-9fea7975ed0e'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ABDOMEN INFERIOR O PELVIS CON CONTRASTE GADOLINIO x2','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['a7496ee8-e33f-5bb7-a10a-9fea7975ed0e'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ABDOMEN INFERIOR O PELVIS CON CONTRASTE GADOLINIO x3','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['a7496ee8-e33f-5bb7-a10a-9fea7975ed0e'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ABDOMEN INFERIOR O PELVIS SIN CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['a7496ee8-e33f-5bb7-a10a-9fea7975ed0e'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ABDOMEN INFERIOR O PELVIS CON Y SIN CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['a7496ee8-e33f-5bb7-a10a-9fea7975ed0e'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('sin RESONANCIA MAGNÉTICA ABDOMEN SUPERIOR CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['11e0ac3a-e10e-5b21-99ec-ab557993664d'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ABDOMEN SUPERIOR CON CONTRASTE GADOLINIO x2','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['11e0ac3a-e10e-5b21-99ec-ab557993664d'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ABDOMEN SUPERIOR CON CONTRASTE GADOLINIO x3','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['11e0ac3a-e10e-5b21-99ec-ab557993664d'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ABDOMEN SUPERIOR SIN CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['11e0ac3a-e10e-5b21-99ec-ab557993664d'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ABDOMEN SUPERIOR CON Y SIN CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['11e0ac3a-e10e-5b21-99ec-ab557993664d'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('sin RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ANTEBRAZO DERECHO CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['bef50d19-7f00-5057-9a3e-22d80b84cdba'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ANTEBRAZO DERECHO CON CONTRASTE GADOLINIO x2','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['bef50d19-7f00-5057-9a3e-22d80b84cdba'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ANTEBRAZO DERECHO CON CONTRASTE GADOLINIO x3','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['bef50d19-7f00-5057-9a3e-22d80b84cdba'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ANTEBRAZO DERECHO SIN CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['bef50d19-7f00-5057-9a3e-22d80b84cdba'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ANTEBRAZO DERECHO CON Y SIN CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['bef50d19-7f00-5057-9a3e-22d80b84cdba'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ANTEBRAZO IZQUIERDO CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['bef50d19-7f00-5057-9a3e-22d80b84cdba'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('sin RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ANTEBRAZO IZQUIERDO CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['4077cf47-4538-547a-a9d7-38f53aacf55f'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ANTEBRAZO IZQUIERDO CON CONTRASTE GADOLINIO x2','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['4077cf47-4538-547a-a9d7-38f53aacf55f'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ANTEBRAZO IZQUIERDO CON CONTRASTE GADOLINIO x3','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['4077cf47-4538-547a-a9d7-38f53aacf55f'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ANTEBRAZO IZQUIERDO SIN CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['4077cf47-4538-547a-a9d7-38f53aacf55f'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ANTEBRAZO IZQUIERDO CON Y SIN CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['4077cf47-4538-547a-a9d7-38f53aacf55f'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ANTEBRAZO DERECHO CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['4077cf47-4538-547a-a9d7-38f53aacf55f'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('sin RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ARTERIAS PULMONARES CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['224e7dcf-d6ff-54a2-9612-504ae9fca5e9'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ARTERIAS PULMONARES CON CONTRASTE GADOLINIO x2','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['224e7dcf-d6ff-54a2-9612-504ae9fca5e9'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ARTERIAS PULMONARES CON CONTRASTE GADOLINIO x3','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['224e7dcf-d6ff-54a2-9612-504ae9fca5e9'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ARTERIAS PULMONARES SIN CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['224e7dcf-d6ff-54a2-9612-504ae9fca5e9'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ARTERIAS PULMONARES CON Y SIN CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['224e7dcf-d6ff-54a2-9612-504ae9fca5e9'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('sin RESONANCIA MAGNÉTICA ANGIORESONANCIA DE BRAZO DERECHO CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['37bd6a75-04d4-57f7-9607-81aeef80755f'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE BRAZO DERECHO CON CONTRASTE GADOLINIO x2','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['37bd6a75-04d4-57f7-9607-81aeef80755f'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE BRAZO DERECHO CON CONTRASTE GADOLINIO x3','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['37bd6a75-04d4-57f7-9607-81aeef80755f'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE BRAZO DERECHO SIN CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['37bd6a75-04d4-57f7-9607-81aeef80755f'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE BRAZO DERECHO CON Y SIN CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['37bd6a75-04d4-57f7-9607-81aeef80755f'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE BRAZO IZQUIERDO CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['37bd6a75-04d4-57f7-9607-81aeef80755f'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('sin RESONANCIA MAGNÉTICA ANGIORESONANCIA DE BRAZO IZQUIERDO CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['77b3d480-92ae-58e8-ac53-d97738b04394'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE BRAZO IZQUIERDO CON CONTRASTE GADOLINIO x2','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['77b3d480-92ae-58e8-ac53-d97738b04394'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE BRAZO IZQUIERDO CON CONTRASTE GADOLINIO x3','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['77b3d480-92ae-58e8-ac53-d97738b04394'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE BRAZO IZQUIERDO SIN CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['77b3d480-92ae-58e8-ac53-d97738b04394'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE BRAZO IZQUIERDO CON Y SIN CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['77b3d480-92ae-58e8-ac53-d97738b04394'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE BRAZO DERECHO CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['77b3d480-92ae-58e8-ac53-d97738b04394'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('sin RESONANCIA MAGNÉTICA ANGIORESONANCIA DE PIERNA DERECHA CON CONTRASTE','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['faf3524d-76d3-5b37-8199-89e424f85e11'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE PIERNA DERECHA CON CONTRASTE x2','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['faf3524d-76d3-5b37-8199-89e424f85e11'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE PIERNA DERECHA CON CONTRASTE x3','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['faf3524d-76d3-5b37-8199-89e424f85e11'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE PIERNA DERECHA SIN CONTRASTE','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['faf3524d-76d3-5b37-8199-89e424f85e11'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE PIERNA DERECHA CON Y SIN CONTRASTE','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['faf3524d-76d3-5b37-8199-89e424f85e11'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE PIERNA IZQUIERDA CON CONTRASTE','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['faf3524d-76d3-5b37-8199-89e424f85e11'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('sin RESONANCIA MAGNÉTICA ANGIORESONANCIA DE PIERNA IZQUIERDA CON CONTRASTE','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['4dabc670-fd4f-565d-ac77-eb4e43c9d9c3'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE PIERNA IZQUIERDA CON CONTRASTE x2','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['4dabc670-fd4f-565d-ac77-eb4e43c9d9c3'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE PIERNA IZQUIERDA CON CONTRASTE x3','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['4dabc670-fd4f-565d-ac77-eb4e43c9d9c3'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE PIERNA IZQUIERDA SIN CONTRASTE','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['4dabc670-fd4f-565d-ac77-eb4e43c9d9c3'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE PIERNA IZQUIERDA CON Y SIN CONTRASTE','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['4dabc670-fd4f-565d-ac77-eb4e43c9d9c3'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE PIERNA DERECHA CON CONTRASTE','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['4dabc670-fd4f-565d-ac77-eb4e43c9d9c3'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('sin RESONANCIA MAGNÉTICA ANGIORESONANCIA DE POLIGONO DE WILLIS CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['6280cf28-1d91-5ba0-8cf8-afef151b6105'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE POLIGONO DE WILLIS CON CONTRASTE GADOLINIO x2','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['6280cf28-1d91-5ba0-8cf8-afef151b6105'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE POLIGONO DE WILLIS CON CONTRASTE GADOLINIO x3','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['6280cf28-1d91-5ba0-8cf8-afef151b6105'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE POLIGONO DE WILLIS SIN CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['6280cf28-1d91-5ba0-8cf8-afef151b6105'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE POLIGONO DE WILLIS CON Y SIN CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['6280cf28-1d91-5ba0-8cf8-afef151b6105'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('sin RESONANCIA MAGNÉTICA ANGIORESONANCIA DE SISTEMA PORTAL CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['d7bb634e-23b9-56e8-abd7-554af6d9ed36'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE SISTEMA PORTAL CON CONTRASTE GADOLINIO x2','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['d7bb634e-23b9-56e8-abd7-554af6d9ed36'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE SISTEMA PORTAL CON CONTRASTE GADOLINIO x3','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['d7bb634e-23b9-56e8-abd7-554af6d9ed36'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE SISTEMA PORTAL SIN CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['d7bb634e-23b9-56e8-abd7-554af6d9ed36'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE SISTEMA PORTAL CON Y SIN CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['d7bb634e-23b9-56e8-abd7-554af6d9ed36'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('sin TOMOGRAFÍA ANGIOTOMOGRAFIA DE EXTREMIDADES INFERIORES','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['c2322064-f938-5991-89f8-62d5452fb845'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('TOMOGRAFÍA ANGIOTOMOGRAFIA DE EXTREMIDADES INFERIORES x2','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['c2322064-f938-5991-89f8-62d5452fb845'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('TOMOGRAFÍA ANGIOTOMOGRAFIA DE EXTREMIDADES INFERIORES x3','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['c2322064-f938-5991-89f8-62d5452fb845'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('sin TOMOGRAFÍA ANTEBRAZO DERECHO CON CONTRASTE','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['82fb01ce-3677-55a5-8423-c216a1f8c3cf'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('TOMOGRAFÍA ANTEBRAZO DERECHO CON CONTRASTE x2','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['82fb01ce-3677-55a5-8423-c216a1f8c3cf'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('TOMOGRAFÍA ANTEBRAZO DERECHO CON CONTRASTE x3','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['82fb01ce-3677-55a5-8423-c216a1f8c3cf'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('TOMOGRAFÍA ANTEBRAZO DERECHO SIN CONTRASTE','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['82fb01ce-3677-55a5-8423-c216a1f8c3cf'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('TOMOGRAFÍA ANTEBRAZO DERECHO CON Y SIN CONTRASTE','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['82fb01ce-3677-55a5-8423-c216a1f8c3cf'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('TOMOGRAFÍA ANTEBRAZO IZQUIERDO CON CONTRASTE','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['82fb01ce-3677-55a5-8423-c216a1f8c3cf'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('sin ULTRASONIDO DOPPLER ARTERIAL BILATERAL DE MIEMBROS INFERIORES','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['864084d2-d69f-5e79-86eb-cf26f6f0734e'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('ULTRASONIDO DOPPLER ARTERIAL BILATERAL DE MIEMBROS INFERIORES x2','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['864084d2-d69f-5e79-86eb-cf26f6f0734e'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('ULTRASONIDO DOPPLER ARTERIAL BILATERAL DE MIEMBROS INFERIORES x3','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['864084d2-d69f-5e79-86eb-cf26f6f0734e'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('sin ULTRASONIDO DOPPLER ARTERIAL BILATERAL MIEMBROS SUPERIORES','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['1ea42453-02e1-5236-9783-fc259ef5c147'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('ULTRASONIDO DOPPLER ARTERIAL BILATERAL MIEMBROS SUPERIORES x2','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['1ea42453-02e1-5236-9783-fc259ef5c147'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('ULTRASONIDO DOPPLER ARTERIAL BILATERAL MIEMBROS SUPERIORES x3','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['1ea42453-02e1-5236-9783-fc259ef5c147'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('t3 libre','health_diagnostics',null,10) where resolution_status='resolved'; if actual is distinct from ARRAY['ee4001a7-229d-5b99-bbbf-9c44aca29fe8'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('Triyodotironina libre (T3 libre)','health_diagnostics',null,10) where resolution_status='resolved'; if actual is distinct from ARRAY['ee4001a7-229d-5b99-bbbf-9c44aca29fe8'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('T3 total','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['ee4001a7-229d-5b99-bbbf-9c44aca29fe8'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('T4 libre','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['ee4001a7-229d-5b99-bbbf-9c44aca29fe8'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('T3 reversa','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['ee4001a7-229d-5b99-bbbf-9c44aca29fe8'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('Captación de T3','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['ee4001a7-229d-5b99-bbbf-9c44aca29fe8'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('T3 libre total','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['ee4001a7-229d-5b99-bbbf-9c44aca29fe8'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('T3 libre x2','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['ee4001a7-229d-5b99-bbbf-9c44aca29fe8'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('sin T3 libre','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['ee4001a7-229d-5b99-bbbf-9c44aca29fe8'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('T3 libre en orina','health_diagnostics',null,10) where resolution_status='resolved'; if actual && ARRAY['ee4001a7-229d-5b99-bbbf-9c44aca29fe8'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ABDOMEN INFERIOR O PELVIS CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual is distinct from ARRAY['a7496ee8-e33f-5bb7-a10a-9fea7975ed0e'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ABDOMEN SUPERIOR CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual is distinct from ARRAY['11e0ac3a-e10e-5b21-99ec-ab557993664d'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ANTEBRAZO DERECHO CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual is distinct from ARRAY['bef50d19-7f00-5057-9a3e-22d80b84cdba'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ANTEBRAZO IZQUIERDO CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual is distinct from ARRAY['4077cf47-4538-547a-a9d7-38f53aacf55f'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE ARTERIAS PULMONARES CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual is distinct from ARRAY['224e7dcf-d6ff-54a2-9612-504ae9fca5e9'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE BRAZO DERECHO CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual is distinct from ARRAY['37bd6a75-04d4-57f7-9607-81aeef80755f'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE BRAZO IZQUIERDO CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual is distinct from ARRAY['77b3d480-92ae-58e8-ac53-d97738b04394'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE PIERNA DERECHA CON CONTRASTE','health_diagnostics',null,10) where resolution_status='resolved'; if actual is distinct from ARRAY['faf3524d-76d3-5b37-8199-89e424f85e11'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE PIERNA IZQUIERDA CON CONTRASTE','health_diagnostics',null,10) where resolution_status='resolved'; if actual is distinct from ARRAY['4dabc670-fd4f-565d-ac77-eb4e43c9d9c3'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE POLIGONO DE WILLIS CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual is distinct from ARRAY['6280cf28-1d91-5ba0-8cf8-afef151b6105'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('RESONANCIA MAGNÉTICA ANGIORESONANCIA DE SISTEMA PORTAL CON CONTRASTE GADOLINIO','health_diagnostics',null,10) where resolution_status='resolved'; if actual is distinct from ARRAY['d7bb634e-23b9-56e8-abd7-554af6d9ed36'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('TOMOGRAFÍA ANGIOTOMOGRAFIA DE EXTREMIDADES INFERIORES','health_diagnostics',null,10) where resolution_status='resolved'; if actual is distinct from ARRAY['c2322064-f938-5991-89f8-62d5452fb845'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('TOMOGRAFÍA ANTEBRAZO DERECHO CON CONTRASTE','health_diagnostics',null,10) where resolution_status='resolved'; if actual is distinct from ARRAY['82fb01ce-3677-55a5-8423-c216a1f8c3cf'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('ULTRASONIDO DOPPLER ARTERIAL BILATERAL DE MIEMBROS INFERIORES','health_diagnostics',null,10) where resolution_status='resolved'; if actual is distinct from ARRAY['864084d2-d69f-5e79-86eb-cf26f6f0734e'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6('ULTRASONIDO DOPPLER ARTERIAL BILATERAL MIEMBROS SUPERIORES','health_diagnostics',null,10) where resolution_status='resolved'; if actual is distinct from ARRAY['1ea42453-02e1-5236-9783-fc259ef5c147'::uuid]::uuid[] then raise exception 'Clinical release assertion failed'; end if; end $assert$;
insert into audit.events(actor_type,action,entity_schema,entity_table,before_data,after_data,request_id,metadata) select 'system','catalog.clinical_reconciliation_approved','catalog','clinical_resolver',payload,jsonb_build_object('services',(select jsonb_agg(to_jsonb(t)) from health.services t where catalog_item_id in ('a7496ee8-e33f-5bb7-a10a-9fea7975ed0e'::uuid,'11e0ac3a-e10e-5b21-99ec-ab557993664d'::uuid,'bef50d19-7f00-5057-9a3e-22d80b84cdba'::uuid,'4077cf47-4538-547a-a9d7-38f53aacf55f'::uuid,'224e7dcf-d6ff-54a2-9612-504ae9fca5e9'::uuid,'37bd6a75-04d4-57f7-9607-81aeef80755f'::uuid,'77b3d480-92ae-58e8-ac53-d97738b04394'::uuid,'faf3524d-76d3-5b37-8199-89e424f85e11'::uuid,'4dabc670-fd4f-565d-ac77-eb4e43c9d9c3'::uuid,'6280cf28-1d91-5ba0-8cf8-afef151b6105'::uuid,'d7bb634e-23b9-56e8-abd7-554af6d9ed36'::uuid,'c2322064-f938-5991-89f8-62d5452fb845'::uuid,'82fb01ce-3677-55a5-8423-c216a1f8c3cf'::uuid,'864084d2-d69f-5e79-86eb-cf26f6f0734e'::uuid,'1ea42453-02e1-5236-9783-fc259ef5c147'::uuid)),'lexicon',(select jsonb_agg(to_jsonb(t)) from health.query_lexicon t where id in ('6c6f85f6-9591-48e6-aa44-a2a9fbcc5ba5'::uuid,'bfd58a97-636b-411a-a25b-1c25037c61f1'::uuid,'0426f984-aefc-4ee1-b9b6-c4d1d2e353c9'::uuid)),'anatomy',(select jsonb_agg(to_jsonb(t)) from health.service_anatomy t where service_id in ('a7496ee8-e33f-5bb7-a10a-9fea7975ed0e'::uuid,'11e0ac3a-e10e-5b21-99ec-ab557993664d'::uuid,'bef50d19-7f00-5057-9a3e-22d80b84cdba'::uuid,'4077cf47-4538-547a-a9d7-38f53aacf55f'::uuid,'224e7dcf-d6ff-54a2-9612-504ae9fca5e9'::uuid,'37bd6a75-04d4-57f7-9607-81aeef80755f'::uuid,'77b3d480-92ae-58e8-ac53-d97738b04394'::uuid,'faf3524d-76d3-5b37-8199-89e424f85e11'::uuid,'4dabc670-fd4f-565d-ac77-eb4e43c9d9c3'::uuid,'6280cf28-1d91-5ba0-8cf8-afef151b6105'::uuid,'d7bb634e-23b9-56e8-abd7-554af6d9ed36'::uuid,'c2322064-f938-5991-89f8-62d5452fb845'::uuid,'82fb01ce-3677-55a5-8423-c216a1f8c3cf'::uuid,'864084d2-d69f-5e79-86eb-cf26f6f0734e'::uuid,'1ea42453-02e1-5236-9783-fc259ef5c147'::uuid))), 'canonical-reconciliation-20261023','{"approval": "23-Oct-2026: como van ya subieron todo al ambiente productivo recuerda q ahora local y produccion es lo mismo no hay tema tienes permiso; bounded to the described four-function canonical reconciliation, not the paused expansion.", "body_sha256": "89caed0eacd7ecc4b75f5e6ceef9dc896ec0f3d5c44cb918390b9d4dfe7531d1", "functions": ["resolve_items", "resolve_items_v3", "resolve_items_v4", "resolve_items_v6"], "backup": "collectors/artifacts/canonical-reconciliation-release-20261023-v1"}'::jsonb from reconciliation_before;
insert into supabase_migrations.schema_migrations(version,name,statements) values ('20261023160000','clinical_identity_canonical_reconciliation',ARRAY['do $guard$ begin
if md5(pg_get_functiondef(''catalog.resolve_items(text,text,uuid,integer)''::regprocedure)) <> ''067b7a2fe0826ccaa48ece0a5dfd8d1d'' then raise exception ''Function changed since preparation''; end if;
if md5(pg_get_functiondef(''catalog.resolve_items_v3(text,text,uuid,integer)''::regprocedure)) <> ''04a16e148fb6d3ee0838890818bdc6e9'' then raise exception ''Function changed since preparation''; end if;
if md5(pg_get_functiondef(''catalog.resolve_items_v4(text,text,uuid,integer)''::regprocedure)) <> ''21964858bf258a1b49e83e93f371cf01'' then raise exception ''Function changed since preparation''; end if;
if md5(pg_get_functiondef(''catalog.resolve_items_v6(text,text,uuid,integer)''::regprocedure)) <> ''62e3527a60897b7d01323e7bd83f3453'' then raise exception ''Function changed since preparation''; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id=''a7496ee8-e33f-5bb7-a10a-9fea7975ed0e''::uuid) is distinct from ''{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "a7496ee8-e33f-5bb7-a10a-9fea7975ed0e", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}''::jsonb then raise exception ''Reviewed row changed''; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id=''11e0ac3a-e10e-5b21-99ec-ab557993664d''::uuid) is distinct from ''{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "11e0ac3a-e10e-5b21-99ec-ab557993664d", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}''::jsonb then raise exception ''Reviewed row changed''; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id=''bef50d19-7f00-5057-9a3e-22d80b84cdba''::uuid) is distinct from ''{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "bef50d19-7f00-5057-9a3e-22d80b84cdba", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}''::jsonb then raise exception ''Reviewed row changed''; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id=''4077cf47-4538-547a-a9d7-38f53aacf55f''::uuid) is distinct from ''{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "4077cf47-4538-547a-a9d7-38f53aacf55f", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}''::jsonb then raise exception ''Reviewed row changed''; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id=''224e7dcf-d6ff-54a2-9612-504ae9fca5e9''::uuid) is distinct from ''{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "224e7dcf-d6ff-54a2-9612-504ae9fca5e9", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}''::jsonb then raise exception ''Reviewed row changed''; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id=''37bd6a75-04d4-57f7-9607-81aeef80755f''::uuid) is distinct from ''{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "37bd6a75-04d4-57f7-9607-81aeef80755f", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}''::jsonb then raise exception ''Reviewed row changed''; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id=''77b3d480-92ae-58e8-ac53-d97738b04394''::uuid) is distinct from ''{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "77b3d480-92ae-58e8-ac53-d97738b04394", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}''::jsonb then raise exception ''Reviewed row changed''; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id=''864084d2-d69f-5e79-86eb-cf26f6f0734e''::uuid) is distinct from ''{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "864084d2-d69f-5e79-86eb-cf26f6f0734e", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}''::jsonb then raise exception ''Reviewed row changed''; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id=''faf3524d-76d3-5b37-8199-89e424f85e11''::uuid) is distinct from ''{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "faf3524d-76d3-5b37-8199-89e424f85e11", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}''::jsonb then raise exception ''Reviewed row changed''; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id=''4dabc670-fd4f-565d-ac77-eb4e43c9d9c3''::uuid) is distinct from ''{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "4dabc670-fd4f-565d-ac77-eb4e43c9d9c3", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}''::jsonb then raise exception ''Reviewed row changed''; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id=''6280cf28-1d91-5ba0-8cf8-afef151b6105''::uuid) is distinct from ''{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "6280cf28-1d91-5ba0-8cf8-afef151b6105", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}''::jsonb then raise exception ''Reviewed row changed''; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id=''d7bb634e-23b9-56e8-abd7-554af6d9ed36''::uuid) is distinct from ''{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "d7bb634e-23b9-56e8-abd7-554af6d9ed36", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}''::jsonb then raise exception ''Reviewed row changed''; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id=''c2322064-f938-5991-89f8-62d5452fb845''::uuid) is distinct from ''{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "c2322064-f938-5991-89f8-62d5452fb845", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}''::jsonb then raise exception ''Reviewed row changed''; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id=''82fb01ce-3677-55a5-8423-c216a1f8c3cf''::uuid) is distinct from ''{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "82fb01ce-3677-55a5-8423-c216a1f8c3cf", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}''::jsonb then raise exception ''Reviewed row changed''; end if;
if (select to_jsonb(t) from health.services t where catalog_item_id=''1ea42453-02e1-5236-9783-fc259ef5c147''::uuid) is distinct from ''{"modality": null, "created_at": "2026-08-26T05:44:31.310029+00:00", "laterality": "not_applicable", "updated_at": "2026-08-28T05:23:00.561439+00:00", "service_type": "imaging", "contrast_mode": "not_applicable", "catalog_item_id": "1ea42453-02e1-5236-9783-fc259ef5c147", "default_requires_order": null, "clinical_equivalence_policy": "manual_if_ambiguous", "default_requires_appointment": null}''::jsonb then raise exception ''Reviewed row changed''; end if;
if (select to_jsonb(t) from health.query_lexicon t where id=''6c6f85f6-9591-48e6-aa44-a2a9fbcc5ba5''::uuid) is distinct from ''{"id": "6c6f85f6-9591-48e6-aa44-a2a9fbcc5ba5", "locale": "es-MX", "phrase": "T3 libre", "status": "approved", "created_at": "2026-08-29T06:54:50.935691+00:00", "source_note": "Resolver benchmark v1: free T3 must not resolve to the reviewed total T3 or free T4 item.", "attribute_type": "service_type", "attribute_value": "__blocked_analyte_variant__", "normalized_phrase": "t3 libre"}''::jsonb then raise exception ''Reviewed row changed''; end if;
if (select to_jsonb(t) from health.query_lexicon t where id=''bfd58a97-636b-411a-a25b-1c25037c61f1''::uuid) is distinct from ''{"id": "bfd58a97-636b-411a-a25b-1c25037c61f1", "locale": "es-MX", "phrase": "Triyodotironina libre", "status": "approved", "created_at": "2026-08-29T06:54:50.935691+00:00", "source_note": "Resolver benchmark v1: free T3 is not the reviewed total T3 mapping.", "attribute_type": "service_type", "attribute_value": "__blocked_analyte_variant__", "normalized_phrase": "triyodotironina libre"}''::jsonb then raise exception ''Reviewed row changed''; end if;
if (select to_jsonb(t) from health.query_lexicon t where id=''0426f984-aefc-4ee1-b9b6-c4d1d2e353c9''::uuid) is distinct from ''{"id": "0426f984-aefc-4ee1-b9b6-c4d1d2e353c9", "locale": "es-MX", "phrase": "Triiodotironina libre", "status": "approved", "created_at": "2026-08-29T06:54:50.935691+00:00", "source_note": "Resolver benchmark v1: free T3 is not the reviewed total T3 mapping.", "attribute_type": "service_type", "attribute_value": "__blocked_analyte_variant__", "normalized_phrase": "triiodotironina libre"}''::jsonb then raise exception ''Reviewed row changed''; end if;
if exists(select 1 from health.service_anatomy where service_id in (''c2322064-f938-5991-89f8-62d5452fb845''::uuid,''864084d2-d69f-5e79-86eb-cf26f6f0734e''::uuid,''1ea42453-02e1-5236-9783-fc259ef5c147''::uuid)) then raise exception ''Anatomy baseline changed''; end if; end $guard$;
do $$ begin update health.services set modality=''magnetic_resonance'',contrast_mode=''with'' where catalog_item_id=''a7496ee8-e33f-5bb7-a10a-9fea7975ed0e''::uuid and modality is not distinct from NULL and contrast_mode is not distinct from ''not_applicable''; if not found then raise exception ''Reviewed service attributes changed''; end if; end $$;
do $$ begin update health.services set modality=''magnetic_resonance'',contrast_mode=''with'' where catalog_item_id=''11e0ac3a-e10e-5b21-99ec-ab557993664d''::uuid and modality is not distinct from NULL and contrast_mode is not distinct from ''not_applicable''; if not found then raise exception ''Reviewed service attributes changed''; end if; end $$;
do $$ begin update health.services set modality=''magnetic_resonance'',contrast_mode=''with'',laterality=''right'' where catalog_item_id=''bef50d19-7f00-5057-9a3e-22d80b84cdba''::uuid and modality is not distinct from NULL and contrast_mode is not distinct from ''not_applicable'' and laterality is not distinct from ''not_applicable''; if not found then raise exception ''Reviewed service attributes changed''; end if; end $$;
do $$ begin update health.services set modality=''magnetic_resonance'',contrast_mode=''with'',laterality=''left'' where catalog_item_id=''4077cf47-4538-547a-a9d7-38f53aacf55f''::uuid and modality is not distinct from NULL and contrast_mode is not distinct from ''not_applicable'' and laterality is not distinct from ''not_applicable''; if not found then raise exception ''Reviewed service attributes changed''; end if; end $$;
do $$ begin update health.services set modality=''magnetic_resonance'',contrast_mode=''with'' where catalog_item_id=''224e7dcf-d6ff-54a2-9612-504ae9fca5e9''::uuid and modality is not distinct from NULL and contrast_mode is not distinct from ''not_applicable''; if not found then raise exception ''Reviewed service attributes changed''; end if; end $$;
do $$ begin update health.services set modality=''magnetic_resonance'',contrast_mode=''with'',laterality=''right'' where catalog_item_id=''37bd6a75-04d4-57f7-9607-81aeef80755f''::uuid and modality is not distinct from NULL and contrast_mode is not distinct from ''not_applicable'' and laterality is not distinct from ''not_applicable''; if not found then raise exception ''Reviewed service attributes changed''; end if; end $$;
do $$ begin update health.services set modality=''magnetic_resonance'',contrast_mode=''with'',laterality=''left'' where catalog_item_id=''77b3d480-92ae-58e8-ac53-d97738b04394''::uuid and modality is not distinct from NULL and contrast_mode is not distinct from ''not_applicable'' and laterality is not distinct from ''not_applicable''; if not found then raise exception ''Reviewed service attributes changed''; end if; end $$;
do $$ begin update health.services set modality=''magnetic_resonance'',contrast_mode=''with'',laterality=''right'' where catalog_item_id=''faf3524d-76d3-5b37-8199-89e424f85e11''::uuid and modality is not distinct from NULL and contrast_mode is not distinct from ''not_applicable'' and laterality is not distinct from ''not_applicable''; if not found then raise exception ''Reviewed service attributes changed''; end if; end $$;
do $$ begin update health.services set modality=''magnetic_resonance'',contrast_mode=''with'',laterality=''left'' where catalog_item_id=''4dabc670-fd4f-565d-ac77-eb4e43c9d9c3''::uuid and modality is not distinct from NULL and contrast_mode is not distinct from ''not_applicable'' and laterality is not distinct from ''not_applicable''; if not found then raise exception ''Reviewed service attributes changed''; end if; end $$;
do $$ begin update health.services set modality=''magnetic_resonance'',contrast_mode=''with'' where catalog_item_id=''6280cf28-1d91-5ba0-8cf8-afef151b6105''::uuid and modality is not distinct from NULL and contrast_mode is not distinct from ''not_applicable''; if not found then raise exception ''Reviewed service attributes changed''; end if; end $$;
do $$ begin update health.services set modality=''magnetic_resonance'',contrast_mode=''with'' where catalog_item_id=''d7bb634e-23b9-56e8-abd7-554af6d9ed36''::uuid and modality is not distinct from NULL and contrast_mode is not distinct from ''not_applicable''; if not found then raise exception ''Reviewed service attributes changed''; end if; end $$;
do $$ begin update health.services set modality=''tomography'' where catalog_item_id=''c2322064-f938-5991-89f8-62d5452fb845''::uuid and modality is not distinct from NULL; if not found then raise exception ''Reviewed service attributes changed''; end if; end $$;
insert into health.service_anatomy(service_id,anatomical_site_id,role,laterality_override,created_at) values (''c2322064-f938-5991-89f8-62d5452fb845''::uuid,''fc59e391-f865-4a8e-aa63-93b1c66f2b01''::uuid,''target'',NULL,now());
do $$ begin update health.services set modality=''tomography'',contrast_mode=''with'',laterality=''right'' where catalog_item_id=''82fb01ce-3677-55a5-8423-c216a1f8c3cf''::uuid and modality is not distinct from NULL and contrast_mode is not distinct from ''not_applicable'' and laterality is not distinct from ''not_applicable''; if not found then raise exception ''Reviewed service attributes changed''; end if; end $$;
do $$ begin update health.services set modality=''ultrasound'',laterality=''bilateral'' where catalog_item_id=''864084d2-d69f-5e79-86eb-cf26f6f0734e''::uuid and modality is not distinct from NULL and laterality is not distinct from ''not_applicable''; if not found then raise exception ''Reviewed service attributes changed''; end if; end $$;
insert into health.service_anatomy(service_id,anatomical_site_id,role,laterality_override,created_at) values (''864084d2-d69f-5e79-86eb-cf26f6f0734e''::uuid,''fc59e391-f865-4a8e-aa63-93b1c66f2b01''::uuid,''target'',NULL,now());
do $$ begin update health.services set modality=''ultrasound'',laterality=''bilateral'' where catalog_item_id=''1ea42453-02e1-5236-9783-fc259ef5c147''::uuid and modality is not distinct from NULL and laterality is not distinct from ''not_applicable''; if not found then raise exception ''Reviewed service attributes changed''; end if; end $$;
insert into health.service_anatomy(service_id,anatomical_site_id,role,laterality_override,created_at) values (''1ea42453-02e1-5236-9783-fc259ef5c147''::uuid,''b2850360-bdaf-404a-b219-964aa530814b''::uuid,''target'',NULL,now());
CREATE OR REPLACE FUNCTION catalog.resolve_items(p_query text, p_domain_code text DEFAULT ''health_diagnostics''::text, p_provider_brand_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 10)
 RETURNS TABLE(item_id uuid, display_name text, matched_term text, term_source text, provider_brand_id uuid, confidence numeric, resolution_status text, match_method text, explanation_data jsonb, result_rank bigint)
 LANGUAGE sql
 STABLE PARALLEL SAFE
 SET search_path TO ''pg_catalog''
AS $function$
with q as (
  select core.normalized_text(p_query) as normalized_query
), qattrs as (
  select distinct l.attribute_type, l.attribute_value
  from health.query_lexicon l
  cross join q
  where l.status = ''approved''
    and q.normalized_query like ''%'' || l.normalized_phrase || ''%''
), disambiguation as (
  select distinct t.id as term_id, t.normalized_term
  from catalog.disambiguation_terms t
  cross join q
  where t.status = ''approved''
    and (q.normalized_query = t.normalized_term
      or extensions.word_similarity(t.normalized_term, q.normalized_query) >= 0.70)
), terms as (
  select n.item_id, n.locale, n.name as term, n.normalized_name as normalized_term,
         ''name''::text as term_source, null::uuid as provider_brand_id,
         case when n.is_primary then 1.00::numeric else 0.98::numeric end as weight
  from catalog.item_names n
  join catalog.items i on i.id = n.item_id and i.status = ''active''
  join catalog.domains d on d.id = i.domain_id and d.code = p_domain_code
  union all
  select a.item_id, a.locale, a.alias, a.normalized_alias, ''alias''::text,
         a.provider_brand_id, a.confidence
  from catalog.item_aliases a
  join catalog.items i on i.id = a.item_id and i.status = ''active''
  join catalog.domains d on d.id = i.domain_id and d.code = p_domain_code
  where a.status = ''approved''
    and (a.provider_brand_id is null or a.provider_brand_id = p_provider_brand_id)
  union all
  select d.item_id, d.locale, d.description, d.normalized_description, ''description''::text,
         null::uuid, 0.90::numeric
  from catalog.item_descriptions d
  join catalog.items i on i.id = d.item_id and i.status = ''active''
  join catalog.domains dm on dm.id = i.domain_id and dm.code = p_domain_code
  where d.status = ''approved''
  union all
  select dc.item_id, t.locale, t.term, t.normalized_term, ''disambiguation''::text,
         null::uuid, 0.90::numeric
  from disambiguation dx
  join catalog.disambiguation_terms t on t.id = dx.term_id
  join catalog.disambiguation_candidates dc on dc.term_id = t.id
  join catalog.items i on i.id = dc.item_id and i.status = ''active''
), scored as (
  select
    t.item_id,
    coalesce((select n.name from catalog.item_names n where n.item_id = t.item_id and n.is_primary order by n.locale = ''es-MX'' desc limit 1), t.term) as display_name,
    t.term as matched_term,
    t.term_source,
    t.provider_brand_id,
    extensions.similarity(t.normalized_term, q.normalized_query)::numeric as similarity_score,
    extensions.word_similarity(t.normalized_term, q.normalized_query)::numeric as word_score,
    case when t.normalized_term = q.normalized_query then 1.00::numeric
         when t.term_source = ''disambiguation'' then 0.92::numeric
         when q.normalized_query like ''%'' || t.normalized_term || ''%'' then 0.88::numeric
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
  where q.normalized_query <> ''''
    and (t.normalized_term = q.normalized_query
      or t.term_source = ''disambiguation''
      or q.normalized_query like ''%'' || t.normalized_term || ''%''
      or t.normalized_term like ''%'' || q.normalized_query || ''%''
      or extensions.similarity(t.normalized_term, q.normalized_query) >= 0.35
      or extensions.word_similarity(t.normalized_term, q.normalized_query) >= 0.45)
), best as (
  select * from scored where term_rank = 1
), enriched as (
  select
    b.*,
    coalesce((select count(*) from qattrs),0)::integer as attribute_count,
    coalesce((select count(*) from qattrs qa where
      (qa.attribute_type = ''service_type'' and exists (
        select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.service_type = qa.attribute_value
      )) or (qa.attribute_type = ''component'' and exists (
        select 1 from health.lab_service_definitions ld where ld.service_id = b.item_id and ld.component = qa.attribute_value
      )) or (qa.attribute_type = ''method'' and exists (
        select 1 from health.service_methods sm where sm.service_id = b.item_id and sm.status = ''approved'' and sm.method_code = qa.attribute_value
      )) or (qa.attribute_type = ''modality'' and exists (
        select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.modality = qa.attribute_value
      )) or (qa.attribute_type = ''anatomical_site'' and exists (
        select 1 from health.service_anatomy sa join health.anatomical_sites an on an.id = sa.anatomical_site_id where sa.service_id = b.item_id and an.code = qa.attribute_value
      )) or (qa.attribute_type = ''laterality'' and exists (
        select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.laterality = qa.attribute_value
      )) or (qa.attribute_type = ''contrast_mode'' and exists (
        select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.contrast_mode = qa.attribute_value
      )) or (qa.attribute_type = ''specimen'' and exists (
        select 1 from health.service_specimens ss join health.specimen_types sp on sp.id = ss.specimen_type_id where ss.service_id = b.item_id and (sp.code = qa.attribute_value or sp.normalized_name = qa.attribute_value)
      ))
    ),0)::integer as attribute_matches,
    exists (select 1 from qattrs qa where
      (qa.attribute_type = ''service_type'' and not exists (select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.service_type = qa.attribute_value))
      or (qa.attribute_type = ''component'' and not exists (select 1 from health.lab_service_definitions ld where ld.service_id = b.item_id and ld.component = qa.attribute_value))
      or (qa.attribute_type = ''method'' and not exists (select 1 from health.service_methods sm where sm.service_id = b.item_id and sm.status = ''approved'' and sm.method_code = qa.attribute_value))
      or (qa.attribute_type = ''modality'' and not exists (select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.modality = qa.attribute_value))
      or (qa.attribute_type = ''anatomical_site'' and not exists (select 1 from health.service_anatomy sa join health.anatomical_sites an on an.id = sa.anatomical_site_id where sa.service_id = b.item_id and an.code = qa.attribute_value))
      or (qa.attribute_type = ''laterality'' and not exists (select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.laterality = qa.attribute_value))
      or (qa.attribute_type = ''contrast_mode'' and not exists (select 1 from health.services hs where hs.catalog_item_id = b.item_id and hs.contrast_mode = qa.attribute_value))
    ) as hard_conflict
  from best b
), accepted as (
  select e.*,
    least(1.00::numeric, greatest(e.lexical_score, 0) + case when e.attribute_count = 0 then 0 else e.attribute_matches::numeric / e.attribute_count::numeric * 0.12 end) as final_score
  from enriched e
  where not e.hard_conflict
    and (e.lexical_score >= 0.45 or e.term_source in (''name'',''alias'',''disambiguation''))
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
       then ''ambiguous'' else ''resolved'' end as resolution_status,
  case when r.term_source = ''disambiguation'' then ''disambiguation''
       when r.lexical_score >= 0.999 then ''exact''
       when r.term_source = ''alias'' then ''alias''
       when r.word_score >= r.similarity_score then ''word_fuzzy''
       else ''trigram'' end as match_method,
  jsonb_build_object(
    ''lexical_score'', r.lexical_score,
    ''similarity_score'', r.similarity_score,
    ''word_score'', r.word_score,
    ''attribute_count'', r.attribute_count,
    ''attribute_matches'', r.attribute_matches,
    ''hard_conflict'', r.hard_conflict,
    ''next_score'', r.next_score
  ) as explanation_data
  ,r.result_rank
from ranked r
where r.result_rank <= greatest(1, least(coalesce(p_limit,10),50))
order by r.result_rank;
$function$;
update health.query_lexicon set attribute_type=''component'',attribute_value=''Triiodothyronine.free'' where id in (''6c6f85f6-9591-48e6-aa44-a2a9fbcc5ba5''::uuid,''bfd58a97-636b-411a-a25b-1c25037c61f1''::uuid,''0426f984-aefc-4ee1-b9b6-c4d1d2e353c9''::uuid);
CREATE OR REPLACE FUNCTION catalog.resolve_items_v3(p_query text, p_domain_code text DEFAULT ''health_diagnostics''::text, p_provider_brand_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 10)
 RETURNS TABLE(item_id uuid, display_name text, matched_term text, term_source text, provider_brand_id uuid, confidence numeric, resolution_status text, match_method text, explanation_data jsonb, result_rank bigint)
 LANGUAGE sql
 STABLE PARALLEL SAFE
 SET search_path TO ''pg_catalog''
AS $function$
with q as (
  select core.normalized_text(p_query) as normalized_query
), candidates as materialized (
  select r.*
  from catalog.resolve_items_v2(p_query, p_domain_code, p_provider_brand_id, greatest(50, coalesce(p_limit,10) * 4)) r
), guarded as (
  select c.*,
    (
      select count(*)
      from unnest(string_to_array(q.normalized_query, '' '')) as qt(token)
      where length(qt.token) >= 4
        and qt.token not in (''para'',''como'',''desde'',''entre'',''sobre'',''este'',''esta'',''estos'',''estas'',''con'',''sin'',''del'',''las'',''los'',''una'',''uno'',''por'',''que'',''sus'',''en'',''de'',''el'',''la'',''y'')
        and exists (
          select 1
          from unnest(string_to_array(core.normalized_text(c.matched_term), '' '')) as mt(token)
          where mt.token = qt.token
             or mt.token like qt.token || ''%''
             or qt.token like mt.token || ''%''
             or extensions.word_similarity(mt.token, qt.token) >= 0.80
        )
    )::integer as meaningful_token_matches,
    (
      select count(*)
      from unnest(string_to_array(q.normalized_query, '' '')) as qt(token)
      where length(qt.token) >= 4
        and qt.token not in (''para'',''como'',''desde'',''entre'',''sobre'',''este'',''esta'',''estos'',''estas'',''con'',''sin'',''del'',''las'',''los'',''una'',''uno'',''por'',''que'',''sus'',''en'',''de'',''el'',''la'',''y'')
    )::integer as meaningful_token_count
  from candidates c
  cross join q
), lexical_accepted as materialized (
  select g.*
  from guarded g
  where g.match_method in (''exact'',''alias'',''disambiguation'')
     or (g.meaningful_token_count > 0 and g.meaningful_token_matches = g.meaningful_token_count)
), requirement_checked as materialized (
  select a.*,
    not exists (
      select 1
      from unnest(string_to_array(core.normalized_text(p_query), '' '')) as qt(token)
      where qt.token <> ''''
        and qt.token not in (''de'',''del'',''el'',''la'',''los'',''las'',''en'')
        and not (qt.token = any(string_to_array(core.normalized_text(a.matched_term), '' '')))
    ) as literal_requirements_present,
    (a.term_source in (''name'',''alias'') and a.match_method in (''exact'',''alias'')
      and a.confidence = 1
      and core.normalized_text(a.matched_term)=core.normalized_text(p_query)) as exact_identity_literal,
    (core.normalized_text(p_query) ~ ''^[a-z]{4,40}$''
      and not (core.normalized_text(p_query) = any(string_to_array(core.normalized_text(a.matched_term),'' '')))
      and exists(select 1 from unnest(string_to_array(core.normalized_text(a.matched_term),'' '')) mt(token)
                 where mt.token like core.normalized_text(p_query)||''%'')) as prefix_discovery
  from lexical_accepted a
), accepted as (
  select a.*,
    (not a.exact_identity_literal and exists (select 1 from requirement_checked x where not x.literal_requirements_present)) as requirements_pruned
  from requirement_checked a
  where a.literal_requirements_present or a.prefix_discovery
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
  case when r.prefix_discovery or r.requirements_pruned or r.candidate_count > 1 then ''ambiguous'' else r.resolution_status end as resolution_status,
  r.match_method,
  r.explanation_data || jsonb_build_object(
    ''meaningful_token_matches'', r.meaningful_token_matches,
    ''meaningful_token_count'', r.meaningful_token_count,
    ''literal_requirements_present'', r.literal_requirements_present,
    ''requirements_pruned'', r.requirements_pruned,
    ''prefix_discovery'', r.prefix_discovery,
    ''exact_identity_literal'', r.exact_identity_literal,
    ''requirements_policy'', ''literal-content-v2-LOCAL-EXPERIMENT''
  ) as explanation_data,
  r.safe_rank as result_rank
from ranked r
where r.safe_rank <= greatest(1, least(coalesce(p_limit,10),50))
order by r.safe_rank;
$function$;
CREATE OR REPLACE FUNCTION catalog.resolve_items_v4(p_query text, p_domain_code text DEFAULT ''health_diagnostics''::text, p_provider_brand_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 10)
 RETURNS TABLE(item_id uuid, display_name text, matched_term text, term_source text, provider_brand_id uuid, confidence numeric, resolution_status text, match_method text, explanation_data jsonb, result_rank bigint)
 LANGUAGE sql
 STABLE PARALLEL SAFE
 SET search_path TO ''pg_catalog''
AS $function$
with rows as materialized (
  select * from catalog.resolve_items_v3(p_query, p_domain_code, p_provider_brand_id, p_limit)
), ranked as (
  select rows.*, count(*) over () as safe_count
  from rows
)
select r.item_id, r.display_name, r.matched_term, r.term_source,
       r.provider_brand_id, r.confidence,
       case when not coalesce((r.explanation_data->>''exact_identity_literal'')::boolean,false)
                 or coalesce((r.explanation_data->>''requirements_pruned'')::boolean,false)
                 or coalesce((r.explanation_data->>''prefix_discovery'')::boolean,false)
                 or r.safe_count > 1 or r.term_source = ''disambiguation'' then ''ambiguous'' else ''resolved'' end,
       r.match_method,
       r.explanation_data || jsonb_build_object(''automatic_identity_policy'',''exact-reviewed-identity-only-LOCAL''),
       r.result_rank
from ranked r
order by r.result_rank;
$function$;
CREATE OR REPLACE FUNCTION catalog.resolve_items_v6(p_query text, p_domain_code text DEFAULT ''health_diagnostics''::text, p_provider_brand_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 10)
 RETURNS TABLE(item_id uuid, display_name text, matched_term text, term_source text, provider_brand_id uuid, confidence numeric, resolution_status text, match_method text, explanation_data jsonb, result_rank bigint)
 LANGUAGE sql
 STABLE PARALLEL SAFE
 SET search_path TO ''pg_catalog''
AS $function$
with identifier_candidates as materialized (
  select
    i.id as item_id,
    coalesce((
      select n.name
      from catalog.item_names n
      where n.item_id = i.id and n.is_primary
      order by n.created_at desc
      limit 1
    ), i.id::text) as display_name,
    ii.code as matched_term,
    ''loinc''::text as term_source,
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
  where lower(trim(ii.system)) = ''http://loinc.org''
    and lower(trim(ii.code)) = lower(trim(coalesce(p_query, '''')))
    and ii.mapping_type = ''exact''
    and ii.status = ''active''
    and ii.verified = true
    and ii.approved_at is not null
    and i.status = ''active''
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
), fallback_raw as materialized (
  select r.*
  from catalog.resolve_items_v5(
    p_query,
    p_domain_code,
    p_provider_brand_id,
    greatest(1, least(coalesce(p_limit, 10), 50))
  ) r
), exact_items as materialized (
  select distinct item_id
  from fallback_raw
  where match_method = ''exact''
), fallback_filtered as materialized (
  select r.*
  from fallback_raw r
  where not exists (select 1 from exact_items)
     or r.item_id in (select e.item_id from exact_items e)
), fallback_ranked as (
  select
    f.*,
    count(*) over () as filtered_count,
    count(*) filter (where f.match_method = ''exact'') over () as filtered_exact_count,
    row_number() over (order by f.confidence desc, f.display_name) as filtered_rank,
    lead(f.confidence) over (order by f.confidence desc, f.display_name) as next_filtered_confidence
  from fallback_filtered f
)
select
  m.item_id,
  m.display_name,
  m.matched_term,
  m.term_source,
  m.provider_brand_id,
  m.confidence,
  case when m.candidate_count > 1 then ''ambiguous'' else ''resolved'' end,
  ''loinc_exact''::text,
  jsonb_build_object(
    ''terminology'', ''LOINC'',
    ''code'', m.code,
    ''version'', m.version,
    ''mapping_type'', m.mapping_type
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
  case
    when coalesce((f.explanation_data->>''requirements_pruned'')::boolean,false) then ''ambiguous''
    when f.filtered_exact_count > 1 then ''ambiguous''
    when f.filtered_exact_count = 1 then ''resolved''
    else f.resolution_status
  end,
  f.match_method,
  f.explanation_data || jsonb_build_object(
    ''exact_dominance'', f.filtered_exact_count = 1,
    ''candidate_count_after_exact_filter'', f.filtered_count
  ),
  f.filtered_rank
from fallback_ranked f
where not exists (select 1 from identifier_matches)
  and f.filtered_rank <= greatest(1, least(coalesce(p_limit, 10), 50))
order by result_rank
limit greatest(1, least(coalesce(p_limit, 10), 50));
$function$;
']);
commit;
