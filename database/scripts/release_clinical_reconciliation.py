"""Pinned, single-attempt release of the explicitly authorized 23-Oct repair.

Prepare is read-only. Evaluate ends in ROLLBACK. Deploy requires that exact
evaluation to have restored state and passed all specified clinical controls.
"""
import argparse
import json
from pathlib import Path
import sys
from uuid import uuid4

import clinical_candidate_evaluation as ev
from run_local_review_queue import query

ROOT = ev.ROOT
PROPOSAL = ROOT / 'docs/proposals/20261023-canonical-reconciliation'
EXPORT = ROOT / 'collectors/artifacts/clinical-core-reconciled-local-20261023'
VERSION = '20261023160000'
NAME = 'clinical_identity_canonical_reconciliation'
APPROVAL = '23-Oct-2026: como van ya subieron todo al ambiente productivo recuerda q ahora local y produccion es lo mismo no hay tema tienes permiso; bounded to the described four-function canonical reconciliation, not the paused expansion.'
HELPER_SHA = 'a3642b3e34bcafc25007752dbae95fc1ba3011d6e90f8aab0dc5fd41f350e927'


def load(path):
    return json.loads(path.read_bytes())


def expanded_snapshot():
    base = ev.snapshot_sql().strip().rstrip(';')
    extras = ['health.query_lexicon', 'catalog.item_identifiers', 'catalog.item_descriptions',
              'catalog.disambiguation_terms', 'catalog.disambiguation_candidates', 'catalog.domains']
    pairs = []
    for table in extras:
        pairs.append(ev.q(table) + ", (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(h,'' order by h),''))) from (select md5(to_jsonb(t)::text) h from " + table + ' t) x)')
    return 'with original as (' + base + ') select jsonb_set(snapshot,\'{protected_data}\',snapshot->\'protected_data\' || jsonb_build_object(' + ','.join(pairs) + ')) as snapshot from original;\n'


def expression(label, kind):
    args = ev.q(label) + ",'health_diagnostics',null"
    if kind == 'core':
        return "coalesce((select jsonb_agg(to_jsonb(r)) from catalog.resolve_items_v6(" + args + ",10) r),'[]'::jsonb)"
    args += ',null,null,10'
    return "jsonb_build_object('search',public.api_resolve_search(" + args + "),'package',public.api_resolve_package(jsonb_build_array(" + ev.q(label) + "),'health_diagnostics',null,null,null,10))"


