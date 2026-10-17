-- Read-only comparison of free text with the strict resolver and a spelling
-- lookup equivalent to the proposed (not-yet-applied) suggestion RPC.
-- Does not call the HTTP route or record patient search telemetry.
with phrases(phrase) as (
  values ('metieron sangre'), ('sangre'), ('biometria hematica'), ('biometira hematica')
)
select p.phrase,
       coalesce((
         select jsonb_agg(jsonb_build_object(
           'name', r.display_name, 'method', r.match_method,
           'status', r.resolution_status
         ) order by r.result_rank)
         from catalog.resolve_items_v6(p.phrase, 'health_diagnostics', null::uuid, 5) r
       ), '[]'::jsonb) as strict_matches,
       coalesce((
         select jsonb_agg(jsonb_build_object(
           'name', names.name,
           'score', extensions.similarity(n.normalized_name, core.normalized_text(p.phrase))
         ) order by extensions.similarity(n.normalized_name, core.normalized_text(p.phrase)) desc)
         from catalog.item_names n
         join catalog.items i on i.id = n.item_id and i.status = 'active'
         join health.services hs on hs.catalog_item_id = i.id
         join catalog.item_names names on names.item_id = i.id
           and names.is_primary and names.locale = 'es-MX'
         where n.locale = 'es-MX'
           and extensions.similarity(n.normalized_name, core.normalized_text(p.phrase)) >= 0.55
       ), '[]'::jsonb) as spelling_suggestions
from phrases p
order by p.phrase;
