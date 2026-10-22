select jsonb_build_object(
 'functions',(select jsonb_agg(jsonb_build_object(
   'schema',n.nspname,'name',p.proname,'arguments',pg_get_function_identity_arguments(p.oid),
   'definition',pg_get_functiondef(p.oid),'acl',p.proacl::text,'owner',pg_get_userbyid(p.proowner),
   'security_definer',p.prosecdef,'configuration',p.proconfig)
   order by n.nspname,p.proname,pg_get_function_identity_arguments(p.oid))
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname in ('public','catalog','health','core','ingest') and p.prokind='f'),
 'relations',(select jsonb_agg(jsonb_build_object('schema',n.nspname,'name',c.relname,
   'kind',c.relkind,'owner',pg_get_userbyid(c.relowner),'acl',c.relacl::text,
   'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity)
   order by n.nspname,c.relname) from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname in ('public','catalog','health','core','ingest') and c.relkind in ('r','p','v','m')),
 'triggers',(select jsonb_agg(jsonb_build_object('schema',n.nspname,'table',c.relname,
   'name',t.tgname,'enabled',t.tgenabled,'definition',pg_get_triggerdef(t.oid,true))
   order by n.nspname,c.relname,t.tgname) from pg_trigger t join pg_class c on c.oid=t.tgrelid
   join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','catalog','health','core','ingest')),
 'policies',(select jsonb_agg(to_jsonb(p) order by p.schemaname,p.tablename,p.policyname)
   from pg_policies p where p.schemaname in ('public','catalog','health','core','ingest')),
 'schemas',(select jsonb_agg(jsonb_build_object('name',nspname,'owner',pg_get_userbyid(nspowner),
   'acl',nspacl::text) order by nspname) from pg_namespace where nspname in ('public','catalog','health','core','ingest')),
 'protected_data',jsonb_build_object('core.provider_brands', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from core.provider_brands) t) hashed),
'core.provider_locations', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from core.provider_locations) t) hashed),
'core.location_external_ids', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from core.location_external_ids) t) hashed),
'catalog.items', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from catalog.items) t) hashed),
'catalog.item_names', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from catalog.item_names) t) hashed),
'catalog.item_aliases', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from catalog.item_aliases) t) hashed),
'health.services', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from health.services) t) hashed),
'health.lab_service_definitions', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from health.lab_service_definitions) t) hashed),
'health.service_components', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from health.service_components) t) hashed),
'health.service_anatomy', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from health.service_anatomy) t) hashed),
'health.anatomical_sites', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from health.anatomical_sites) t) hashed),
'health.specimen_types', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from health.specimen_types) t) hashed),
'health.service_specimens', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from health.service_specimens) t) hashed),
'health.service_methods', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from health.service_methods) t) hashed),
'supply.offers', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from supply.offers) t) hashed),
'supply.offer_scopes', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from supply.offer_scopes) t) hashed),
'supply.price_versions', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from supply.price_versions) t) hashed),
'supply.offer_links', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from supply.offer_links) t) hashed),
'supply.availability_current', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from supply.availability_current) t) hashed),
'ingest.sources', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from ingest.sources) t) hashed),
'public_source_raw', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select rr.* from ingest.raw_records rr where exists(select 1 from ingest.sources s where s.id=rr.source_id and s.source_type in ('government','provider_official','public_website'))) t) hashed),
'crawler_runs', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from ingest.normalization_runs where input_type='crawler') t) hashed),
'crawler_decisions', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select nd.* from ingest.normalization_decisions nd where exists(select 1 from ingest.normalization_runs nr where nr.id=nd.normalization_run_id and nr.input_type='crawler')) t) hashed),
'crawler_candidates', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select nc.* from ingest.normalization_candidates nc where exists(select 1 from ingest.normalization_runs nr where nr.id=nc.normalization_run_id and nr.input_type='crawler')) t) hashed),
'public_source_observations', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select o.* from ingest.source_observations o where exists(select 1 from ingest.sources s where s.id=o.source_id and s.source_type in ('government','provider_official','public_website'))) t) hashed),
'business_review_audits', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from audit.events where action in ('catalog.alias_evidence_review','catalog.concept_evidence_review','catalog.imaging_protocol_review','provider.identity_evidence_review','catalog.panel_composition_review','catalog.panel_composition_quarantine')) t) hashed),
'migrations', (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (select * from supabase_migrations.schema_migrations) t) hashed))) as snapshot;
