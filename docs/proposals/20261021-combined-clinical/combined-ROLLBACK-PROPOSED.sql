-- ISOLATED D-006 DRAFT. NEVER SUBMITTED. NO EXECUTOR OR APPROVAL.
-- Registry empty; no aliases, concepts, offers or crawler decisions approved.
begin;
set local lock_timeout='250ms';
set local statement_timeout='10s';
set local idle_in_transaction_session_timeout='15s';
do $baseline_guard$ begin
 if exists(select 1 from jsonb_array_elements('[{"schema": "catalog", "name": "resolve_items", "arguments": "p_query text, p_domain_code text, p_provider_brand_id uuid, p_limit integer", "definition_md5": "067b7a2fe0826ccaa48ece0a5dfd8d1d", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "catalog.resolve_items"}, {"schema": "catalog", "name": "resolve_items_v2", "arguments": "p_query text, p_domain_code text, p_provider_brand_id uuid, p_limit integer", "definition_md5": "7b0be9fb9a16bebd289e5e9b3ed71f05", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "catalog.resolve_items_v2"}, {"schema": "catalog", "name": "resolve_items_v3", "arguments": "p_query text, p_domain_code text, p_provider_brand_id uuid, p_limit integer", "definition_md5": "04a16e148fb6d3ee0838890818bdc6e9", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "catalog.resolve_items_v3"}, {"schema": "catalog", "name": "resolve_items_v4", "arguments": "p_query text, p_domain_code text, p_provider_brand_id uuid, p_limit integer", "definition_md5": "21964858bf258a1b49e83e93f371cf01", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "catalog.resolve_items_v4"}, {"schema": "catalog", "name": "resolve_items_v5", "arguments": "p_query text, p_domain_code text, p_provider_brand_id uuid, p_limit integer", "definition_md5": "32830b96541e6d803749987455572e9a", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "catalog.resolve_items_v5"}, {"schema": "catalog", "name": "resolve_items_v6", "arguments": "p_query text, p_domain_code text, p_provider_brand_id uuid, p_limit integer", "definition_md5": "62e3527a60897b7d01323e7bd83f3453", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "catalog.resolve_items_v6"}, {"schema": "catalog", "name": "search_items", "arguments": "p_query text, p_domain_code text, p_provider_brand_id uuid, p_limit integer", "definition_md5": "b3a7f87d485dc5a5a711e2b664c7a720", "acl": "{postgres=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "catalog.search_items"}, {"schema": "core", "name": "normalized_text", "arguments": "input text", "definition_md5": "316b789d77ac228427fc69104e65f83e", "acl": "{postgres=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "core.normalized_text"}, {"schema": "public", "name": "api_provider_detail", "arguments": "p_provider_brand_id uuid", "definition_md5": "488896bedef266484aff707065a55815", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, core, catalog, supply, gis"], "full_name": "public.api_provider_detail"}, {"schema": "public", "name": "api_resolve_ocr_package", "arguments": "p_items jsonb, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "99f775a4411bfde5a71b23f7cb26f094", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, core, supply, geo, gis, extensions"], "full_name": "public.api_resolve_ocr_package"}, {"schema": "public", "name": "api_resolve_ocr_package_internal", "arguments": "p_items jsonb, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "a4fb23e946b4b3b9aa079ffb1ad60b3c", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, core, supply, geo, gis, extensions"], "full_name": "public.api_resolve_ocr_package_internal"}, {"schema": "public", "name": "api_resolve_package", "arguments": "p_items jsonb, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "930f9943ec8deeb2eb26d1b23377bf21", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, core, supply, geo, gis, extensions"], "full_name": "public.api_resolve_package"}, {"schema": "public", "name": "api_resolve_package_internal", "arguments": "p_items jsonb, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "d009d7d8185bcbdd33d259cd6e46560e", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, supply"], "full_name": "public.api_resolve_package_internal"}, {"schema": "public", "name": "api_resolve_package_links_legacy", "arguments": "p_items jsonb, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "a08145ff11e793982e335058c88060f1", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, core, supply, geo, gis, extensions"], "full_name": "public.api_resolve_package_links_legacy"}, {"schema": "public", "name": "api_resolve_package_unfiltered", "arguments": "p_items jsonb, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "bc2f82070699884ff65c703cb967587a", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, core, supply, geo, gis, extensions"], "full_name": "public.api_resolve_package_unfiltered"}, {"schema": "public", "name": "api_resolve_search", "arguments": "p_query text, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "89d6a3efb3e43daa736d947eca7406fe", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, core, supply, geo, gis, extensions"], "full_name": "public.api_resolve_search"}, {"schema": "public", "name": "api_resolve_search_unfiltered", "arguments": "p_query text, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "0f1756738cad4540cf9835597dae8e3c", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public"], "full_name": "public.api_resolve_search_unfiltered"}, {"schema": "public", "name": "api_resolve_search_v2", "arguments": "p_query text, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "52efd4b565a02daebc8b40660e440db1", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, health, core, supply, geo, gis, extensions"], "full_name": "public.api_resolve_search_v2"}, {"schema": "public", "name": "api_resolve_search_v3", "arguments": "p_query text, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "32fcc4566f9ceaf9a2b360f45aa5c225", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public"], "full_name": "public.api_resolve_search_v3"}, {"schema": "public", "name": "api_resolve_search_v4", "arguments": "p_query text, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "eb2a8f5d7ea847ae74892fb8210eaf2c", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, supply, core"], "full_name": "public.api_resolve_search_v4"}, {"schema": "public", "name": "api_resolve_search_v4_links_legacy", "arguments": "p_query text, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "d831c25cf7024a846af2955a7a3c3e1a", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public"], "full_name": "public.api_resolve_search_v4_links_legacy"}, {"schema": "public", "name": "api_search", "arguments": "p_query text, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "74eef2e92ac940191921071f776aae60", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, supply"], "full_name": "public.api_search"}, {"schema": "public", "name": "api_search_links_legacy_v1", "arguments": "p_query text, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "5ee173805303c231132deb9fb96fdb54", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, core, supply, geo, gis, extensions"], "full_name": "public.api_search_links_legacy_v1"}, {"schema": "public", "name": "api_search_scoped_v1", "arguments": "p_query text, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "b0bdd0cfcb3c0d8b2bc717f24b615d40", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, core, supply, geo, gis, extensions"], "full_name": "public.api_search_scoped_v1"}, {"schema": "public", "name": "api_service_detail", "arguments": "p_service_id uuid", "definition_md5": "9720e801b6c0c9cad8c0f265ceef73e6", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, health, supply, core"], "full_name": "public.api_service_detail"}, {"schema": "public", "name": "apply_package_confidence_guard", "arguments": "p_payload jsonb", "definition_md5": "cbbf64d963a748ac293630c8615b1da0", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "public.apply_package_confidence_guard"}, {"schema": "public", "name": "apply_resolution_confidence_guard", "arguments": "p_payload jsonb", "definition_md5": "62a030588affbee2f92dfc566687ec7a", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "public.apply_resolution_confidence_guard"}]'::jsonb) r(value)
 where not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname=r.value->>'schema' and p.proname=r.value->>'name'
 and pg_get_function_identity_arguments(p.oid)=r.value->>'arguments'
 and (p.proacl is null)=((r.value->>'acl') is null)
 and array(select a::text from unnest(p.proacl) a order by a::text)
   =array(select a::text from unnest((r.value->>'acl')::aclitem[]) a order by a::text)
 and pg_get_userbyid(p.proowner)=r.value->>'owner'
 and p.prosecdef=(r.value->>'security_definer')::boolean
 and coalesce(to_jsonb(p.proconfig),'null'::jsonb)=r.value->'configuration' and md5(pg_get_functiondef(p.oid))=r.value->>'definition_md5')) then raise exception 'Combined draft baseline or permissions changed'; end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where (n.nspname='catalog' and p.proname='resolve_items_v6_before_panels') or (n.nspname='catalog' and p.proname='resolve_items_v7') or (n.nspname='health' and p.proname='assert_rx_protocol_integrity') or (n.nspname='health' and p.proname='check_rx_protocol_integrity') or (n.nspname='health' and p.proname='panel_current_state') or (n.nspname='health' and p.proname='panel_query_is_compatible') or (n.nspname='health' and p.proname='parse_rx_chest_request') or (n.nspname='health' and p.proname='preserve_panel_audit_anchor') or (n.nspname='health' and p.proname='preserve_rx_protocol_review') or (n.nspname='health' and p.proname='prevent_panel_manifest_mutation') or (n.nspname='health' and p.proname='prevent_rx_protocol_truncate') or (n.nspname='health' and p.proname='rx_protocol_definition') or (n.nspname='health' and p.proname='rx_protocol_gate') or (n.nspname='health' and p.proname='validate_imaging_protocol_service') or (n.nspname='health' and p.proname='validate_panel_manifest_insert') or (n.nspname='health' and p.proname='validate_panel_quarantine_insert') or (n.nspname='public' and p.proname='api_resolve_rx_chest_package_pilot_v2') or (n.nspname='public' and p.proname='api_resolve_rx_chest_pilot') or (n.nspname='public' and p.proname='api_search_before_panels')) then raise exception 'Proposed function name already exists'; end if;
 if to_regclass('health.imaging_protocols') is not null then raise exception 'Proposed table already exists'; end if;
 if to_regclass('health.imaging_protocol_views') is not null then raise exception 'Proposed table already exists'; end if;
 if to_regclass('health.reviewed_panel_compositions') is not null then raise exception 'Proposed table already exists'; end if;
 if to_regclass('health.panel_composition_quarantines') is not null then raise exception 'Proposed table already exists'; end if;
end $baseline_guard$;

-- SECTION image_schema
-- PROPOSAL ONLY. NOT EXECUTED. Requires D-006 review before a new migration.
-- Additive schema and opt-in RPC; no replacement of current public functions.

set local lock_timeout='5s';
set local statement_timeout='30s';

create table health.imaging_protocols (
 service_id uuid primary key references health.services(catalog_item_id) on delete restrict,
 contract_version integer not null check(contract_version=1),
 acquisition_variant text not null check(acquisition_variant in ('radiography','teleradiography','unspecified')),
 projection_set_complete boolean not null,
 view_count integer check(view_count between 1 and 50),
 patient_posture text check(patient_posture in ('upright','decubitus_unspecified','supine','prone','lateral_decubitus')),
 comparative boolean,
 source_review_id text not null,
 source_contract_sha256 text not null check(source_contract_sha256 ~ '^[a-f0-9]{64}$'),
 created_at timestamptz not null default now()
);
create table health.imaging_protocol_views (
 service_id uuid not null references health.imaging_protocols(service_id) on delete restrict,
 ordinal integer not null check(ordinal between 1 and 50),
 projection_code text not null check(projection_code in ('AP','PA','lateral','oblique','axial','tangential','unspecified')),
 projection_side text check(projection_side in ('left','right')),
 patient_posture text check(patient_posture in ('upright','decubitus_unspecified','supine','prone','lateral_decubitus')),
 angle_degrees numeric check(angle_degrees between 0 and 360),
 primary key(service_id,ordinal)
);
-- A projection is distinct from anatomical laterality; ordinal preserves an
-- explicitly ordered series. NULL count never becomes array length.
create function health.validate_imaging_protocol_service() returns trigger
language plpgsql set search_path=pg_catalog as $$
begin
 if not exists(select 1 from health.services s where s.catalog_item_id=new.service_id
  and s.service_type='imaging' and s.modality='radiography')
 then raise exception 'RX protocol requires an explicit radiography service'; end if;
 return new;