def prepare(folder):
    folder = ev.within_artifacts(folder)
    folder.mkdir(exist_ok=False, parents=True)
    preparation = load(PROPOSAL / 'preparation.json')
    metadata = load(EXPORT / 'metadata.json')
    names = load(EXPORT / 'catalog.item_names.json')
    ids = [c['item_id'] for c in preparation['imaging_changes']]
    lexids = preparation['positive_component_lexicon_ids']
    with ev.client() as db:
        baseline = query(db, ev.PROJECT, expanded_snapshot())[0]['snapshot']
    ev.write_new(folder / 'baseline.json', baseline)
    ev.write_new(folder / 'snapshot.sql', expanded_snapshot())
    changed = ['resolve_items', 'resolve_items_v3', 'resolve_items_v4', 'resolve_items_v6']
    original = [f for f in metadata['functions'] if f['name'] in changed]
    assert len(original) == 4
    guard = ["do $guard$ begin"]
    for function in original:
        signature = 'catalog.' + function['name'] + '(text,text,uuid,integer)'
        live = [f for f in baseline['functions'] if f['schema'] == 'catalog' and f['name'] == function['name']]
        assert len(live) == 1 and ev.sha(live[0]['definition'].encode()) == ev.sha(function['definition'].encode()), 'Function baseline drift'
        guard.append("if md5(pg_get_functiondef(" + ev.q(signature) + "::regprocedure)) <> " + ev.q(function['md5']) + " then raise exception 'Function changed since preparation'; end if;")
    for table, key, selected in [('health.services', 'catalog_item_id', ids), ('health.query_lexicon', 'id', lexids)]:
        for row in load(EXPORT / (table + '.json')):
            if row[key] in selected:
                guard.append('if (select to_jsonb(t) from ' + table + ' t where ' + key + '=' + ev.q(row[key]) + '::uuid) is distinct from ' + ev.q(json.dumps(row)) + "::jsonb then raise exception 'Reviewed row changed'; end if;")
    guard.append("if exists(select 1 from health.service_anatomy where service_id in (" + ','.join(ev.q(x) + '::uuid' for x in ids if next(c for c in preparation['imaging_changes'] if c['item_id'] == x)['anatomy_code_added']) + ")) then raise exception 'Anatomy baseline changed'; end if; end $guard$;")
    guard = '\n'.join(guard) + '\n'
    local = (PROPOSAL / 'reconciliation-LOCAL-ONLY.sql').read_text(encoding='utf-8')
    body = '\n'.join(local.splitlines()[3:-1]) + '\n'
    assert 'local_evaluation' not in body and 'commit;' not in body.lower()
    for name in changed[1:]:
        raw = (ROOT / 'docs/proposals/20261023-explicit-identity' / ('catalog-' + name + '-PROPOSED.sql')).read_text(encoding='utf-8')
        body += raw[raw.index('CREATE OR REPLACE FUNCTION'):].strip().rstrip(';') + ';\n'
    controls = load(PROPOSAL / 'controls.json')
    for row in names:
        if row['is_primary'] and row['item_id'] in ids:
            controls.append({'query': row['name'], 'expected_item_ids': [row['item_id']]})
    cases = [dict(c, kind='core') for c in controls]
    public_labels = [c['name'] for c in preparation['imaging_changes']] + ['t3 libre', 'hematica', 'biometria', 'orina', 'sangre', 'electro', 'electrocardiograma', 'Biometría hemática', 'renina', 'Plasmodium', 'Biometría hemática INR', 'Biometría hemática x2']
    cases.extend({'query': label, 'kind': 'public'} for label in public_labels)
    def observations(phase):
        return '\n'.join('insert into evaluation_observations values (' + ','.join([ev.q(phase), str(i), ev.q(c['kind']), ev.q(c['query']), expression(c['query'], c['kind'])]) + ');' for i, c in enumerate(cases)) + '\n'
    prefix = "begin;\nset local lock_timeout='250ms';\nset local statement_timeout='10s';\n"
    temp = 'create temporary table evaluation_observations(phase text,ordinal integer,kind text,label text,payload jsonb) on commit drop;\n'
    sql = prefix + 'set local application_name=' + ev.q(ev.TOKEN) + ';\n' + guard + temp + observations('before') + body + observations('after')
    sql += "select jsonb_build_object('application_name',current_setting('application_name'),'backend_pid',pg_backend_pid(),'observations',(select jsonb_agg(to_jsonb(o) order by phase,ordinal) from evaluation_observations o),'rollback_required',true) as evaluation;\nrollback;\n"
    ev.write_new(folder / 'evaluation-ROLLBACK-PROPOSED.sql', sql)
    ev.write_new(folder / 'candidate-body.sql', guard + body)
    ev.write_new(folder / 'original-functions.sql', '\n'.join(f['definition'].rstrip(';') + ';' for f in original))
    ev.write_new(folder / 'preparation.json', preparation)
    plan = dict(version=1, project_ref=ev.PROJECT, purpose='canonical_reconciliation_rollback_evaluation',
                runner_sha256=ev.sha(Path(__file__).read_bytes()), helper_sha256=HELPER_SHA,
                sql_template_sha256=ev.sha(sql.encode()), snapshot_sql_sha256=ev.sha(expanded_snapshot().encode()),
                body_sha256=ev.sha((guard + body).encode()), cases=cases, observation_rows_expected=2 * len(cases), approval_reference=APPROVAL)
    ev.write_new(folder / 'plan.json', plan)
    ev.write_new(folder / 'authorization.json', {**{k: plan[k] for k in ['version', 'project_ref', 'purpose', 'runner_sha256', 'sql_template_sha256']}, 'approved_by_user': True, 'user_approval_reference': APPROVAL})
    print(json.dumps({'prepared': True, 'cases': len(cases), 'remote_writes': 0}))


