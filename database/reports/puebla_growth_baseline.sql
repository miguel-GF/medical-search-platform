-- Read-only operational baseline; excludes patient inputs, user IDs and secrets.
select jsonb_build_object(
  'database_version', current_setting('server_version'),
  'database_size_bytes', pg_database_size(current_database()),
  'migration_count', (select count(*) from supabase_migrations.schema_migrations),
  'provider_brands', (select count(*) from core.provider_brands),
  'provider_locations', (select count(*) from core.provider_locations),
  'active_catalog_items', (select count(*) from catalog.items where status='active'),
  'active_offers', (select count(*) from supply.offers where status='active'),
  'pending_crawler_rows', (
    select count(*) from ingest.normalization_runs nr
    where nr.input_type='crawler' and nr.status in ('pending','ambiguous','no_match')
      and not exists(select 1 from ingest.normalization_decisions nd
                     where nd.normalization_run_id=nr.id and
                     nd.decision_type in ('automatic','manual','ambiguous','rejected','no_match'))
  ),
  'sources', (select jsonb_agg(jsonb_build_object(
    'id',id,'name',name,'source_type',source_type,'usage_policy_status',usage_policy_status,'status',status
  ) order by name) from ingest.sources),
  'review_items', (select jsonb_agg(to_jsonb(s) || jsonb_build_object('names',(
    select jsonb_agg(n.name order by n.is_primary desc,n.locale) from catalog.item_names n where n.item_id=s.catalog_item_id
  ))) from health.services s where s.catalog_item_id in (
    '831441e7-9e66-5b4e-8032-b5911b6875ea', '04e00006-ec41-5a94-987c-c1de64c3c258',
    '55bf636e-7149-5574-8bcb-d7e51974aaae', '3e080173-1b5f-503c-a324-bd65cf092031',
    '00000000-0000-0000-0000-000000001111', 'b3ec7d1e-9e20-55ec-9bfc-d72c0836c7dd'
  ))
) as baseline;