end $$;
create trigger imaging_protocol_service_guard before insert or update
on health.imaging_protocols for each row execute function health.validate_imaging_protocol_service();
alter table health.imaging_protocols enable row level security;
alter table health.imaging_protocol_views enable row level security;
revoke all on health.imaging_protocols,health.imaging_protocol_views from public,anon,authenticated;
grant select,insert,update,delete on health.imaging_protocols,health.imaging_protocol_views to service_role;

-- Bounded chest pilot parser; deliberately does not interpret other anatomy.
-- Unmodeled qualifiers force clarification rather than an inferred protocol.
create function health.parse_rx_chest_request(p_query text) returns jsonb
language sql immutable parallel safe set search_path=pg_catalog as $$
with q as(select core.normalized_text(p_query) t), tokens as(
 select t,regexp_split_to_array(t,' +') words from q
), parsed as(
 select t,
  case when t ~ '\mteleradiografia\M' then 'teleradiography'
   when t ~ '\m(rx|radiografia|rayos x)\M' then 'radiography'
   else 'unspecified' end variant,
  array(select distinct p from unnest(array[
   case when t ~ '\m(pa|postero anterior|posteroanterior)\M' then 'PA' end,
   case when t ~ '\m(ap|antero posterior|anteroposterior)\M' then 'AP' end,
   case when t ~ '\m(lat|lateral)\M' then 'lateral' end
  ]) p where p is not null order by p) projections,
  case when t ~ '\m(1|una) proyeccion\M' then 1
   when t ~ '\m(2|dos) proyecciones\M' then 2 end view_count,
  case when t ~ '\m(bipedestacion|de pie)\M' then 'upright'
   when t ~ '\mdecubito\M' then 'decubitus_unspecified' end posture,
  exists(select 1 from unnest(words) w where w not in (
   'teleradiografia','radiografia','rx','rayos','x','torax','de','del','el','en','y',
   'pa','ap','postero','anterior','posteroanterior','antero','posterior','anteroposterior',
   'lat','lateral','1','una','proyeccion','2','dos','proyecciones','bipedestacion','pie','decubito'
  )) unmodeled
 from tokens
)
select jsonb_build_object('scope',t ~ '\mtorax\M' and t !~ '\m(tc|rm|tac|resonancia|tomografia|ultrasonido)\M',
 'variant',variant,'projections',to_jsonb(projections),'view_count',view_count,
 'posture',posture,'unmodeled',unmodeled) from parsed;
$$;

-- Preserve confidence guard and all existing scoring. This decorator can only
-- remove/downgrade candidates; it never adds or upgrades a v6-derived result.
create function public.api_resolve_rx_chest_pilot(
 p_query text,p_domain_code text default 'health_diagnostics',
 p_latitude double precision default null,p_longitude double precision default null,
 p_location_id uuid default null,p_limit integer default 20
) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare
 source jsonb; request jsonb; candidate jsonb; kept jsonb='[]'::jsonb;
 protocol record; candidate_projections text[]; requested_projections text[];
 needs_clarification boolean; any_ambiguous boolean=false; result_status text;
begin
 source:=public.api_resolve_search(p_query,p_domain_code,p_latitude,p_longitude,p_location_id,p_limit);
 request:=health.parse_rx_chest_request(p_query);
 if not coalesce((request->>'scope')::boolean,false) then return source; end if;
 requested_projections:=array(select jsonb_array_elements_text(request->'projections'));
 for candidate in select value from jsonb_array_elements(coalesce(source->'candidates','[]'::jsonb)) loop
  select p.* into protocol from health.imaging_protocols p
   join health.services s on s.catalog_item_id=p.service_id and s.service_type='imaging' and s.modality='radiography'
   where p.service_id=(candidate->>'service_id')::uuid
    and exists(select 1 from health.service_anatomy a join health.anatomical_sites n on n.id=a.anatomical_site_id
     where a.service_id=p.service_id and a.role='target' and n.code='chest' and n.status='active');
  if not found then continue; end if;
  candidate_projections:=array(select distinct v.projection_code from health.imaging_protocol_views v
   where v.service_id=protocol.service_id order by v.projection_code);
  if cardinality(candidate_projections)=0 then continue; end if;
  if cardinality(requested_projections)>0 and requested_projections<>candidate_projections then continue; end if;
  if request->>'variant'<>'unspecified' and request->>'variant'<>protocol.acquisition_variant then continue; end if;
  if request->>'view_count' is not null and (request->>'view_count')::int is distinct from protocol.view_count then continue; end if;
  if request->>'posture' is not null and request->>'posture' is distinct from protocol.patient_posture then continue; end if;
  needs_clarification:=not protocol.projection_set_complete or cardinality(requested_projections)=0
   or request->>'variant'='unspecified' or coalesce((request->>'unmodeled')::boolean,true)
   or candidate->>'resolution_status'<>'resolved' or source->>'status'<>'resolved';
  if needs_clarification then
   candidate:=candidate || jsonb_build_object('resolution_status','ambiguous','offers','[]'::jsonb);
   any_ambiguous:=true;
  end if;
  kept:=kept || jsonb_build_array(candidate);
 end loop;
 result_status:=case when jsonb_array_length(kept)=0 then 'no_match'
  when any_ambiguous or jsonb_array_length(kept)>1 then 'ambiguous' else source->>'status' end;
 if result_status<>'resolved' then
  kept:=coalesce((select jsonb_agg(value || jsonb_build_object('resolution_status','ambiguous','offers','[]'::jsonb))
   from jsonb_array_elements(kept)),'[]'::jsonb);
 end if;
 return source || jsonb_build_object('status',result_status,'candidates',kept,
  'imaging_clarification',case when result_status='resolved' then null else jsonb_build_object('kind','rx_chest_projection') end);
end $$;

revoke all on function health.validate_imaging_protocol_service(),health.parse_rx_chest_request(text) from public,anon,authenticated;
revoke all on function public.api_resolve_rx_chest_pilot(text,text,double precision,double precision,uuid,integer) from public,anon,authenticated;
grant execute on function health.parse_rx_chest_request(text),public.api_resolve_rx_chest_pilot(text,text,double precision,double precision,uuid,integer) to service_role;

-- SECTION latest_panel_registry_with_immutable_audit
-- ISOLATED D-006 PROPOSAL. Never submitted to a DB. No approved manifest rows.
-- Included inside the generated migration transaction.
create table health.reviewed_panel_compositions (
 id uuid primary key,
 panel_id uuid not null references health.services(catalog_item_id),
 provider_brand_id uuid not null references core.provider_brands(id),
 version integer not null check (version > 0),
 status text not null check (status in ('complete','incomplete','quarantined')),
 reviewed_state jsonb not null check (jsonb_typeof(reviewed_state)='object'),
 clinical_scope jsonb not null check (jsonb_typeof(clinical_scope)='array'),
 protocol jsonb not null check (jsonb_typeof(protocol)='object'),
 approved_queries jsonb not null check (jsonb_typeof(approved_queries)='array'),
 review_id text not null,
 audit_event_id uuid not null references audit.events(id) on delete restrict,
 source_evidence jsonb not null check (jsonb_typeof(source_evidence)='array' and jsonb_array_length(source_evidence)>0),
 created_at timestamptz not null default now(),
 unique(panel_id,provider_brand_id,version)
);
create table health.panel_composition_quarantines (
 composition_id uuid primary key references health.reviewed_panel_compositions(id) on delete restrict,
 reason text not null check (length(trim(reason))>0),
 audit_event_id uuid not null references audit.events(id) on delete restrict,
 created_at timestamptz not null default now()
);
alter table health.reviewed_panel_compositions enable row level security;
alter table health.panel_composition_quarantines enable row level security;
revoke all on health.reviewed_panel_compositions from public,anon,authenticated;
revoke all on health.panel_composition_quarantines from public,anon,authenticated;
grant select,insert on health.reviewed_panel_compositions,health.panel_composition_quarantines to service_role;

-- State comparison automatically quarantines matching when the graph or any
-- reviewed clinical row changes. Historical manifests remain reproducible.
create function health.panel_current_state(p_panel uuid)
returns jsonb language sql stable parallel safe
set search_path=pg_catalog
as $state$
select jsonb_build_object('parent',to_jsonb(s)-array['created_at','updated_at','row_version'],
 'parent_item',to_jsonb(parent_item)-array['created_at','updated_at','row_version','status'],
 'components',(select jsonb_agg(jsonb_build_object(
  'edge',to_jsonb(edge)-array['created_at','updated_at','row_version'],
  'child',to_jsonb(child)-array['created_at','updated_at','row_version'],
  'item',to_jsonb(ci)-array['created_at','updated_at','row_version','status'],
  'definition',to_jsonb(ld)-array['created_at','updated_at','row_version'],
  'specimens',(select coalesce(jsonb_agg(jsonb_build_object('relation',to_jsonb(sp)-array['created_at','updated_at','row_version'],
    'specimen_type',to_jsonb(st)-array['created_at','updated_at','row_version','status']) order by sp.specimen_type_id),'[]'::jsonb)
    from health.service_specimens sp join health.specimen_types st on st.id=sp.specimen_type_id
    where sp.service_id=child.catalog_item_id),
  'methods',(select coalesce(jsonb_agg(to_jsonb(me)-array['created_at','updated_at','row_version'] order by me.method_code),'[]'::jsonb)
    from health.service_methods me where me.service_id=child.catalog_item_id))
   order by edge.component_order,edge.child_service_id)
  from health.service_components edge
  left join health.services child on child.catalog_item_id=edge.child_service_id
  left join catalog.items ci on ci.id=edge.child_service_id
  left join health.lab_service_definitions ld on ld.service_id=edge.child_service_id
  where edge.parent_service_id=s.catalog_item_id))
from health.services s join catalog.items parent_item on parent_item.id=s.catalog_item_id
where s.catalog_item_id=p_panel and s.service_type='lab_panel';
$state$;

create function health.panel_query_is_compatible(p_query text,p_item uuid,p_provider uuid default null)
returns boolean language sql stable parallel safe
set search_path=pg_catalog
as $gate$
select case when not exists(select 1 from health.reviewed_panel_compositions h where h.panel_id=p_item)
 and not exists(select 1 from health.services s
 where s.catalog_item_id=p_item and s.service_type='lab_panel') then true