def validate(folder):
    plan = load(folder / 'plan.json')
    assert (ROOT / 'database/supabase/.temp/project-ref').read_text().strip() == ev.PROJECT == plan['project_ref']
    assert ev.sha(Path(ev.__file__).read_bytes()) == HELPER_SHA == plan['helper_sha256']
    assert ev.sha(Path(__file__).read_bytes()) == plan['runner_sha256']
    for file, key in [('evaluation-ROLLBACK-PROPOSED.sql', 'sql_template_sha256'), ('snapshot.sql', 'snapshot_sql_sha256'), ('candidate-body.sql', 'body_sha256')]:
        assert ev.sha((folder / file).read_bytes()) == plan[key]
    return plan


def assess(folder, plan):
    assert load(folder / 'attempt/verified.json')['state_restored']
    observations = load(folder / 'attempt/response.json')[0]['evaluation']['observations']
    failures = []
    for row in observations:
        if row['phase'] != 'after' or row['kind'] != 'core':
            continue
        case = plan['cases'][row['ordinal']]
        resolved = {r['item_id'] for r in row['payload'] if r['resolution_status'] == 'resolved'}
        if ('expected_item_ids' in case and resolved != set(case['expected_item_ids'])) or resolved.intersection(case.get('must_not_resolve_ids', [])):
            failures.append({'query': row['label'], 'resolved_ids': sorted(resolved)})
    report = {'at': ev.now(), 'failures': failures, 'specified_controls': sum(c['kind'] == 'core' for c in plan['cases']), 'public_observations': sum(c['kind'] == 'public' for c in plan['cases']), 'pass': not failures}
    ev.write_new(folder / 'clinical-assessment.json', report)
    print(json.dumps(report))
    assert not failures, 'Do not deploy a failed clinical candidate'


