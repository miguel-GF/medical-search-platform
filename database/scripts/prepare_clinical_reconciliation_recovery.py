"""Prepare guarded recovery SQL only; never connect to or mutate a database."""
import argparse
import json
from pathlib import Path

import clinical_candidate_evaluation as ev


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--folder', required=True, type=Path)
    parser.add_argument('--output-name', default='recovery-PREPARED-DO-NOT-AUTO-RUN.sql')
    args = parser.parse_args()
    folder = ev.within_artifacts(args.folder)
    assert Path(args.output_name).name == args.output_name and args.output_name.endswith('.sql')
    prep = json.loads((folder / 'preparation.json').read_bytes())
    inspected = json.loads((ev.ROOT / 'collectors/artifacts/clinical-core-reconciled-local-20261023/reconciled-v1-runtime-pg17/independent-local-inspection.json').read_bytes())
    sql = "-- PREPARED RECOVERY ONLY. Do not replay a failed deployment.\n-- Inspect current state first; apply as a new migration after recovery authorization.\nbegin;\nset local lock_timeout='250ms';\nset local statement_timeout='10s';\n"
    sql += "do $guard$ declare a record; begin select * into strict a from audit.events where request_id='canonical-reconciliation-20261023' and action='catalog.clinical_reconciliation_approved';\n"
    ids = ','.join(ev.q(c['item_id']) + '::uuid' for c in prep['imaging_changes'])
    sql += "if (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]'::jsonb) from health.service_anatomy t where service_id in (" + ids + ")) is distinct from (select coalesce(jsonb_agg(x order by x::text),'[]'::jsonb) from jsonb_array_elements(a.after_data->'anatomy') x) then raise exception 'Anatomy changed after release'; end if;\n"
    for row in prep['imaging_changes']:
        item = ev.q(row['item_id']) + '::uuid'
        sql += "if (select to_jsonb(t) from health.services t where catalog_item_id=" + item + ") is distinct from (select x from jsonb_array_elements(a.after_data->'services') x where x->>'catalog_item_id'=" + ev.q(row['item_id']) + ") then raise exception 'Service changed after release'; end if;\n"
    for lex in prep['positive_component_lexicon_ids']:
        sql += "if (select to_jsonb(t) from health.query_lexicon t where id=" + ev.q(lex) + "::uuid) is distinct from (select x from jsonb_array_elements(a.after_data->'lexicon') x where x->>'id'=" + ev.q(lex) + ") then raise exception 'Lexicon changed after release'; end if;\n"
    for name in ['resolve_items', 'resolve_items_v3', 'resolve_items_v4', 'resolve_items_v6']:
        sql += "if md5(pg_get_functiondef(" + ev.q('catalog.' + name + '(text,text,uuid,integer)') + "::regprocedure)) <> " + ev.q(inspected['function_md5_after']['catalog.' + name]) + " then raise exception 'Resolver changed after release'; end if;\n"
    sql += 'end $guard$;\n'
    for row in prep['imaging_changes']:
        sql += 'update health.services set ' + ','.join(k + '=' + ev.q(v) for k, v in row['before'].items()) + ' where catalog_item_id=' + ev.q(row['item_id']) + '::uuid;\n'
        if row['anatomy_code_added']:
            sql += "delete from health.service_anatomy where service_id=" + ev.q(row['item_id']) + "::uuid and role='target' and laterality_override is null and anatomical_site_id=(select id from health.anatomical_sites where code=" + ev.q(row['anatomy_code_added']) + ");\n"
    sql += "update health.query_lexicon set attribute_type='service_type',attribute_value='__blocked_analyte_variant__' where id in (" + ','.join(ev.q(x) + '::uuid' for x in prep['positive_component_lexicon_ids']) + ');\n'
    sql += (folder / 'original-functions.sql').read_text(encoding='utf-8') + '\n'
    sql += "insert into audit.events(actor_type,action,entity_schema,entity_table,request_id,metadata) values ('system','catalog.clinical_reconciliation_reverted','catalog','clinical_resolver','canonical-reconciliation-recovery-20261023',jsonb_build_object('original_request','canonical-reconciliation-20261023'));\n-- Retain original applied migration and audit history. Register this recovery as a NEW migration.\ncommit;\n"
    ev.write_new(folder / args.output_name, sql)
    print(json.dumps({'recovery_prepared': True, 'remote_writes': 0}))


if __name__ == '__main__':
    main()