else exists(
 select 1 from health.reviewed_panel_compositions m
 where m.panel_id=p_item and m.status='complete'
 and m.version=(select max(latest.version) from health.reviewed_panel_compositions latest
  where latest.panel_id=m.panel_id and latest.provider_brand_id=m.provider_brand_id)
 and not exists(select 1 from health.panel_composition_quarantines q where q.composition_id=m.id)
 and exists(select 1 from catalog.items i where i.id=p_item and i.status='active')
 and m.protocol='{"kind":"component_set","version":1,"parameters":{}}'::jsonb
 and (p_provider is null or m.provider_brand_id=p_provider)
 and m.reviewed_state=health.panel_current_state(p_item)
 and jsonb_array_length(m.source_evidence)>0
 and jsonb_array_length(m.clinical_scope)>=2
 and jsonb_array_length(m.clinical_scope)=(select count(*) from health.service_components e where e.parent_service_id=p_item)
 and not exists(
  select 1 from health.service_components e
  left join health.services c on c.catalog_item_id=e.child_service_id
  left join catalog.items ci on ci.id=e.child_service_id
  where e.parent_service_id=p_item and (e.quantity<>1 or not e.is_required
   or c.service_type is distinct from 'lab_test' or ci.status is distinct from 'active'))
 and not exists(select 1 from health.service_components e
  join health.service_specimens sp on sp.service_id=e.child_service_id
  join health.specimen_types st on st.id=sp.specimen_type_id
  where e.parent_service_id=p_item and st.status is distinct from 'active')
 and not exists(select 1 from jsonb_array_elements(m.clinical_scope) c(value)
  where coalesce(c.value->>'specimen','') in ('','unknown','unspecified_by_source')
  or coalesce(c.value->>'method','') in ('','unknown','unspecified_by_source')
  or coalesce(c.value->>'time_aspect','') in ('','unknown','unspecified_by_source')
  or c.value->>'reviewed' is distinct from 'true')
 and not exists(select 1 from health.service_components e where e.parent_service_id=p_item
  and (select count(*) from jsonb_array_elements(m.clinical_scope) c(value)
   where c.value->>'service_id'=e.child_service_id::text)<>1)
 and not exists(select 1 from jsonb_array_elements(m.clinical_scope) c(value)
  where not exists(select 1 from health.lab_service_definitions ld
   where ld.service_id::text=c.value->>'service_id'
    and ld.system=c.value->>'specimen' and ld.method=c.value->>'method'
    and ld.time_aspect=c.value->>'time_aspect'))
 and exists(select 1 from jsonb_array_elements(m.approved_queries) q(value)
  where q.value->>'normalized_query'=core.normalized_text(p_query)
  and q.value->>'composition_reviewed'='true'
  and (q.value->>'scope'='global_explicit_composition'
   or (q.value->>'scope'='provider' and p_provider is not null
    and q.value->>'provider_brand_id'=p_provider::text)))
) end;
$gate$;

create function health.validate_panel_manifest_insert() returns trigger
language plpgsql set search_path=pg_catalog as $validate$
declare evidence jsonb;
begin
 if new.protocol is distinct from '{"kind":"component_set","version":1,"parameters":{}}'::jsonb
 then raise exception 'Only explicit component-set protocol without dose, ingestion or temporal parameters'; end if;
 if new.review_id !~ '^pruevia:evidence-review:[0-9]{8}:[0-9]{2}$'
 then raise exception 'Invalid terminology review identity'; end if;
 if new.reviewed_state is distinct from health.panel_current_state(new.panel_id)
 then raise exception 'Reviewed panel state changed or parent no longer lab_panel'; end if;
 for evidence in select value from jsonb_array_elements(new.source_evidence) loop
  if jsonb_typeof(evidence) is distinct from 'object'
   or evidence->>'kind' is distinct from 'provider_raw'
   or coalesce(evidence->>'url','') !~ '^https://[^[:space:]]+$'
   or coalesce(evidence->>'payload_sha256','') !~ '^[0-9a-f]{64}$'
   or coalesce(evidence->>'normalization_run_id','') !~ '^[0-9a-f-]{36}$'
   or coalesce(evidence->>'observed_at','')=''
  then raise exception 'Malformed or missing provider RAW evidence'; end if;
  perform (evidence->>'observed_at')::timestamptz;
  if not exists(select 1 from ingest.normalization_runs nr join ingest.raw_records rr on rr.id=nr.raw_record_id
   where nr.id=(evidence->>'normalization_run_id')::uuid and nr.input_type='crawler'
    and nr.provider_brand_id=new.provider_brand_id
    and encode(extensions.digest(convert_to(rr.payload::text,'UTF8'),'sha256'),'hex')=evidence->>'payload_sha256')
  then raise exception 'RAW evidence identity, brand or SHA256 changed'; end if;
 end loop;
 -- The event must exist in the same transaction before the manifest is inserted.
 perform 1 from audit.events a where a.id=new.audit_event_id
  and a.action='catalog.panel_composition_review' and a.entity_schema='health'
  and a.entity_table='reviewed_panel_compositions' and a.entity_id=new.id
  and a.request_id=new.review_id
  and a.metadata->'manifest_definition'=to_jsonb(new)-array['created_at','audit_event_id'] for share;
 if not found then raise exception 'Missing exact immutable audit anchor'; end if;
 return new;
end;
$validate$;
create function health.prevent_panel_manifest_mutation() returns trigger
language plpgsql set search_path=pg_catalog as $immutable$
begin raise exception 'Panel review history is append-only; insert a new version or quarantine'; end;
$immutable$;
create function health.validate_panel_quarantine_insert() returns trigger
language plpgsql set search_path=pg_catalog as $quarantine$
begin
 perform 1 from audit.events a where a.id=new.audit_event_id
  and a.action='catalog.panel_composition_quarantine' and a.entity_schema='health'
  and a.entity_table='reviewed_panel_compositions' and a.entity_id=new.composition_id
  and a.metadata->>'reason'=new.reason for share;
 if not found then raise exception 'Missing quarantine audit anchor'; end if;
 return new;
end;
$quarantine$;
create function health.preserve_panel_audit_anchor() returns trigger
language plpgsql set search_path=pg_catalog as $audit$
begin
 if tg_op='TRUNCATE' then
  if exists(select 1 from health.reviewed_panel_compositions)
    or exists(select 1 from health.panel_composition_quarantines)
  then raise exception 'Panel review audit anchors cannot be truncated'; end if;
  return null;
 end if;
 if exists(select 1 from health.reviewed_panel_compositions m where m.audit_event_id=old.id)
   or exists(select 1 from health.panel_composition_quarantines q where q.audit_event_id=old.id)
 then raise exception 'Referenced panel audit anchor is immutable'; end if;
 if tg_op='DELETE' then return old; else return new; end if;
end;
$audit$;
create trigger panel_manifest_insert before insert on health.reviewed_panel_compositions
 for each row execute function health.validate_panel_manifest_insert();
create trigger panel_manifest_immutable before update or delete on health.reviewed_panel_compositions
 for each row execute function health.prevent_panel_manifest_mutation();
create trigger panel_manifest_no_truncate before truncate on health.reviewed_panel_compositions
 for each statement execute function health.prevent_panel_manifest_mutation();
create trigger panel_quarantine_insert before insert on health.panel_composition_quarantines
 for each row execute function health.validate_panel_quarantine_insert();
create trigger panel_quarantine_immutable before update or delete on health.panel_composition_quarantines
 for each row execute function health.prevent_panel_manifest_mutation();
create trigger panel_quarantine_no_truncate before truncate on health.panel_composition_quarantines
 for each statement execute function health.prevent_panel_manifest_mutation();
create trigger panel_audit_anchor_immutable before update or delete on audit.events
 for each row execute function health.preserve_panel_audit_anchor();
create trigger panel_audit_anchor_no_truncate before truncate on audit.events
 for each statement execute function health.preserve_panel_audit_anchor();
revoke all on function health.validate_panel_manifest_insert(),health.prevent_panel_manifest_mutation(),
 health.validate_panel_quarantine_insert(),health.preserve_panel_audit_anchor() from public,anon,authenticated,service_role;
revoke all on function health.panel_current_state(uuid) from public,anon,authenticated;
revoke all on function health.panel_query_is_compatible(text,uuid,uuid) from public,anon,authenticated;
grant execute on function health.panel_current_state(uuid),health.panel_query_is_compatible(text,uuid,uuid) to service_role;

-- This registry is deliberately empty. Creating it does not approve a panel.
-- Complete writes require the guarded importer transaction plus D-006 approval.