def deploy(folder, plan):
    assert load(folder / 'clinical-assessment.json')['pass']
    attempt = folder / 'deployment'
    attempt.mkdir(exist_ok=False)
    before = load(folder / 'attempt/before.json')
    with ev.client() as db:
        current = ev.capture_snapshot(db, folder)
    assert current == before, 'Protected baseline changed; prepare fresh evaluation'
    ev.write_new(attempt / 'before.json', current)
    prep = load(folder / 'preparation.json')
    ids = ','.join(ev.q(c['item_id']) + '::uuid' for c in prep['imaging_changes'])
    lexids = ','.join(ev.q(x) + '::uuid' for x in prep['positive_component_lexicon_ids'])
    sql = "begin;\nset local lock_timeout='250ms';\nset local statement_timeout='10s';\n"
    sql += "create temporary table reconciliation_before on commit drop as select jsonb_build_object('services',(select jsonb_agg(to_jsonb(t)) from health.services t where catalog_item_id in (" + ids + ")),'lexicon',(select jsonb_agg(to_jsonb(t)) from health.query_lexicon t where id in (" + lexids + ")),'anatomy',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from health.service_anatomy t where service_id in (" + ids + "))) payload;\n"
    sql += (folder / 'candidate-body.sql').read_text(encoding='utf-8')
    for case in plan['cases']:
        if case['kind'] != 'core':
            continue
        checks = []
        if 'expected_item_ids' in case:
            expected = ','.join(ev.q(x) + '::uuid' for x in sorted(case['expected_item_ids']))
            checks.append('actual is distinct from ARRAY[' + expected + ']::uuid[]')
        if 'must_not_resolve_ids' in case:
            checks.append('actual && ARRAY[' + ','.join(ev.q(x) + '::uuid' for x in case['must_not_resolve_ids']) + ']::uuid[]')
        sql += "do $assert$ declare actual uuid[]; begin select coalesce(array_agg(item_id order by item_id),'{}'::uuid[]) into actual from catalog.resolve_items_v6(" + ev.q(case['query']) + ",'health_diagnostics',null,10) where resolution_status='resolved'; if " + ' or '.join(checks) + " then raise exception 'Clinical release assertion failed'; end if; end $assert$;\n"
    sql += "insert into audit.events(actor_type,action,entity_schema,entity_table,before_data,after_data,request_id,metadata) select 'system','catalog.clinical_reconciliation_approved','catalog','clinical_resolver',payload,jsonb_build_object('services',(select jsonb_agg(to_jsonb(t)) from health.services t where catalog_item_id in (" + ids + ")),'lexicon',(select jsonb_agg(to_jsonb(t)) from health.query_lexicon t where id in (" + lexids + ")),'anatomy',(select jsonb_agg(to_jsonb(t)) from health.service_anatomy t where service_id in (" + ids + "))), 'canonical-reconciliation-20261023'," + ev.q(json.dumps({'approval': APPROVAL, 'body_sha256': plan['body_sha256'], 'functions': ['resolve_items', 'resolve_items_v3', 'resolve_items_v4', 'resolve_items_v6'], 'backup': str(folder.relative_to(ROOT)).replace('\\', '/')})) + '::jsonb from reconciliation_before;\n'
    sql += "insert into supabase_migrations.schema_migrations(version,name,statements) values (" + ev.q(VERSION) + ',' + ev.q(NAME) + ',ARRAY[' + ev.q((folder / 'candidate-body.sql').read_text(encoding='utf-8')) + ']);\ncommit;\n'
    ev.write_new(attempt / 'migration.sql', sql)
    ev.write_new(attempt / 'send-attempt.json', {'at': ev.now(), 'single_attempt': True, 'sha256': ev.sha(sql.encode()), 'approval': APPROVAL})
    with ev.client() as db:
        try:
            response = query(db, ev.PROJECT, sql)
            ev.write_new(attempt / 'response.json', response)
        except Exception as error:
            ev.write_new(attempt / 'outcome-uncertain.json', {'at': ev.now(), 'error_type': type(error).__name__, 'instruction': 'Inspect ledger and protected state; NEVER replay.'})
    with ev.client() as observer:
        after = ev.capture_snapshot(observer, folder)
        ledger = query(observer, ev.PROJECT, 'select version,name from supabase_migrations.schema_migrations where version=' + ev.q(VERSION))
    ev.write_new(attempt / 'after.json', after)
    ev.write_new(attempt / 'ledger.json', ledger)
    assert len(ledger) == 1, 'Deployment not confirmed; inspect without replay'
    changed_funcs = [a['name'] for a, b in zip(after['functions'], before['functions']) if a != b]
    assert set(changed_funcs) == {'resolve_items', 'resolve_items_v3', 'resolve_items_v4', 'resolve_items_v6'}
    for a, b in zip(after['functions'], before['functions']):
        assert {k: v for k, v in a.items() if k != 'definition'} == {k: v for k, v in b.items() if k != 'definition'}, 'Function permissions/configuration drift'
    for section in ['schemas', 'relations', 'triggers', 'policies']:
        assert before[section] == after[section], 'Security/schema drift'
    changed_data = [k for k in before['protected_data'] if before['protected_data'][k] != after['protected_data'][k]]
    assert set(changed_data) == {'health.services', 'health.service_anatomy', 'health.query_lexicon', 'migrations'}, changed_data
    migration = ROOT / 'database/supabase/migrations' / (VERSION + '_' + NAME + '.sql')
    ev.write_new(migration, sql)
    ev.write_new(attempt / 'verified.json', {'at': ev.now(), 'deployed': True, 'changed_functions': changed_funcs, 'changed_data_groups': changed_data, 'permissions_preserved': True, 'new_audit_request': 'canonical-reconciliation-20261023'})
    print(json.dumps({'deployed': True, 'migration': VERSION, 'changed_functions': changed_funcs, 'permissions_preserved': True}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['prepare', 'evaluate', 'deploy'])
    parser.add_argument('--folder', type=Path, required=True)
    args = parser.parse_args()
    folder = ev.within_artifacts(args.folder)
    if args.command == 'prepare':
        prepare(folder)
        return
    plan = validate(folder)
    if args.command == 'evaluate':
        assert ev.execute(folder, plan, folder / 'authorization.json') == 0
        assess(folder, plan)
    else:
        deploy(folder, plan)


if __name__ == '__main__':
    main()
