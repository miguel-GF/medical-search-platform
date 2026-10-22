"""Prepare or inspect a bounded clinical SQL evaluation.

Preparation and inspection never replace functions. Execution requires a separate
record of explicit user approval for this exact plan, runner and SQL template.
The one submitted transaction ends in ROLLBACK; no replay or restore is provided.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import sys
from uuid import uuid4

import httpx

from publish_denue_bulk_linked import management_token
from publish_golden_catalog import q
from run_local_review_queue import query

ROOT = Path(__file__).resolve().parents[2]
ARTIFACTS = ROOT / 'collectors/artifacts'
PROJECT = 'ymtcmfgwuzdqtsbuvzqf'
PROPOSAL = ROOT / 'docs/proposals/20261021-combined-clinical'
TOKEN = '__PRUEVIA_EVALUATION_ATTEMPT__'
SCHEMAS = "('public','catalog','health','core','ingest')"


def now():
    return datetime.now(timezone.utc).isoformat()


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def write_new(path, value):
    raw = value.encode('utf-8') if isinstance(value, str) else (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
    with path.open('xb') as target:
        target.write(raw)


def within_artifacts(path):
    resolved = path.resolve()
    resolved.relative_to(ARTIFACTS.resolve())
    if resolved == ARTIFACTS.resolve():
        raise ValueError('An isolated artifact directory is required')
    return resolved


def client():
    return httpx.Client(base_url='https://api.supabase.com', headers={'Authorization': 'Bearer ' + management_token()}, timeout=120)


def snapshot_sql():
    tables = [
        'core.provider_brands', 'core.provider_locations', 'core.location_external_ids',
        'catalog.items', 'catalog.item_names', 'catalog.item_aliases',
        'health.services', 'health.lab_service_definitions', 'health.service_components',
        'health.service_anatomy', 'health.anatomical_sites', 'health.specimen_types',
        'health.service_specimens', 'health.service_methods',
        'supply.offers', 'supply.offer_scopes', 'supply.price_versions',
        'supply.offer_links', 'supply.availability_current', 'ingest.sources',
    ]
    selections = {name: 'select * from ' + name for name in tables}
    selections.update({
        'public_source_raw': "select rr.* from ingest.raw_records rr where exists(select 1 from ingest.sources s where s.id=rr.source_id and s.source_type in ('government','provider_official','public_website'))",
        'crawler_runs': "select * from ingest.normalization_runs where input_type='crawler'",
        'crawler_decisions': "select nd.* from ingest.normalization_decisions nd where exists(select 1 from ingest.normalization_runs nr where nr.id=nd.normalization_run_id and nr.input_type='crawler')",
        'crawler_candidates': "select nc.* from ingest.normalization_candidates nc where exists(select 1 from ingest.normalization_runs nr where nr.id=nc.normalization_run_id and nr.input_type='crawler')",
        'public_source_observations': "select o.* from ingest.source_observations o where exists(select 1 from ingest.sources s where s.id=o.source_id and s.source_type in ('government','provider_official','public_website'))",
        'business_review_audits': "select * from audit.events where action in ('catalog.alias_evidence_review','catalog.concept_evidence_review','catalog.imaging_protocol_review','provider.identity_evidence_review','catalog.panel_composition_review','catalog.panel_composition_quarantine')",
        'migrations': 'select * from supabase_migrations.schema_migrations',
    })
    digests = []
    for name, selection in selections.items():
        digests.append(q(name) + ", (select jsonb_build_object('rows',count(*),'multiset_md5',md5(coalesce(string_agg(row_md5,'' order by row_md5),''))) from (select md5(to_jsonb(t)::text) row_md5 from (" + selection + ') t) hashed)')
    return """select jsonb_build_object(
 'functions',(select jsonb_agg(jsonb_build_object(
   'schema',n.nspname,'name',p.proname,'arguments',pg_get_function_identity_arguments(p.oid),
   'definition',pg_get_functiondef(p.oid),'acl',p.proacl::text,'owner',pg_get_userbyid(p.proowner),
   'security_definer',p.prosecdef,'configuration',p.proconfig)
   order by n.nspname,p.proname,pg_get_function_identity_arguments(p.oid))
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname in """ + SCHEMAS + """ and p.prokind='f'),
 'relations',(select jsonb_agg(jsonb_build_object('schema',n.nspname,'name',c.relname,
   'kind',c.relkind,'owner',pg_get_userbyid(c.relowner),'acl',c.relacl::text,
   'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity)
   order by n.nspname,c.relname) from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname in """ + SCHEMAS + """ and c.relkind in ('r','p','v','m')),
 'triggers',(select jsonb_agg(jsonb_build_object('schema',n.nspname,'table',c.relname,
   'name',t.tgname,'enabled',t.tgenabled,'definition',pg_get_triggerdef(t.oid,true))
   order by n.nspname,c.relname,t.tgname) from pg_trigger t join pg_class c on c.oid=t.tgrelid
   join pg_namespace n on n.oid=c.relnamespace where n.nspname in """ + SCHEMAS + """),
 'policies',(select jsonb_agg(to_jsonb(p) order by p.schemaname,p.tablename,p.policyname)
   from pg_policies p where p.schemaname in """ + SCHEMAS + """),
 'schemas',(select jsonb_agg(jsonb_build_object('name',nspname,'owner',pg_get_userbyid(nspowner),
   'acl',nspacl::text) order by nspname) from pg_namespace where nspname in """ + SCHEMAS + "),\n 'protected_data',jsonb_build_object(" + ',\n'.join(digests) + ')) as snapshot;\n'


def prepare(out):
    out = within_artifacts(out)
    if out.exists():
        raise ValueError('Preserve existing evaluation evidence')
    evidence = json.loads((PROPOSAL / 'evidence.json').read_bytes())
    base = (PROPOSAL / 'combined-ROLLBACK-PROPOSED.sql').read_bytes()
    if sha(base) != evidence['sql']['combined_sql_sha256']:
        raise ValueError('Proposal pin changed')
    sql = base.decode('utf-8')
    labels = ['Biometría hemática', 'Biometría hemática INR', 'Biometría hemática x2',
              'hematica', 'biometria', 'orina', 'sangre', 'electro', 'electrocardiograma',
              'IgE específica contra gluten', 'IgE específica contra gluten sin IgE',
              'TELERADIOGRAFIA DE TORAX PA', 'TELERADIOGRAFIA TORAX PA Y LATERAL']
    labels += [row['name'] for row in evidence['panel_impact']['panels']]
    labels = list(dict.fromkeys(labels))
    cases = []
    for label in labels:
        if not isinstance(label, str) or not 1 <= len(label) <= 200:
            raise ValueError('Only bounded public study labels are accepted')
        args = q(label) + ",'health_diagnostics',null,null,null,10"
        cases.append({'kind': 'search_and_package', 'label': label,
                      'expression': "jsonb_build_object('search',public.api_resolve_search(" + args + "),'package',public.api_resolve_package(jsonb_build_array(" + q(label) + "),'health_diagnostics',null,null,null,10))"})
    for row in evidence['panel_impact']['panels']:
        cases.append({'kind': 'panel_detail', 'label': row['name'],
                      'expression': 'public.api_service_detail(' + q(row['catalog_item_id']) + '::uuid)'})

    def capture(phase):
        return '\n'.join("insert into evaluation_observations values (" + ','.join((q(phase), str(index), q(case['kind']), q(case['label']), case['expression'])) + ');'
                         for index, case in enumerate(cases, 1))

    marker = 'end $baseline_guard$;'
    if sql.count(marker) != 1 or not sql.endswith('rollback;\n'):
        raise ValueError('Proposal transaction layout changed')
    sql = sql.replace('begin;\n', "begin;\nset local application_name=" + q(TOKEN) + ';\n', 1)
    before = "\ncreate temporary table evaluation_observations(phase text,ordinal integer,kind text,label text,payload jsonb) on commit drop;\n" + capture('before') + '\n'
    sql = sql.replace(marker, marker + before, 1)
    after = '\n' + capture('after') + "\nselect jsonb_build_object('application_name',current_setting('application_name'),'backend_pid',pg_backend_pid(),'observations',(select jsonb_agg(to_jsonb(o) order by phase,ordinal) from evaluation_observations o),'rollback_required',true) as evaluation;\nrollback;\n"
    sql = sql[:-len('rollback;\n')] + after
    if sql.count(TOKEN) != 1 or re.search(r'^commit;', sql, re.I | re.M):
        raise ValueError('Unexpected execution boundary')
    snapshot = snapshot_sql()
    out.mkdir(parents=True)
    write_new(out / 'evaluation-ROLLBACK-PROPOSED.sql', sql)
    write_new(out / 'snapshot.sql', snapshot)
    plan = {'version': 1, 'prepared_at': now(), 'project_ref': PROJECT,
            'purpose': 'combined_clinical_rollback_evaluation_only',
            'runner_sha256': sha(Path(__file__).read_bytes()), 'sql_template_sha256': sha(sql.encode('utf-8')),
            'snapshot_sql_sha256': sha(snapshot.encode('utf-8')), 'proposal_sql_sha256': sha(base),
            'cases': [{key: value for key, value in case.items() if key != 'expression'} for case in cases],
            'observation_rows_expected': len(cases) * 2,
            'database_writes_submitted': False, 'formal_tests_executed': False,
            'limitations': ['Empty proposed registries; no pilot imports', 'Owner-session RPC observations, not HTTP/JWT or service-role execution', 'No clinical expected-outcome assertions or complete contract suite']}
    write_new(out / 'plan.json', plan)
    write_new(out / 'authorization.example.json', {'version': 1, 'approved_by_user': False,
              'project_ref': PROJECT, 'purpose': plan['purpose'], 'sql_template_sha256': plan['sql_template_sha256'],
              'runner_sha256': plan['runner_sha256'], 'user_approval_reference': ''})
    print(json.dumps({'prepared': True, 'cases': len(cases), 'observation_rows': len(cases) * 2,
                      'sql_template_sha256': plan['sql_template_sha256'], 'sql_submitted': False}))


def load_plan(path):
    folder = within_artifacts(path.parent)
    plan = json.loads(path.read_bytes())
    linked = (ROOT / 'database/supabase/.temp/project-ref').read_text().strip()
    if linked != PROJECT or plan['project_ref'] != PROJECT or plan['version'] != 1 or plan.get('purpose') != 'combined_clinical_rollback_evaluation_only':
        raise ValueError('Wrong evaluation destination')
    for name, expected in [('evaluation-ROLLBACK-PROPOSED.sql', plan['sql_template_sha256']), ('snapshot.sql', plan['snapshot_sql_sha256'])]:
        if sha((folder / name).read_bytes()) != expected:
            raise ValueError('Evaluation bytes changed')
    if sha(Path(__file__).read_bytes()) != plan['runner_sha256']:
        raise ValueError('Runner changed; prepare a new plan and authorization')
    if (folder / 'snapshot.sql').read_bytes() != snapshot_sql().encode('utf-8'):
        raise ValueError('Read-only snapshots must match the built-in SELECT exactly')
    return folder, plan


def capture_snapshot(db, folder):
    rows = query(db, PROJECT, (folder / 'snapshot.sql').read_text(encoding='utf-8'))
    if len(rows) != 1 or not isinstance(rows[0].get('snapshot'), dict):
        raise ValueError('Incomplete state snapshot')
    return rows[0]['snapshot']


def inspect(folder, plan):
    attempt = folder / 'attempt'
    record = json.loads((attempt / 'send-attempt.json').read_bytes())
    marker = record['application_name']
    if not re.fullmatch(r'pruevia-eval-[a-f0-9]{16}', marker):
        raise ValueError('Invalid session marker')
    with client() as observer:
        activity = query(observer, PROJECT, 'select pid,backend_start,xact_start,state from pg_stat_activity where application_name=' + q(marker))
        after = capture_snapshot(observer, folder)
    before = json.loads((attempt / 'before.json').read_bytes())
    report = {'at': now(), 'active_evaluation_sessions': activity,
              'state_restored': not activity and before == after,
              'different_sections': sorted(key for key in before if before[key] != after.get(key)),
              'sql_replayed': False, 'recovery_writes': False}
    name = 'inspection-' + uuid4().hex[:12]
    write_new(attempt / (name + '-state.json'), after)
    write_new(attempt / (name + '.json'), report)
    print(json.dumps(report, default=str))
    return report


def execute(folder, plan, authorization_path):
    authorization = json.loads(authorization_path.read_bytes())
    if authorization.get('version') != 1 or authorization.get('approved_by_user') is not True:
        raise ValueError('Explicit user approval has not been recorded')
    for key in ('project_ref', 'purpose', 'sql_template_sha256', 'runner_sha256'):
        if authorization.get(key) != plan[key]:
            raise ValueError('Approval does not cover this exact evaluation')
    reference = authorization.get('user_approval_reference')
    if not isinstance(reference, str) or not 1 <= len(reference.strip()) <= 500:
        raise ValueError('A faithful reference to explicit user approval is required')
    attempt = folder / 'attempt'
    attempt.mkdir(exist_ok=False)
    marker = 'pruevia-eval-' + uuid4().hex[:16]
    sql = (folder / 'evaluation-ROLLBACK-PROPOSED.sql').read_text(encoding='utf-8').replace(TOKEN, marker)
    with client() as db:
        before = capture_snapshot(db, folder)
        write_new(attempt / 'before.json', before)
        write_new(attempt / 'approval-record.json', {key: authorization[key] for key in (
            'version', 'approved_by_user', 'project_ref', 'purpose', 'sql_template_sha256',
            'runner_sha256', 'user_approval_reference')})
        write_new(attempt / 'send-attempt.json', {'at': now(), 'application_name': marker,
                  'sql_template_sha256': plan['sql_template_sha256'], 'submitted_sha256': sha(sql.encode('utf-8')),
                  'single_attempt': True})
        try:
            rows = query(db, PROJECT, sql)
            write_new(attempt / 'response.json', rows)
        except Exception as error:
            write_new(attempt / 'outcome-uncertain.json', {'at': now(), 'error_type': type(error).__name__,
                      'next_action': 'Inspect this same attempt. Never resend SQL.'})
    report = inspect(folder, plan)
    if not report['state_restored'] or (attempt / 'outcome-uncertain.json').exists():
        return 2
    rows = json.loads((attempt / 'response.json').read_bytes())
    payload = rows[0].get('evaluation') if len(rows) == 1 else None
    if not isinstance(payload, dict) or payload.get('application_name') != marker or len(payload.get('observations', [])) != plan['observation_rows_expected']:
        raise ValueError('Restore observed, but evaluation response is incomplete')
    write_new(attempt / 'verified.json', {'at': now(), 'state_restored': True,
              'observations_captured': len(payload['observations']), 'clinical_correctness_approved': False,
              'deployment_authorized': False})
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('prepare').add_argument('--output', type=Path, required=True)
    for name in ('capture-baseline', 'inspect', 'execute'):
        command = sub.add_parser(name)
        command.add_argument('--plan', type=Path, required=True)
        if name == 'execute':
            command.add_argument('--authorization', type=Path, required=True)
            command.add_argument('--execute-approved-evaluation', action='store_true', required=True)
    args = parser.parse_args()
    if args.command == 'prepare':
        prepare(args.output)
        return 0
    folder, plan = load_plan(args.plan)
    if args.command == 'capture-baseline':
        with client() as db:
            value = capture_snapshot(db, folder)
        write_new(folder / 'preparation-baseline.json', {'at': now(), 'snapshot': value, 'database_writes': False})
        print(json.dumps({'read_only_baseline_captured': True, 'functions': len(value['functions']), 'protected_groups': len(value['protected_data'])}))
        return 0
    if args.command == 'inspect':
        return 0 if inspect(folder, plan)['state_restored'] else 2
    return execute(folder, plan, args.authorization)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        print(json.dumps({'stopped': True, 'error_type': type(error).__name__,
                          'instruction': 'Preserve receipts and inspect; never replay a sent evaluation.'}))
        sys.exit(2)