-- SECTION requirements_v3
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
    ) as literal_requirements_present
  from lexical_accepted a
), accepted as (
  select a.*,
    exists (select 1 from requirement_checked x where not x.literal_requirements_present) as requirements_pruned
  from requirement_checked a
  where a.literal_requirements_present
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
  case when r.requirements_pruned or r.candidate_count > 1 then 'ambiguous' else r.resolution_status end as resolution_status,
  r.match_method,
  r.explanation_data || jsonb_build_object(
    'meaningful_token_matches', r.meaningful_token_matches,
    'meaningful_token_count', r.meaningful_token_count,
    'literal_requirements_present', r.literal_requirements_present,
    'requirements_pruned', r.requirements_pruned,
    'requirements_policy', 'literal-content-v1-PROPOSED'
  ) as explanation_data,
  r.safe_rank as result_rank
from ranked r
where r.safe_rank <= greatest(1, least(coalesce(p_limit,10),50))
order by r.safe_rank;
$function$;

-- SECTION requirements_v4
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
       case when coalesce((r.explanation_data->>'requirements_pruned')::boolean,false)
                 or r.safe_count > 1 or r.term_source = 'disambiguation' then 'ambiguous' else 'resolved' end,
       r.match_method,
       r.explanation_data,
       r.result_rank
from ranked r
order by r.result_rank;
$function$;

-- SECTION requirements_v6_private_base
CREATE OR REPLACE FUNCTION catalog.resolve_items_v6_before_panels(p_query text, p_domain_code text DEFAULT 'health_diagnostics'::text, p_provider_brand_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 10)
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

-- SECTION panel_v6_wrapper
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
set search_path=pg_catalog
as $$
select r.item_id,r.display_name,r.matched_term,r.term_source,r.provider_brand_id,
 r.confidence,
 case when g.compatible then r.resolution_status else 'ambiguous'::text end,
 r.match_method,
 coalesce(r.explanation_data,'{}'::jsonb) || case when g.compatible then '{}'::jsonb
 else jsonb_build_object('requires_confirmation',true,'reason_code','panel_composition_unverified') end,
 r.result_rank
from catalog.resolve_items_v6_before_panels(p_query,p_domain_code,p_provider_brand_id,p_limit) r
cross join lateral (select health.panel_query_is_compatible(p_query,r.item_id,p_provider_brand_id) compatible) g;
$$;

-- SECTION image_v7_wrapper
-- PROPOSAL ONLY. NOT EXECUTED. Central gate covers search and package callers.

set local lock_timeout='5s';
set local statement_timeout='30s';
create function health.rx_protocol_gate(p_query text,p_service_id uuid) returns text
language plpgsql stable set search_path=pg_catalog as $$
declare request jsonb; protocol record; requested text[]; declared text[]; scoped boolean;
begin
 request:=health.parse_rx_chest_request(p_query);
 scoped:=coalesce((request->>'scope')::boolean,false);
 select p.* into protocol from health.imaging_protocols p
  where p.service_id=p_service_id;
 if not found then
  if scoped then return 'reject'; else return 'pass'; end if;
 end if;
 if not scoped then return 'clarify'; end if;
 if not exists(select 1 from health.services s where s.catalog_item_id=p_service_id
  and s.service_type='imaging' and s.modality='radiography')
  or not exists(select 1 from health.service_anatomy a join health.anatomical_sites n on n.id=a.anatomical_site_id
   where a.service_id=p_service_id and a.role='target' and n.code='chest' and n.status='active')
 then return 'reject'; end if;
 requested:=array(select jsonb_array_elements_text(request->'projections'));
 declared:=array(select distinct v.projection_code from health.imaging_protocol_views v
  where v.service_id=p_service_id order by v.projection_code);
 if cardinality(declared)=0 then return 'reject'; end if;
 if cardinality(requested)>0 and requested<>declared then return 'reject'; end if;
 if request->>'variant'<>'unspecified' and request->>'variant'<>protocol.acquisition_variant then return 'reject'; end if;
 if request->>'view_count' is not null and (request->>'view_count')::int is distinct from protocol.view_count then return 'reject'; end if;
 if request->>'posture' is not null and request->>'posture' is distinct from protocol.patient_posture then return 'reject'; end if;
 if not protocol.projection_set_complete or cardinality(requested)=0
  or request->>'variant'='unspecified' or coalesce((request->>'unmodeled')::boolean,true)
 then return 'clarify'; end if;
 return 'pass';
end $$;

create function catalog.resolve_items_v7(
 p_query text,p_domain_code text default 'health_diagnostics',
 p_provider_brand_id uuid default null,p_limit integer default 10
) returns table(item_id uuid,display_name text,matched_term text,term_source text,
 provider_brand_id uuid,confidence numeric,resolution_status text,match_method text,
 explanation_data jsonb,result_rank bigint)
language plpgsql stable set search_path=pg_catalog as $$
declare candidate record; gate text;
begin
 for candidate in select r.* from catalog.resolve_items_v6(p_query,p_domain_code,p_provider_brand_id,p_limit) r loop
  gate:=health.rx_protocol_gate(p_query,candidate.item_id);
  if gate='reject' then continue; end if;
  return query select candidate.item_id,candidate.display_name,candidate.matched_term,candidate.term_source,
   candidate.provider_brand_id,candidate.confidence,
   case when gate='clarify' then 'ambiguous' else candidate.resolution_status end,
   candidate.match_method,candidate.explanation_data || jsonb_build_object('rx_protocol_gate',gate),candidate.result_rank;
 end loop;
end $$;
revoke all on function health.rx_protocol_gate(text,uuid),catalog.resolve_items_v7(text,text,uuid,integer) from public,anon,authenticated;
grant execute on function health.rx_protocol_gate(text,uuid),catalog.resolve_items_v7(text,text,uuid,integer) to service_role;

-- SECTION image_definition_integrity
-- ISOLATED D-006 PROPOSAL. NOT EXECUTED OR VERIFIED IN POSTGRESQL.
-- Install after proposed001 schema and before the first reviewed import.
-- No review may omit the complete definition or retroactively redefine it.

set local lock_timeout='5s';
set local statement_timeout='30s';

-- Exact JSONB equality is intentional. Include nullable attributes, ordered
-- views and every anatomy link; never derive view_count from the view array.
-- Catalog lifecycle status and its automatic revision counter are operational,
-- not clinical identity. A reviewed item may be hidden/deprecated for recovery.
-- health.services has no status in the audited schema; no future field is
-- silently excluded. Site status remains guarded because the gate requires it.
create function health.rx_protocol_definition(p_service_id uuid) returns jsonb
language sql stable set search_path=pg_catalog as $$
 select jsonb_build_object(
  'definition_version',1,
  'catalog_item',to_jsonb(i)-'created_at'-'updated_at'-'status'-'row_version',
  'service',to_jsonb(s)-'created_at'-'updated_at',
  'protocol',to_jsonb(p)-'created_at',
  'anatomy',coalesce((select jsonb_agg(jsonb_build_object(
   'link',to_jsonb(a)-'created_at','site',to_jsonb(n)-'created_at')
   order by a.anatomical_site_id,a.role)
   from health.service_anatomy a join health.anatomical_sites n on n.id=a.anatomical_site_id
   where a.service_id=p.service_id),'[]'::jsonb),
  'views',coalesce((select jsonb_agg(to_jsonb(v) order by v.ordinal)
   from health.imaging_protocol_views v where v.service_id=p.service_id),'[]'::jsonb))
 from health.imaging_protocols p
 join health.services s on s.catalog_item_id=p.service_id
 join catalog.items i on i.id=p.service_id
 where p.service_id=p_service_id;
$$;

create function health.assert_rx_protocol_integrity(p_service_id uuid) returns void
language plpgsql security definer set search_path=pg_catalog as $$
declare definition jsonb; review record; reviews integer:=0;
begin
 if p_service_id is null then return; end if;
 -- Serialize final checks for the same service, including cross-table changes.
 perform 1 from health.services where catalog_item_id=p_service_id for update;
 if not exists(select 1 from health.imaging_protocols where service_id=p_service_id)
  and not exists(select 1 from audit.events where action='catalog.imaging_protocol_review'
   and entity_schema='catalog' and entity_table='items' and entity_id=p_service_id)
 then return; end if;
 definition:=health.rx_protocol_definition(p_service_id);
 if definition is null then raise exception 'Reviewed RX definition or service deleted: %',p_service_id; end if;
 if definition#>>'{service,service_type}' is distinct from 'imaging'
  or definition#>>'{service,modality}' is distinct from 'radiography'
  or definition#>>'{catalog_item,item_type}' is distinct from 'service'
 then raise exception 'RX service type/modality changed: %',p_service_id; end if;
 if not exists(select 1 from health.service_anatomy a join health.anatomical_sites n on n.id=a.anatomical_site_id
  where a.service_id=p_service_id and a.role='target' and n.code='chest' and n.status='active')
  or jsonb_array_length(definition->'views')=0
 then raise exception 'RX pilot requires chest anatomy and explicit projections: %',p_service_id; end if;
 -- Preserve all prior definitions, then require an exact current review anchor.
 -- A new event cannot authorize rewriting an older reviewed service in place.
 if exists(select 1 from audit.events e where e.action='catalog.imaging_protocol_review'
  and e.entity_schema='catalog' and e.entity_table='items' and e.entity_id=p_service_id
  and e.metadata->'protocol_definition' is distinct from definition)
 then raise exception 'RX differs from an immutable prior reviewed definition: %',p_service_id; end if;
 for review in select e.* from audit.events e
  where e.action='catalog.imaging_protocol_review' and e.entity_schema='catalog'
   and e.entity_table='items' and e.entity_id=p_service_id
   and e.request_id=definition#>>'{protocol,source_review_id}'
   and e.metadata->>'contract_sha256'=definition#>>'{protocol,source_contract_sha256}'
   order by e.id
 loop
  reviews:=reviews+1;
  if jsonb_typeof(review.metadata->'protocol_definition') is distinct from 'object'
   or review.metadata->'protocol_definition' is distinct from definition
   or review.request_id is distinct from definition#>>'{protocol,source_review_id}'
   or review.metadata->>'contract_sha256' is distinct from definition#>>'{protocol,source_contract_sha256}'
   or coalesce(review.metadata->>'approval_scope_sha256','') !~ '^[a-f0-9]{64}$'
  then raise exception 'RX complete audited definition differs: service %, event %',p_service_id,review.id; end if;
 end loop;
 if reviews=0 then raise exception 'RX complete definition has no review event: %',p_service_id; end if;
end $$;

create function health.check_rx_protocol_integrity() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
declare prior jsonb; current_row jsonb; old_id uuid; new_id uuid; affected uuid;
begin
 if TG_OP<>'INSERT' then prior:=to_jsonb(OLD); end if;
 if TG_OP<>'DELETE' then current_row:=to_jsonb(NEW); end if;
 if TG_TABLE_SCHEMA='health' and TG_TABLE_NAME='anatomical_sites' then
  -- Site code/status/parent/laterality/name changes affect every linked order.
  for affected in select distinct a.service_id from health.service_anatomy a
   where a.anatomical_site_id in ((prior->>'id')::uuid,(current_row->>'id')::uuid)
   order by a.service_id
  loop perform health.assert_rx_protocol_integrity(affected); end loop;
 else
  if TG_TABLE_NAME='services' then
   old_id:=(prior->>'catalog_item_id')::uuid; new_id:=(current_row->>'catalog_item_id')::uuid;
  elsif TG_TABLE_SCHEMA='catalog' then
   old_id:=(prior->>'id')::uuid; new_id:=(current_row->>'id')::uuid;
  elsif TG_TABLE_SCHEMA='audit' then
   if prior->>'action'='catalog.imaging_protocol_review' then old_id:=(prior->>'entity_id')::uuid; end if;
   if current_row->>'action'='catalog.imaging_protocol_review' then new_id:=(current_row->>'entity_id')::uuid; end if;
  else
   old_id:=(prior->>'service_id')::uuid; new_id:=(current_row->>'service_id')::uuid;
  end if;
  -- Both old and new IDs matter when a link/view is moved to another order.
  for affected in select distinct x from unnest(array[old_id,new_id]) x where x is not null order by x
  loop perform health.assert_rx_protocol_integrity(affected); end loop;
 end if;
 return null;
end $$;

create constraint trigger rx_protocol_definition_guard after insert or update or delete
 on health.imaging_protocols deferrable initially deferred for each row execute function health.check_rx_protocol_integrity();
create constraint trigger rx_protocol_views_definition_guard after insert or update or delete
 on health.imaging_protocol_views deferrable initially deferred for each row execute function health.check_rx_protocol_integrity();
create constraint trigger rx_service_definition_guard after insert or update or delete
 on health.services deferrable initially deferred for each row execute function health.check_rx_protocol_integrity();
create constraint trigger rx_anatomy_definition_guard after insert or update or delete
 on health.service_anatomy deferrable initially deferred for each row execute function health.check_rx_protocol_integrity();
create constraint trigger rx_anatomical_site_definition_guard after insert or update or delete
 on health.anatomical_sites deferrable initially deferred for each row execute function health.check_rx_protocol_integrity();
create constraint trigger rx_catalog_item_definition_guard after insert or update or delete
 on catalog.items deferrable initially deferred for each row execute function health.check_rx_protocol_integrity();
create constraint trigger rx_audit_definition_guard after insert or update or delete
 on audit.events deferrable initially deferred for each row execute function health.check_rx_protocol_integrity();

-- Preserve the review anchor even if someone deletes both protocol and event
-- in one transaction. Row constraint checks alone cannot protect that case.
create function health.preserve_rx_protocol_review() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
begin
 if OLD.action='catalog.imaging_protocol_review' then
  raise exception 'RX review events are immutable; preserve the original evidence';
 end if;
 if TG_OP='DELETE' then return OLD; end if;
 return NEW;
end $$;
create trigger rx_review_immutable before update or delete on audit.events
 for each row execute function health.preserve_rx_protocol_review();

-- TRUNCATE bypasses row triggers. Do not permit it across protected tables
-- while a reviewed protocol exists; normal unrelated row edits remain allowed.
create function health.prevent_rx_protocol_truncate() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
begin
 if exists(select 1 from audit.events where action='catalog.imaging_protocol_review') then
  raise exception 'TRUNCATE would bypass reviewed RX definition guards';
 end if;
 return null;
end $$;
create trigger rx_protocol_no_truncate before truncate on health.imaging_protocols
 for each statement execute function health.prevent_rx_protocol_truncate();
create trigger rx_views_no_truncate before truncate on health.imaging_protocol_views
 for each statement execute function health.prevent_rx_protocol_truncate();
create trigger rx_service_no_truncate before truncate on health.services
 for each statement execute function health.prevent_rx_protocol_truncate();
create trigger rx_anatomy_no_truncate before truncate on health.service_anatomy
 for each statement execute function health.prevent_rx_protocol_truncate();
create trigger rx_site_no_truncate before truncate on health.anatomical_sites
 for each statement execute function health.prevent_rx_protocol_truncate();
create trigger rx_item_no_truncate before truncate on catalog.items
 for each statement execute function health.prevent_rx_protocol_truncate();
create trigger rx_audit_no_truncate before truncate on audit.events
 for each statement execute function health.prevent_rx_protocol_truncate();

revoke all on function health.rx_protocol_definition(uuid),health.assert_rx_protocol_integrity(uuid),
 health.check_rx_protocol_integrity(),health.preserve_rx_protocol_review(),health.prevent_rx_protocol_truncate()
 from public,anon,authenticated;
grant execute on function health.rx_protocol_definition(uuid) to service_role;
-- Validate any existing reviewed definitions at installation too. This is a
-- proposal precondition, not a claim that existing remote schemas were altered.
do $$ declare affected uuid; begin
 for affected in select service_id from health.imaging_protocols
  union select entity_id from audit.events where action='catalog.imaging_protocol_review'
   and entity_schema='catalog' and entity_table='items' and entity_id is not null
 loop perform health.assert_rx_protocol_integrity(affected); end loop;
end $$;

-- SECTION public.api_search_before_panels
create or replace function public.api_search_before_panels(
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
), diversified as (
  select r.*,
    row_number() over (
      partition by r.service_id, r.provider_brand_id
      order by r.distance_meters nulls last, r.amount_minor nulls last,
               r.provider_name, r.display_name, r.offer_id
    ) as provider_rank
  from preferred r
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
from diversified r
left join lateral supply.resolve_offer_link_metadata(r.offer_id, r.provider_location_id) lm on true
order by case when r.provider_rank = 1 then 0 else 1 end,
         r.confidence desc, r.distance_meters nulls last,
         r.provider_name, r.display_name
limit greatest(1, least(coalesce(p_limit, 20), 100));
$$;

-- SECTION public.api_search
create or replace function public.api_search(
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
select r.* from public.api_search_before_panels(
 p_query,p_domain_code,p_latitude,p_longitude,p_location_id,p_limit) r
where health.panel_query_is_compatible(p_query,r.service_id,r.provider_brand_id);
$$;

-- SECTION public.api_service_detail
create or replace function public.api_service_detail(p_service_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, catalog, health, supply, core
as $$
select case when i.id is null then null else jsonb_build_object(
  'id', i.id,
  'status', i.status,
  'item_type', i.item_type,
  'names', coalesce((select jsonb_agg(jsonb_build_object('name', n.name, 'type', n.name_type, 'primary', n.is_primary) order by n.is_primary desc, n.name) from catalog.item_names n where n.item_id = i.id), '[]'::jsonb),
  'service', (select to_jsonb(h) from health.services h where h.catalog_item_id = i.id),
  'offers', coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', o.id,
      'provider_brand_id', o.provider_brand_id,
      'provider_name', b.name,
      'provider_display_name', o.provider_display_name,
      'provider_sku', o.provider_sku,
      'status', o.status,
      'scopes', (select coalesce(jsonb_agg(jsonb_build_object('scope_type', os.scope_type, 'market_id', os.provider_market_id, 'location_id', os.provider_location_id)), '[]'::jsonb) from supply.offer_scopes os where os.offer_id = o.id and os.status = 'active'),
      'prices', (select coalesce(jsonb_agg(jsonb_build_object('price_type', pv.price_type, 'price_key', pv.price_key, 'amount_minor', pv.amount_minor, 'currency', pv.currency, 'last_seen_at', pv.last_seen_at)), '[]'::jsonb) from supply.offer_scopes os join supply.current_price_versions pv on pv.offer_scope_id = os.id where os.offer_id = o.id and os.status = 'active')
    ) order by b.name, o.provider_display_name)
    from supply.offers o join core.provider_brands b on b.id = o.provider_brand_id and b.status = 'active'
    where o.catalog_item_id = i.id and o.status = 'active'
    and health.panel_query_is_compatible((select pn.name from catalog.item_names pn where pn.item_id=i.id and pn.is_primary order by pn.created_at desc limit 1),i.id,o.provider_brand_id)
  ), '[]'::jsonb)
) end
from catalog.items i
where i.id = p_service_id and i.status = 'active';
$$;

-- SECTION public.api_provider_detail
create or replace function public.api_provider_detail(p_provider_brand_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, core, catalog, supply, gis
as $$
select case when b.id is null then null else jsonb_build_object(
  'id', b.id,
  'name', b.name,
  'slug', b.slug,
  'website_url', b.website_url,
  'verification_status', b.verification_status,
  'locations', coalesce((select jsonb_agg(to_jsonb(x)) from (select l.id, l.name, l.address_line_1 as address, l.locality_text as locality, l.postal_code, l.phone, case when l.coordinates is null then null else gis.st_y(l.coordinates::gis.geometry) end as latitude, case when l.coordinates is null then null else gis.st_x(l.coordinates::gis.geometry) end as longitude from core.provider_locations l where l.provider_brand_id = b.id and l.status = 'active' order by l.name) x), '[]'::jsonb),
  'services', coalesce((select jsonb_agg(to_jsonb(x)) from (select distinct i.id, coalesce((select n.name from catalog.item_names n where n.item_id=i.id and n.is_primary limit 1), '') as display_name from supply.offers o join catalog.items i on i.id=o.catalog_item_id where o.provider_brand_id=b.id and o.status='active' and i.status='active' and health.panel_query_is_compatible((select pn.name from catalog.item_names pn where pn.item_id=i.id and pn.is_primary order by pn.created_at desc limit 1),i.id,b.id) order by i.id) x), '[]'::jsonb)
) end
from core.provider_brands b
where b.id = p_provider_brand_id and b.status = 'active';
$$;

-- SECTION package_with_both_gates
create or replace function public.api_resolve_package_links_legacy(
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
set search_path = public, catalog, core, supply, geo, gis, extensions
as $$
with input_items as materialized (
  select
    x.ordinality::integer as item_index,
    trim(x.value) as input,
    core.normalized_text(trim(x.value)) as normalized_query
  from jsonb_array_elements_text(
    case when jsonb_typeof(coalesce(p_items, '[]'::jsonb)) = 'array'
      then coalesce(p_items, '[]'::jsonb)
      else '[]'::jsonb
    end
  ) with ordinality as x(value, ordinality)
  where trim(x.value) <> ''
), resolved_rows as materialized (
  select
    i.item_index,
    i.input,
    i.normalized_query,
    r.item_id,
    r.display_name,
    r.matched_term,
    r.term_source,
    r.confidence,
    r.resolution_status,
    r.match_method,
    r.explanation_data,
    r.result_rank
  from input_items i
  left join lateral catalog.resolve_items_v7(
    i.input,
    p_domain_code,
    null,
    greatest(1, least(coalesce(p_limit, 10), 50))
  ) r on true
), item_payload as (
  select
    rr.item_index,
    rr.input,
    rr.normalized_query,
    case
      when count(rr.item_id) = 0 then 'no_match'
      when count(rr.item_id) > 1 or bool_or(rr.resolution_status = 'ambiguous') then 'ambiguous'
      else 'resolved'
    end as status,
    case
      when count(rr.item_id) = 0 then 'service_not_found'
      when count(rr.item_id) > 1 or bool_or(rr.resolution_status = 'ambiguous') then 'ambiguous_service'
      else null
    end as reason_code,
    coalesce(jsonb_agg(jsonb_build_object(
      'service_id', rr.item_id,
      'display_name', rr.display_name,
      'matched_term', rr.matched_term,
      'term_source', rr.term_source,
      'confidence', rr.confidence,
      'resolution_status', rr.resolution_status,
      'match_method', rr.match_method,
      'explanation', coalesce(rr.explanation_data, '{}'::jsonb)
    ) order by rr.result_rank, rr.display_name)
      filter (where rr.item_id is not null), '[]'::jsonb) as candidates
  from resolved_rows rr
  group by rr.item_index, rr.input, rr.normalized_query
), resolved_items as (
  select
    rr.item_index,
    (array_agg(rr.item_id order by rr.result_rank))[1] as item_id
  from resolved_rows rr
  group by rr.item_index
  having count(rr.item_id) = 1
     and bool_and(rr.resolution_status = 'resolved')
), expanded_offers as (
  select
    ri.item_index,
    o.catalog_item_id as item_id,
    o.id as offer_id,
    o.provider_brand_id,
    b.name as provider_name,
    o.requires_quote as offer_requires_quote,
    os.id as offer_scope_id,
    os.scope_type,
    case os.scope_type when 'location' then 3 when 'market' then 2 else 1 end::smallint as scope_specificity,
    l.id as provider_location_id,
    l.name as provider_location_name,
    l.coordinates,
    price.price_type,
    price.price_key,
    price.amount_minor,
    price.currency,
    price.last_seen_at as price_last_seen_at,
    coalesce(link.url, link_parent.url) as source_url
  from resolved_items ri
  join supply.offers o
    on o.catalog_item_id = ri.item_id
   and o.status = 'active'
   and health.panel_query_is_compatible(
     (select ii.input from input_items ii where ii.item_index=ri.item_index),
     o.catalog_item_id,o.provider_brand_id)
  join core.provider_brands b
    on b.id = o.provider_brand_id
   and b.status = 'active'
  join supply.offer_scopes os
    on os.offer_id = o.id
   and os.status = 'active'
  join lateral (
    select pl.id, pl.name, pl.coordinates
    from core.provider_locations pl
    where pl.status = 'active'
      and (p_location_id is null or pl.id = p_location_id)
      and (
        (os.scope_type = 'location' and pl.id = os.provider_location_id)
        or (os.scope_type = 'market' and exists (
          select 1
          from core.provider_market_locations pml
          where pml.provider_market_id = os.provider_market_id
            and pml.provider_location_id = pl.id
        ))
        or (os.scope_type = 'brand' and pl.provider_brand_id = o.provider_brand_id)
      )
  ) l on true
  left join lateral (
    select rp.price_type, rp.price_key, rp.amount_minor, rp.currency, pv.last_seen_at
    from supply.resolve_prices(o.id, l.id) rp
    left join supply.price_versions pv on pv.id = rp.price_version_id
    order by rp.specificity desc,
      case when rp.price_type = 'regular' then 0 else 1 end,
      rp.amount_minor asc,
      rp.price_key
    limit 1
  ) price on true
  left join lateral (
    select ol.url
    from supply.offer_links ol
    where ol.offer_scope_id = os.id
      and ol.link_type = 'details'
      and ol.status = 'active'
    order by ol.verified_at desc nulls last, ol.created_at desc
    limit 1
  ) link on true
  left join lateral (
    select ol.url
    from supply.offer_links ol
    where ol.offer_scope_id = (
      select parent.id
      from supply.offer_scopes parent
      where parent.offer_id = o.id and parent.scope_type = 'brand' and parent.status = 'active'
      limit 1
    )
      and ol.link_type = 'details'
      and ol.status = 'active'
    order by ol.verified_at desc nulls last, ol.created_at desc
    limit 1
  ) link_parent on true
), ranked_offers as (
  select
    eo.*,
    row_number() over (
      partition by eo.item_index, eo.offer_id, eo.provider_location_id
      order by eo.scope_specificity desc,
        eo.amount_minor nulls last,
        eo.offer_scope_id
    ) as scope_rank
  from expanded_offers eo
), offer_payload as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'item_index', ro.item_index,
    'item_id', ro.item_id,
    'offer_id', ro.offer_id,
    'provider_brand_id', ro.provider_brand_id,
    'provider_name', ro.provider_name,
    'provider_location_id', ro.provider_location_id,
    'provider_location_name', ro.provider_location_name,
    'latitude', case when ro.coordinates is null then null else gis.st_y(ro.coordinates::gis.geometry) end,
    'longitude', case when ro.coordinates is null then null else gis.st_x(ro.coordinates::gis.geometry) end,
    'distance_meters', case
      when ro.coordinates is null or p_latitude is null or p_longitude is null then null
      else gis.st_distance(
        ro.coordinates,
        gis.st_setsrid(gis.st_makepoint(p_longitude, p_latitude), 4326)::gis.geography
      )
    end,
    'source_url', ro.source_url,
    'price_type', ro.price_type,
    'price_key', ro.price_key,
    'amount_minor', ro.amount_minor,
    'currency', ro.currency,
    'price_last_seen_at', ro.price_last_seen_at,
    'requires_quote', (ro.offer_requires_quote or ro.amount_minor is null)
  ) order by ro.item_index, ro.provider_name, ro.provider_location_name, ro.amount_minor nulls last)
    filter (where ro.scope_rank = 1), '[]'::jsonb) as offers
  from ranked_offers ro
)
select jsonb_build_object(
  'engine_version', 'clinical-resolver-v6',
  'items', coalesce((
    select jsonb_agg(jsonb_build_object(
      'index', ip.item_index,
      'input', ip.input,
      'normalized_query', ip.normalized_query,
      'status', ip.status,
      'reason_code', ip.reason_code,
      'candidates', ip.candidates
    ) order by ip.item_index)
    from item_payload ip
  ), '[]'::jsonb),
  'offers', coalesce((select offers from offer_payload), '[]'::jsonb)
);
$$;

-- SECTION catalog.search_items
CREATE OR REPLACE FUNCTION catalog.search_items(p_query text, p_domain_code text DEFAULT 'health_diagnostics'::text, p_provider_brand_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 10)
 RETURNS TABLE(item_id uuid, display_name text, matched_term text, term_source text, provider_brand_id uuid, similarity_score real, weighted_score numeric)
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
select r.item_id, r.display_name, r.matched_term, r.term_source,
       r.provider_brand_id, r.confidence::real, r.confidence
from catalog.resolve_items_v7(p_query, p_domain_code, p_provider_brand_id, p_limit) r
where r.resolution_status in ('resolved', 'ambiguous')
order by r.confidence desc, r.display_name
limit greatest(1, least(coalesce(p_limit, 10), 50));
$function$;

-- SECTION public.api_resolve_search_v4
CREATE OR REPLACE FUNCTION public.api_resolve_search_v4(p_query text, p_domain_code text DEFAULT 'health_diagnostics'::text, p_latitude double precision DEFAULT NULL::double precision, p_longitude double precision DEFAULT NULL::double precision, p_location_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 20)
 RETURNS jsonb
 LANGUAGE sql
 STABLE PARALLEL SAFE SECURITY DEFINER
 SET search_path TO 'public', 'catalog', 'supply', 'core'
AS $function$
with valid_input as (
  select core.normalized_text(p_query) as normalized_query
  where core.normalized_text(p_query) <> ''
), candidates as materialized (
  select r.*
  from valid_input v
  cross join lateral catalog.resolve_items_v7(
    p_query, p_domain_code, null,
    greatest(1, least(coalesce(p_limit, 20), 50))
  ) r
), candidate_offers as (
  select c.item_id,
    coalesce(jsonb_agg(jsonb_build_object(
      'offer_id', x.offer_id,
      'provider_brand_id', x.provider_brand_id,
      'provider_name', x.provider_name,
      'provider_location_id', x.provider_location_id,
      'provider_location_name', x.provider_location_name,
      'latitude', x.latitude,
      'longitude', x.longitude,
      'distance_meters', x.distance_meters,
      'source_url', x.source_url,
      'study_url', x.study_url,
      'location_url', x.location_url,
      'booking_url', x.booking_url,
      'link_capability', x.link_capability,
      'link_handoff', x.link_handoff,
      'price_type', x.price_type,
      'price_key', x.price_key,
      'amount_minor', x.amount_minor,
      'currency', x.currency,
      'price_last_seen_at', x.price_last_seen_at
    ) order by x.distance_meters nulls last, x.provider_name, x.provider_location_name)
      filter (where x.offer_id is not null
        and (x.amount_minor is not null or x.provider_location_id is not null)),
      '[]'::jsonb) as offers
  from candidates c
  left join lateral (
    select distinct on (s.offer_id, s.provider_location_id, s.price_type, s.price_key)
      s.offer_id, s.provider_brand_id, s.provider_name,
      s.provider_location_id, s.provider_location_name,
      s.latitude, s.longitude, s.distance_meters, s.source_url,
      s.study_url, s.location_url, s.booking_url, s.link_capability,
      s.link_handoff,
      s.price_type, s.price_key, s.amount_minor, s.currency,
      s.price_last_seen_at
    from public.api_search(
      c.display_name, p_domain_code, p_latitude, p_longitude,
      p_location_id, greatest(1, least(coalesce(p_limit, 20), 100))
    ) s
    where s.service_id = c.item_id
    order by s.offer_id, s.provider_location_id, s.price_type, s.price_key,
             s.distance_meters nulls last, s.amount_minor nulls last
  ) x on true
  group by c.item_id
), payload as (
  select c.item_id, c.result_rank, c.display_name, c.matched_term,
         c.term_source, c.provider_brand_id, c.confidence,
         c.resolution_status, c.match_method, c.explanation_data,
         coalesce(o.offers, '[]'::jsonb) as offers
  from candidates c
  left join candidate_offers o on o.item_id = c.item_id
), summary as (
  select count(*)::integer as candidate_count,
         coalesce(bool_or(resolution_status = 'ambiguous'), false) as has_ambiguous
  from payload
), response_status as (
  select case
    when candidate_count = 0 then 'no_match'
    when has_ambiguous or candidate_count > 1 then 'ambiguous'
    else 'resolved'
  end as status
  from summary
)
select jsonb_build_object(
  'query', p_query,
  'normalized_query', coalesce((select normalized_query from valid_input), ''),
  'engine_version', 'clinical-resolver-v6',
  'status', (select status from response_status),
  'candidates', coalesce((
    select jsonb_agg(jsonb_build_object(
      'service_id', p.item_id,
      'display_name', p.display_name,
      'matched_term', p.matched_term,
      'term_source', p.term_source,
      'provider_brand_id', p.provider_brand_id,
      'confidence', p.confidence,
      'resolution_status', p.resolution_status,
      'match_method', p.match_method,
      'explanation', p.explanation_data,
      'offers', p.offers
    ) order by p.result_rank)
    from payload p
  ), '[]'::jsonb)
);
$function$;

-- SECTION public.api_resolve_search_v4_links_legacy
CREATE OR REPLACE FUNCTION public.api_resolve_search_v4_links_legacy(p_query text, p_domain_code text DEFAULT 'health_diagnostics'::text, p_latitude double precision DEFAULT NULL::double precision, p_longitude double precision DEFAULT NULL::double precision, p_location_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 20)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
with valid_input as (
  select core.normalized_text(p_query) as normalized_query
  where core.normalized_text(p_query) <> ''
), candidates as materialized (
  select r.*
  from valid_input v
  cross join lateral catalog.resolve_items_v7(
    p_query,
    p_domain_code,
    null,
    greatest(1, least(coalesce(p_limit, 20), 50))
  ) r
), candidate_offers as (
  select c.item_id,
    coalesce(jsonb_agg(jsonb_build_object(
      'offer_id', x.offer_id,
      'provider_brand_id', x.provider_brand_id,
      'provider_name', x.provider_name,
      'provider_location_id', x.provider_location_id,
      'provider_location_name', x.provider_location_name,
      'latitude', x.latitude,
      'longitude', x.longitude,
      'distance_meters', x.distance_meters,
      'source_url', x.source_url,
      'price_type', x.price_type,
      'price_key', x.price_key,
      'amount_minor', x.amount_minor,
      'currency', x.currency,
      'price_last_seen_at', x.price_last_seen_at
    ) order by x.distance_meters nulls last, x.provider_name)
      filter (where x.offer_id is not null
        and (x.amount_minor is not null or x.provider_location_id is not null)),
      '[]'::jsonb) as offers
  from candidates c
  left join lateral (
    select distinct on (s.offer_id, s.price_type, s.price_key)
      s.offer_id, s.provider_brand_id, s.provider_name,
      s.provider_location_id, s.provider_location_name,
      s.latitude, s.longitude, s.distance_meters, s.source_url,
      s.price_type, s.price_key, s.amount_minor, s.currency,
      s.price_last_seen_at
    from public.api_search(
      c.display_name,
      p_domain_code,
      p_latitude,
      p_longitude,
      p_location_id,
      greatest(1, least(coalesce(p_limit, 20), 100))
    ) s
    where s.service_id = c.item_id
    order by s.offer_id, s.price_type, s.price_key,
             s.distance_meters nulls last, s.amount_minor nulls last
  ) x on true
  group by c.item_id
), payload as (
  select c.item_id, c.result_rank, c.display_name, c.matched_term,
         c.term_source, c.provider_brand_id, c.confidence,
         c.resolution_status, c.match_method, c.explanation_data,
         coalesce(o.offers, '[]'::jsonb) as offers
  from candidates c
  left join candidate_offers o on o.item_id = c.item_id
), summary as (
  select count(*)::integer as candidate_count,
         coalesce(bool_or(resolution_status = 'ambiguous'), false) as has_ambiguous
  from payload
), response_status as (
  select case
    when candidate_count = 0 then 'no_match'
    when has_ambiguous or candidate_count > 1 then 'ambiguous'
    else 'resolved'
  end as status
  from summary
)
select jsonb_build_object(
  'query', p_query,
  'normalized_query', coalesce((select normalized_query from valid_input), ''),
  'engine_version', 'clinical-resolver-v6',
  'status', (select status from response_status),
  'candidates', coalesce((
    select jsonb_agg(jsonb_build_object(
      'service_id', p.item_id,
      'display_name', p.display_name,
      'matched_term', p.matched_term,
      'term_source', p.term_source,
      'provider_brand_id', p.provider_brand_id,
      'confidence', p.confidence,
      'resolution_status', p.resolution_status,
      'match_method', p.match_method,
      'explanation', p.explanation_data,
      'offers', p.offers
    ) order by p.result_rank)
    from payload p
  ), '[]'::jsonb)
);
$function$;

-- SECTION package_original_alignment
-- ISOLATED D-006 PROPOSAL. NOT EXECUTED. Replaces the proposed package decorator,
-- not any currently installed public function. Original arrays are mandatory.

set local lock_timeout='5s';
set local statement_timeout='30s';
create function public.api_resolve_rx_chest_package_pilot_v2(
 p_items jsonb,p_domain_code text default 'health_diagnostics',
 p_latitude double precision default null,p_longitude double precision default null,
 p_location_id uuid default null,p_limit integer default 10,p_from_ocr boolean default false,
 p_original_items jsonb default null
) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare
 source jsonb; item jsonb; candidate jsonb; kept jsonb; output jsonb='[]'::jsonb;
 original text; gate text; state text; index_value integer; total integer;
 allowed_indices integer[]='{}'::integer[]; actual_indices integer[];
 expected_indices integer[]; requires_review boolean; candidate_has_protocol boolean;
 projection_fragment boolean; fragment_pattern text; preparation_suffix text;
 fallback_items jsonb; fallback_payload jsonb;
begin
 if p_domain_code is distinct from 'health_diagnostics' then
  if p_from_ocr then
   return public.api_resolve_ocr_package(p_items,p_domain_code,p_latitude,p_longitude,p_location_id,p_limit);
  end if;
  return public.api_resolve_package(p_items,p_domain_code,p_latitude,p_longitude,p_location_id,p_limit);
 end if;
 if jsonb_typeof(p_items) is distinct from 'array'
  or jsonb_typeof(p_original_items) is distinct from 'array'
 then raise exception 'Pilot package requires input and original arrays'; end if;
 total:=jsonb_array_length(p_items);
 if total not between 1 and 30 or jsonb_array_length(p_original_items)<>total
 then raise exception 'Pilot original/input item count differs'; end if;
 if exists(select 1 from jsonb_array_elements(p_items) x
   where jsonb_typeof(x) is distinct from 'string' or char_length(trim(x#>>'{}')) not between 1 and 200)
  or exists(select 1 from jsonb_array_elements(p_original_items) x
   where jsonb_typeof(x) is distinct from 'string' or char_length(trim(x#>>'{}')) not between 1 and 200)
 then raise exception 'Pilot entries must retain valid strings and source lengths'; end if;
 -- Use the original item boundary even if a later RPC filters/reorders data.
 select jsonb_agg(jsonb_build_object('index',x.ordinality,'input',x.value,
  'normalized_query',core.normalized_text(x.value),'status','ambiguous',
  'reason_code','ambiguous_service','candidates','[]'::jsonb) order by x.ordinality)
 into fallback_items from jsonb_array_elements_text(p_original_items) with ordinality x(value,ordinality);
 fallback_payload:=jsonb_build_object('items',fallback_items,'offers','[]'::jsonb,
  'ocr_corrections','[]'::jsonb,'imaging_alignment_required',true);
 -- Cardinality alone cannot prove that input i was derived from original i.
 -- Permit only the published parser's bounded fasting suffix extraction.
 -- Compare actual text, not a token set that could hide qualifier movement.
 preparation_suffix:='[[:space:]]+((en[[:space:]]+)?ayun(o|as)(([[:space:]]+de)?[[:space:]]+[0-9]+([.,][0-9]+)?[[:space:]]*(h(rs?)?|horas?))?)[[:space:]]*$';
 if exists(select 1 from jsonb_array_elements_text(p_items) with ordinality x(value,n)
  where trim(x.value) is distinct from trim(p_original_items->>(x.n::integer-1))
   and trim(x.value) is distinct from trim(regexp_replace(
    trim(p_original_items->>(x.n::integer-1)),preparation_suffix,'','i')))
 then return fallback_payload; end if;
 if p_from_ocr then
  source:=public.api_resolve_ocr_package(p_items,p_domain_code,p_latitude,p_longitude,p_location_id,p_limit);
 else
  source:=public.api_resolve_package(p_items,p_domain_code,p_latitude,p_longitude,p_location_id,p_limit);
 end if;
 if jsonb_typeof(source) is distinct from 'object' then return fallback_payload; end if;
 if jsonb_typeof(source->'items') is distinct from 'array' then return source || fallback_payload; end if;
 if jsonb_array_length(source->'items')<>total then return source || fallback_payload; end if;
 if exists(select 1 from jsonb_array_elements(source->'items') x
  where jsonb_typeof(x->'index') is distinct from 'number'
   or coalesce(x->>'index','') !~ '^[1-9][0-9]?$')
 then return source || fallback_payload; end if;
 select array_agg((x.value->>'index')::integer order by x.ordinality) into actual_indices
 from jsonb_array_elements(source->'items') with ordinality x(value,ordinality);
 select array_agg(n order by n) into expected_indices from generate_series(1,total) n;
 if actual_indices is distinct from expected_indices then return source || fallback_payload; end if;
 -- OCR returns its pre-correction input; non-OCR returns the trimmed input.
 -- Check both ordinal and input identity before reading any original by index.
 if exists(select 1 from jsonb_array_elements(source->'items') x
  where jsonb_typeof(x->'input') is distinct from 'string'
   or trim(x->>'input') is distinct from trim(p_items->>((x->>'index')::integer-1))
   or jsonb_typeof(x->'candidates') is distinct from 'array')
 then return source || fallback_payload; end if;
 if exists(select 1 from jsonb_array_elements(source->'items') x
  cross join lateral jsonb_array_elements(x->'candidates') c
  where jsonb_typeof(c) is distinct from 'object'
   or coalesce(c->>'service_id','') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
 then return source || fallback_payload; end if;
 -- A projection/posture written alone may qualify an adjacent imaging order.
 -- Preserve it, but never silently confirm only the first part of that order.
 fragment_pattern:='^(pa|ap|lat|lateral|oblicua|oblicuo|axial|tangencial|posteroanterior|anteroposterior|postero|antero|anterior|posterior|proyeccion|proyecciones|vista|vistas|en|de|con|pie|bipedestacion|decubito|supino|prono|una|un|dos|[0-9]+)( (pa|ap|lat|lateral|oblicua|oblicuo|axial|tangencial|posteroanterior|anteroposterior|postero|antero|anterior|posterior|proyeccion|proyecciones|vista|vistas|en|de|con|pie|bipedestacion|decubito|supino|prono|derecha|derecho|izquierda|izquierdo|y|e|una|un|dos|[0-9]+))*$';
 select exists(select 1 from jsonb_array_elements_text(p_original_items) x
  where core.normalized_text(x.value) ~ fragment_pattern) into projection_fragment;
 for item in select value from jsonb_array_elements(source->'items') loop
  index_value:=(item->>'index')::integer;
  original:=p_original_items->>(index_value-1);
  item:=item || jsonb_build_object('input',original,'original_input',original,
   'resolver_input',p_items->>(index_value-1));
  if core.normalized_text(original) ~ fragment_pattern then
   item:=item || jsonb_build_object('status','ambiguous','reason_code','ambiguous_service','candidates','[]'::jsonb);
  else
   select exists(select 1 from jsonb_array_elements(coalesce(item->'candidates','[]'::jsonb)) c
    join health.imaging_protocols p on p.service_id=(c.value->>'service_id')::uuid)
   into candidate_has_protocol;
   if coalesce((health.parse_rx_chest_request(original)->>'scope')::boolean,false) or candidate_has_protocol then
    kept:='[]'::jsonb;
    requires_review:=projection_fragment or item->>'status' is distinct from 'resolved';
    for candidate in select value from jsonb_array_elements(coalesce(item->'candidates','[]'::jsonb)) loop
     gate:=health.rx_protocol_gate(original,(candidate->>'service_id')::uuid);
     if gate='reject' then continue; end if;
     if gate='clarify' or candidate->>'resolution_status' is distinct from 'resolved' then
      requires_review:=true;
      candidate:=candidate || jsonb_build_object('resolution_status','ambiguous','offers','[]'::jsonb);
     end if;
     kept:=kept || jsonb_build_array(candidate);
    end loop;
    state:=case when jsonb_array_length(kept)=0 then 'no_match'
     when requires_review or jsonb_array_length(kept)<>1 then 'ambiguous' else 'resolved' end;
    if state<>'resolved' then
     select coalesce(jsonb_agg(value || jsonb_build_object('resolution_status','ambiguous','offers','[]'::jsonb)),
      '[]'::jsonb) into kept from jsonb_array_elements(kept);
    end if;
    item:=item || jsonb_build_object('input',original,'status',state,'candidates',kept,
     'reason_code',case when state='no_match' then 'service_not_found'
      when state<>'resolved' then 'ambiguous_service' else item->>'reason_code' end);
   end if;
  end if;
  if item->>'status'='resolved' and jsonb_array_length(item->'candidates')=1
   and item->'candidates'->0->>'resolution_status'='resolved'
  then allowed_indices:=array_append(allowed_indices,index_value);
  else
   -- Includes projection fragments and malformed prior resolved states.
   item:=item || jsonb_build_object('offers','[]'::jsonb,'candidates',coalesce((
    select jsonb_agg(value || jsonb_build_object('offers','[]'::jsonb,
     'resolution_status','ambiguous')) from jsonb_array_elements(item->'candidates')),'[]'::jsonb));
   if item->>'status'='resolved' then
    item:=item || jsonb_build_object('status','ambiguous','reason_code','ambiguous_service');
   end if;
  end if;
  output:=output || jsonb_build_array(item);
 end loop;
 return source || jsonb_build_object('items',output,'offers',coalesce((
  select jsonb_agg(o.value order by o.n) from jsonb_array_elements(
   case when jsonb_typeof(source->'offers')='array' then source->'offers' else '[]'::jsonb end)
   with ordinality o(value,n)
  where exists(select 1 from jsonb_array_elements(output) i
   where (i->>'index')::integer=any(allowed_indices)
    and o.value->>'item_index'=i->>'index'
    and o.value->>'item_id'=i->'candidates'->0->>'service_id')), '[]'::jsonb));
end $$;
revoke all on function public.api_resolve_rx_chest_package_pilot_v2(jsonb,text,double precision,double precision,uuid,integer,boolean,jsonb)
 from public,anon,authenticated;
grant execute on function public.api_resolve_rx_chest_package_pilot_v2(jsonb,text,double precision,double precision,uuid,integer,boolean,jsonb)
 to service_role;

revoke all on function catalog.resolve_items_v6_before_panels(text,text,uuid,integer) from public,anon,authenticated,service_role;
grant execute on function catalog.resolve_items_v6_before_panels(text,text,uuid,integer) to service_role;
revoke all on function catalog.resolve_items_v7(text,text,uuid,integer) from public,anon,authenticated,service_role;
grant execute on function catalog.resolve_items_v7(text,text,uuid,integer) to service_role;
revoke all on function health.assert_rx_protocol_integrity(uuid) from public,anon,authenticated,service_role;
revoke all on function health.check_rx_protocol_integrity() from public,anon,authenticated,service_role;
revoke all on function health.panel_current_state(uuid) from public,anon,authenticated,service_role;
grant execute on function health.panel_current_state(uuid) to service_role;
revoke all on function health.panel_query_is_compatible(text,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function health.panel_query_is_compatible(text,uuid,uuid) to service_role;
revoke all on function health.parse_rx_chest_request(text) from public,anon,authenticated,service_role;
grant execute on function health.parse_rx_chest_request(text) to service_role;
revoke all on function health.preserve_panel_audit_anchor() from public,anon,authenticated,service_role;
revoke all on function health.preserve_rx_protocol_review() from public,anon,authenticated,service_role;
revoke all on function health.prevent_panel_manifest_mutation() from public,anon,authenticated,service_role;
revoke all on function health.prevent_rx_protocol_truncate() from public,anon,authenticated,service_role;
revoke all on function health.rx_protocol_definition(uuid) from public,anon,authenticated,service_role;
grant execute on function health.rx_protocol_definition(uuid) to service_role;
revoke all on function health.rx_protocol_gate(text,uuid) from public,anon,authenticated,service_role;
grant execute on function health.rx_protocol_gate(text,uuid) to service_role;
revoke all on function health.validate_imaging_protocol_service() from public,anon,authenticated,service_role;
revoke all on function health.validate_panel_manifest_insert() from public,anon,authenticated,service_role;
revoke all on function health.validate_panel_quarantine_insert() from public,anon,authenticated,service_role;
revoke all on function public.api_resolve_rx_chest_package_pilot_v2(jsonb,text,double precision,double precision,uuid,integer,boolean,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.api_resolve_rx_chest_package_pilot_v2(jsonb,text,double precision,double precision,uuid,integer,boolean,jsonb) to service_role;
revoke all on function public.api_resolve_rx_chest_pilot(text,text,double precision,double precision,uuid,integer) from public,anon,authenticated,service_role;
grant execute on function public.api_resolve_rx_chest_pilot(text,text,double precision,double precision,uuid,integer) to service_role;
revoke all on function public.api_search_before_panels(text,text,double precision,double precision,uuid,integer) from public,anon,authenticated,service_role;
do $permissions_guard$ begin
 if exists(select 1 from jsonb_array_elements('[{"schema": "catalog", "name": "resolve_items", "arguments": "p_query text, p_domain_code text, p_provider_brand_id uuid, p_limit integer", "definition_md5": "067b7a2fe0826ccaa48ece0a5dfd8d1d", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "catalog.resolve_items"}, {"schema": "catalog", "name": "resolve_items_v2", "arguments": "p_query text, p_domain_code text, p_provider_brand_id uuid, p_limit integer", "definition_md5": "7b0be9fb9a16bebd289e5e9b3ed71f05", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "catalog.resolve_items_v2"}, {"schema": "catalog", "name": "resolve_items_v3", "arguments": "p_query text, p_domain_code text, p_provider_brand_id uuid, p_limit integer", "definition_md5": "04a16e148fb6d3ee0838890818bdc6e9", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "catalog.resolve_items_v3"}, {"schema": "catalog", "name": "resolve_items_v4", "arguments": "p_query text, p_domain_code text, p_provider_brand_id uuid, p_limit integer", "definition_md5": "21964858bf258a1b49e83e93f371cf01", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "catalog.resolve_items_v4"}, {"schema": "catalog", "name": "resolve_items_v5", "arguments": "p_query text, p_domain_code text, p_provider_brand_id uuid, p_limit integer", "definition_md5": "32830b96541e6d803749987455572e9a", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "catalog.resolve_items_v5"}, {"schema": "catalog", "name": "resolve_items_v6", "arguments": "p_query text, p_domain_code text, p_provider_brand_id uuid, p_limit integer", "definition_md5": "62e3527a60897b7d01323e7bd83f3453", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "catalog.resolve_items_v6"}, {"schema": "catalog", "name": "search_items", "arguments": "p_query text, p_domain_code text, p_provider_brand_id uuid, p_limit integer", "definition_md5": "b3a7f87d485dc5a5a711e2b664c7a720", "acl": "{postgres=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "catalog.search_items"}, {"schema": "core", "name": "normalized_text", "arguments": "input text", "definition_md5": "316b789d77ac228427fc69104e65f83e", "acl": "{postgres=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "core.normalized_text"}, {"schema": "public", "name": "api_provider_detail", "arguments": "p_provider_brand_id uuid", "definition_md5": "488896bedef266484aff707065a55815", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, core, catalog, supply, gis"], "full_name": "public.api_provider_detail"}, {"schema": "public", "name": "api_resolve_ocr_package", "arguments": "p_items jsonb, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "99f775a4411bfde5a71b23f7cb26f094", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, core, supply, geo, gis, extensions"], "full_name": "public.api_resolve_ocr_package"}, {"schema": "public", "name": "api_resolve_ocr_package_internal", "arguments": "p_items jsonb, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "a4fb23e946b4b3b9aa079ffb1ad60b3c", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, core, supply, geo, gis, extensions"], "full_name": "public.api_resolve_ocr_package_internal"}, {"schema": "public", "name": "api_resolve_package", "arguments": "p_items jsonb, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "930f9943ec8deeb2eb26d1b23377bf21", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, core, supply, geo, gis, extensions"], "full_name": "public.api_resolve_package"}, {"schema": "public", "name": "api_resolve_package_internal", "arguments": "p_items jsonb, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "d009d7d8185bcbdd33d259cd6e46560e", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, supply"], "full_name": "public.api_resolve_package_internal"}, {"schema": "public", "name": "api_resolve_package_links_legacy", "arguments": "p_items jsonb, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "a08145ff11e793982e335058c88060f1", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, core, supply, geo, gis, extensions"], "full_name": "public.api_resolve_package_links_legacy"}, {"schema": "public", "name": "api_resolve_package_unfiltered", "arguments": "p_items jsonb, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "bc2f82070699884ff65c703cb967587a", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, core, supply, geo, gis, extensions"], "full_name": "public.api_resolve_package_unfiltered"}, {"schema": "public", "name": "api_resolve_search", "arguments": "p_query text, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "89d6a3efb3e43daa736d947eca7406fe", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, core, supply, geo, gis, extensions"], "full_name": "public.api_resolve_search"}, {"schema": "public", "name": "api_resolve_search_unfiltered", "arguments": "p_query text, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "0f1756738cad4540cf9835597dae8e3c", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public"], "full_name": "public.api_resolve_search_unfiltered"}, {"schema": "public", "name": "api_resolve_search_v2", "arguments": "p_query text, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "52efd4b565a02daebc8b40660e440db1", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, health, core, supply, geo, gis, extensions"], "full_name": "public.api_resolve_search_v2"}, {"schema": "public", "name": "api_resolve_search_v3", "arguments": "p_query text, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "32fcc4566f9ceaf9a2b360f45aa5c225", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public"], "full_name": "public.api_resolve_search_v3"}, {"schema": "public", "name": "api_resolve_search_v4", "arguments": "p_query text, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "eb2a8f5d7ea847ae74892fb8210eaf2c", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, supply, core"], "full_name": "public.api_resolve_search_v4"}, {"schema": "public", "name": "api_resolve_search_v4_links_legacy", "arguments": "p_query text, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "d831c25cf7024a846af2955a7a3c3e1a", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public"], "full_name": "public.api_resolve_search_v4_links_legacy"}, {"schema": "public", "name": "api_search", "arguments": "p_query text, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "74eef2e92ac940191921071f776aae60", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, supply"], "full_name": "public.api_search"}, {"schema": "public", "name": "api_search_links_legacy_v1", "arguments": "p_query text, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "5ee173805303c231132deb9fb96fdb54", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, core, supply, geo, gis, extensions"], "full_name": "public.api_search_links_legacy_v1"}, {"schema": "public", "name": "api_search_scoped_v1", "arguments": "p_query text, p_domain_code text, p_latitude double precision, p_longitude double precision, p_location_id uuid, p_limit integer", "definition_md5": "b0bdd0cfcb3c0d8b2bc717f24b615d40", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, core, supply, geo, gis, extensions"], "full_name": "public.api_search_scoped_v1"}, {"schema": "public", "name": "api_service_detail", "arguments": "p_service_id uuid", "definition_md5": "9720e801b6c0c9cad8c0f265ceef73e6", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": true, "configuration": ["search_path=public, catalog, health, supply, core"], "full_name": "public.api_service_detail"}, {"schema": "public", "name": "apply_package_confidence_guard", "arguments": "p_payload jsonb", "definition_md5": "cbbf64d963a748ac293630c8615b1da0", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "public.apply_package_confidence_guard"}, {"schema": "public", "name": "apply_resolution_confidence_guard", "arguments": "p_payload jsonb", "definition_md5": "62a030588affbee2f92dfc566687ec7a", "acl": "{postgres=X/postgres,service_role=X/postgres}", "owner": "postgres", "security_definer": false, "configuration": ["search_path=pg_catalog"], "full_name": "public.apply_resolution_confidence_guard"}]'::jsonb) r(value)
 where not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname=r.value->>'schema' and p.proname=r.value->>'name'
 and pg_get_function_identity_arguments(p.oid)=r.value->>'arguments'
 and (p.proacl is null)=((r.value->>'acl') is null)
 and array(select a::text from unnest(p.proacl) a order by a::text)
   =array(select a::text from unnest((r.value->>'acl')::aclitem[]) a order by a::text)
 and pg_get_userbyid(p.proowner)=r.value->>'owner'
 and p.prosecdef=(r.value->>'security_definer')::boolean
 and coalesce(to_jsonb(p.proconfig),'null'::jsonb)=r.value->'configuration' and (r.value->>'full_name' in ('catalog.resolve_items_v3','catalog.resolve_items_v4','catalog.resolve_items_v6','catalog.search_items','public.api_provider_detail','public.api_resolve_package_links_legacy','public.api_resolve_search_v4','public.api_resolve_search_v4_links_legacy','public.api_search','public.api_service_detail') or md5(pg_get_functiondef(p.oid))=r.value->>'definition_md5'))) then raise exception 'Existing permissions, configuration or unchanged dependency body changed'; end if;
end $permissions_guard$;
do $new_permissions_guard$ begin
 if exists(select 1 from jsonb_array_elements('[{"name": "catalog.resolve_items_v6_before_panels", "signature": "catalog.resolve_items_v6_before_panels(text,text,uuid,integer)", "service_role": true}, {"name": "catalog.resolve_items_v7", "signature": "catalog.resolve_items_v7(text,text,uuid,integer)", "service_role": true}, {"name": "health.assert_rx_protocol_integrity", "signature": "health.assert_rx_protocol_integrity(uuid)", "service_role": false}, {"name": "health.check_rx_protocol_integrity", "signature": "health.check_rx_protocol_integrity()", "service_role": false}, {"name": "health.panel_current_state", "signature": "health.panel_current_state(uuid)", "service_role": true}, {"name": "health.panel_query_is_compatible", "signature": "health.panel_query_is_compatible(text,uuid,uuid)", "service_role": true}, {"name": "health.parse_rx_chest_request", "signature": "health.parse_rx_chest_request(text)", "service_role": true}, {"name": "health.preserve_panel_audit_anchor", "signature": "health.preserve_panel_audit_anchor()", "service_role": false}, {"name": "health.preserve_rx_protocol_review", "signature": "health.preserve_rx_protocol_review()", "service_role": false}, {"name": "health.prevent_panel_manifest_mutation", "signature": "health.prevent_panel_manifest_mutation()", "service_role": false}, {"name": "health.prevent_rx_protocol_truncate", "signature": "health.prevent_rx_protocol_truncate()", "service_role": false}, {"name": "health.rx_protocol_definition", "signature": "health.rx_protocol_definition(uuid)", "service_role": true}, {"name": "health.rx_protocol_gate", "signature": "health.rx_protocol_gate(text,uuid)", "service_role": true}, {"name": "health.validate_imaging_protocol_service", "signature": "health.validate_imaging_protocol_service()", "service_role": false}, {"name": "health.validate_panel_manifest_insert", "signature": "health.validate_panel_manifest_insert()", "service_role": false}, {"name": "health.validate_panel_quarantine_insert", "signature": "health.validate_panel_quarantine_insert()", "service_role": false}, {"name": "public.api_resolve_rx_chest_package_pilot_v2", "signature": "public.api_resolve_rx_chest_package_pilot_v2(jsonb,text,double precision,double precision,uuid,integer,boolean,jsonb)", "service_role": true}, {"name": "public.api_resolve_rx_chest_pilot", "signature": "public.api_resolve_rx_chest_pilot(text,text,double precision,double precision,uuid,integer)", "service_role": true}, {"name": "public.api_search_before_panels", "signature": "public.api_search_before_panels(text,text,double precision,double precision,uuid,integer)", "service_role": false}]'::jsonb) r(value)
 where not exists(select 1 from pg_proc p where p.oid=to_regprocedure(r.value->>'signature')
  and pg_get_userbyid(p.proowner)='postgres'
  and not exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
   where a.grantee<>p.proowner and
    (a.grantee<>(select oid from pg_roles where rolname='service_role')
     or not (r.value->>'service_role')::boolean or a.is_grantable))))
 then raise exception 'Unexpected permissions on a new helper'; end if;
end $new_permissions_guard$;

rollback;
