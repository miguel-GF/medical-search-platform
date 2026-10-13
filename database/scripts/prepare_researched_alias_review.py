"""Prepare a researched review from frozen crawler evidence; no DB writes.

This is the preparation stage for D-021/D-022, not an automatic clinical reviewer.
The definition file and research report record the investigator's decisions.
Current RAW, exact collisions, counts and ledger are rechecked before producing
an immutable fixture and rollback SQL for the existing queue executor.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
from uuid import NAMESPACE_URL, UUID, uuid5

import httpx

from publish_denue_bulk_linked import management_token
from reviewed_alias_batch import expected_rows, render
from render_ingest_artifact import q
from run_local_review_queue import ledger, query, save

ROOT = Path(__file__).resolve().parents[2]
COMMON = (' Sólo identidad de orden y atributos escritos; no equivalencia de resultados. '
          'Propiedad, método, escala, unidad y LOINC no aprobados salvo declaración '
          'literal registrada en el motivo. Original y preparación conservados, '
          'sin validar instrucciones farmacológicas. Sin ofertas, precio o disponibilidad nuevos.')


def within(value: Path, parent: Path) -> Path:
    path = value.resolve()
    if not path.is_relative_to(parent.resolve()):
        raise ValueError('Preparation paths must remain within their designated workspace')
    return path


def field(payload: dict, path: list[str]) -> str:
    value = payload
    for part in path:
        value = value[part]
    if not isinstance(value, str) or not value:
        raise ValueError('A complete nonempty RAW guard value is required')
    return value


def prepare(client: httpx.Client, ref: str, *, definition: Path, snapshot: Path,
            report: Path, fixture: Path, artifacts: Path) -> dict:
    if fixture.exists() or (artifacts / 'prepared.json').exists():
        raise ValueError('Preserve existing prepared reviews; inspect ledger before a new operation')
    document = json.loads(definition.read_text(encoding='utf-8'))
    if set(document) != {'review_id', 'research_date', 'scope', 'definitions'}:
        raise ValueError('Explicit review ID, research date, scope and definitions are required')
    rid = document['review_id']
    if not re.fullmatch(r'pruevia:evidence-review:[0-9]{8}:[0-9]{2}', rid):
        raise ValueError('A dated terminology review ID is required')
    if fixture.name != 'reviewed-aliases-' + rid.split(':')[2] + '-' + rid.split(':')[3] + '.json':
        raise ValueError('Fixture filename must match its immutable review identity')
    if (not isinstance(document['research_date'], str)
            or not re.fullmatch(r'[0-9]{4}-[0-9]{2}-[0-9]{2}', document['research_date'])
            or document['research_date'].replace('-', '') != rid.split(':')[2]
            or not isinstance(document['scope'], str) or not document['scope'].strip()):
        raise ValueError('Research date and review scope must be consistent')
    defs = document['definitions']
    if not isinstance(defs, list) or not 1 <= len(defs) <= 10:
        raise ValueError('Provide one to ten investigated concepts')
    report_bytes = report.read_bytes()
    if not report_bytes.strip():
        raise ValueError('A primary research report is required')
    original_bytes = snapshot.read_bytes()
    original_rows = json.loads(original_bytes)
    if not isinstance(original_rows, list) or any(not isinstance(r, dict) for r in original_rows):
        raise ValueError('Crawler snapshot must be an array of complete context objects')
    originals = {row['id']: row for row in original_rows}
    if len(originals) != len(original_rows):
        raise ValueError('Duplicate context IDs in frozen snapshot')
    labels = sorted({a['label'] for d in defs for a in d['aliases']})
    rows = query(client, ref, "select nr.id,nr.provider_brand_id,nr.normalized_input,"
                 "nr.raw_text,nr.status,rr.payload from ingest.normalization_runs nr "
                 "join ingest.raw_records rr on rr.id=nr.raw_record_id "
                 "where nr.input_type='crawler' and nr.normalized_input in ("
                 + ','.join(q(label) for label in labels)
                 + ") and nr.status in ('pending','ambiguous','no_match') and not exists("
                 "select 1 from ingest.normalization_decisions nd where nd.normalization_run_id=nr.id "
                 "and nd.decision_type in ('automatic','manual','ambiguous','rejected','no_match')) "
                 "order by nr.normalized_input,nr.provider_brand_id,nr.id")
    global_labels = {a['label'] for d in defs for a in d['aliases']
                     if a.get('alias_scope', 'global') == 'global'}
    provider_pairs = {(a['label'], t['provider_brand_id']) for d in defs
                      for a in d['aliases'] for t in a['targets']}
    outside_scope = [row for row in rows if row['normalized_input'] not in global_labels
                     and (row['normalized_input'], row['provider_brand_id']) not in provider_pairs]
    save(artifacts / 'provider-contexts-outside-scope-before.json', outside_scope)
    rows = [row for row in rows if row not in outside_scope]
    if not rows or any(row['id'] not in originals or any(
            row[key] != originals[row['id']][key]
            for key in ['payload', 'provider_brand_id', 'normalized_input', 'raw_text']) for row in rows):
        raise ValueError('Current evidence differs from the investigated snapshot')
    review = {
        'review_id': rid, 'research_date': document['research_date'], 'scope': document['scope'],
        'reviewed_by': 'Codex, investigación delegada por el operador', 'human_review': False,
        'authorization': 'D-021/D-022: investigar fuentes primarias y decidir identidades claras; conservar ambigüedad clínica.',
        'research_report_sha256': hashlib.sha256(report_bytes).hexdigest(),
        'research_snapshot_sha256': hashlib.sha256(original_bytes).hexdigest(),
        'definition_sha256': hashlib.sha256(definition.read_bytes()).hexdigest(),
        'new_concepts': [], 'aliases': [],
    }
    chosen = set()
    reused = {}
    for d in defs:
        existing = d.get('existing_catalog_item_id')
        item = str(UUID(existing)) if existing else str(uuid5(
            NAMESPACE_URL, rid + ':concept:' + d['aliases'][0]['label']))
        if existing:
            identity = query(client, ref, "select i.id,n.name,h.service_type from catalog.items i "
                             "join catalog.domains dm on dm.id=i.domain_id "
                             "join catalog.item_names n on n.item_id=i.id and n.is_primary "
                             "join health.services h on h.catalog_item_id=i.id "
                             "where i.id=" + q(item) + "::uuid and i.status='active' "
                             "and dm.code='health_diagnostics'")
            if (len(identity) != 1 or identity[0]['name'] != d['canonical_name']
                    or identity[0]['service_type'] != 'lab_test'):
                raise ValueError('Existing identity must be an active exact named laboratory order')
            reused[item] = identity[0]
        reason = d['reason'] + COMMON
        specimen = d['specimen_code']
        concept = {
            'item_id': item, 'canonical_name': d['canonical_name'], 'component': d['component'],
            'specimen_code': specimen, 'time_aspect': d.get('time_aspect'),
            'identity_scope': 'specimen_order' if specimen else 'analyte_order',
            'evidence_url': d['evidence_url'], 'reason': reason,
        }
        if specimen is None:
            concept['specimen_uncertainty'] = d.get('specimen_uncertainty') or (
                'Matriz exacta y duración desconocidas en esta orden. Los atributos explícitos '
                'de cada fuente quedan en su contexto; ayuno y muestra externa no completan el canónico.')
        if not existing:
            review['new_concepts'].append(concept)
        for a in d['aliases']:
            scope = a.get('alias_scope', 'global')
            targets = []
            for t in a['targets']:
                group = [r for r in rows if r['normalized_input'] == a['label']
                         and r['provider_brand_id'] == t['provider_brand_id']]
                if len(group) != t['expected_rows']:
                    raise ValueError('Current eligible context count differs from research')
                for row in group:
                    study = row['payload'].get('raw_study') or {}
                    if (any(study.get(key) not in (None, '', 0, '0')
                            for key in ['IdPaciente', 'IdPacienteSisPrev'])
                            or (study and study.get('Estudio') != 'LABORATORIO')):
                        raise ValueError('Patient or non-laboratory context cannot enter this batch')
                values = {field(row['payload'], t['guard_path']) for row in group}
                if len(values) != 1:
                    raise ValueError('Distinct clinical contexts need independent investigation')
                if chosen.intersection(row['id'] for row in group):
                    raise ValueError('A crawler context cannot be selected twice')
                chosen.update(row['id'] for row in group)
                target = {
                    'provider_brand_id': t['provider_brand_id'], 'expected_rows': len(group),
                    'raw_guard': {'path': t['guard_path'], 'value': next(iter(values))},
                }
                if t.get('source_attributes'):
                    target['source_attributes'] = t['source_attributes']
                targets.append(target)
            if not targets:
                raise ValueError('Each reviewed alias requires an explicit provider context')
            alias = {
                'alias': a['label'], 'item_id': item, 'canonical_name': d['canonical_name'],
                'service_type': 'lab_test', 'alias_scope': scope,
                'evidence_url': d['evidence_url'], 'reason': reason, **targets[0],
            }
            if scope == 'provider':
                review['aliases'].extend({**alias, **target} for target in targets)
            else:
                if len(targets) > 1:
                    alias['additional_targets'] = targets[1:]
                review['aliases'].append(alias)
    if chosen != {row['id'] for row in rows} or len(rows) != expected_rows(review):
        raise ValueError('Every eligible row for the researched labels must be accounted for')
    terms = sorted(set(labels + [d['canonical_name'] for d in defs]))
    values = ','.join('(' + q(term) + ')' for term in terms)
    collisions = query(client, ref, 'with terms(raw) as (values ' + values + ") "
                       "select 'name' source,n.item_id,n.name term from catalog.item_names n "
                       "where n.normalized_name in(select core.normalized_text(raw) from terms) "
                       "union all select 'alias',a.item_id,a.alias from catalog.item_aliases a "
                       "where a.status<>'rejected' and a.normalized_alias in"
                       "(select core.normalized_text(raw) from terms) "
                       "union all select 'disambiguation',null::uuid,d.term from catalog.disambiguation_terms d "
                       "where d.status='approved' and d.normalized_term in"
                       "(select core.normalized_text(raw) from terms)")
    save(artifacts / 'exact-collisions-before.json', collisions)
    unexpected_collisions = [row for row in collisions if not (
        row['source'] in ('name', 'alias') and row['item_id'] in reused
        and row['term'] == reused[row['item_id']]['name'])]
    save(artifacts / 'reused-identities-before.json', list(reused.values()))
    if unexpected_collisions:
        raise ValueError('Review the existing identity instead of creating a duplicate')
    # Validate with the existing renderer before producing the final fixture.
    staged = artifacts / 'prepared-review-staging.json'
    save(staged, review)
    sql = render(fixture=staged)
    state = ledger(client, ref, review)
    if state != 'not_applied':
        raise ValueError('The remote ledger is already applied or inconsistent')
    # Primary canonical names are global exact terms too. Reading only alias
    # labels misses eligible records from another provider that use a new name.
    global_terms = sorted(global_labels | {d['canonical_name'] for d in defs})
    global_values = ','.join('(' + q(term) + ')' for term in global_terms)
    pair_conditions = ' or '.join('(' + 'nr.normalized_input=' + q(label)
                                 + ' and nr.provider_brand_id=' + q(provider) + '::uuid)'
                                 for label, provider in sorted(provider_pairs))
    name_rows = query(client, ref, 'with terms(raw) as (values ' + global_values + ") "
                      "select nr.id,nr.provider_brand_id,nr.normalized_input,nr.raw_text,nr.status,rr.payload "
                      "from ingest.normalization_runs nr join ingest.raw_records rr on rr.id=nr.raw_record_id "
                      "where nr.input_type='crawler' and (nr.normalized_input in "
                      "(select core.normalized_text(raw) from terms) or " + pair_conditions + ") "
                      "and nr.status in ('pending','ambiguous','no_match') and not exists("
                      "select 1 from ingest.normalization_decisions nd where nd.normalization_run_id=nr.id "
                      "and nd.decision_type in ('automatic','manual','ambiguous','rejected','no_match')) "
                      "order by nr.id")
    unreviewed = [row for row in name_rows if row['id'] not in chosen]
    save(artifacts / 'additional-exact-contexts-before.json', unreviewed)
    if unreviewed:
        raise ValueError('New canonical names enable unreviewed crawler contexts; research those before enqueueing')
    # Recheck the destination after remote reads; never replace an existing review.
    content = (json.dumps(review, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
    with fixture.open('xb') as output:
        output.write(content)
    save(artifacts / 'selected-raw-contexts-before.json', rows)
    (artifacts / 'preview.sql').write_bytes(sql.encode('utf-8'))
    receipt = {
        'observed_at': datetime.now(timezone.utc).isoformat(), 'project_ref': ref,
        'review_id': rid, 'rows': len(rows), 'concepts': len(review['new_concepts']),
        'reused_concepts': len(reused), 'aliases': len(review['aliases']),
        'sha256': hashlib.sha256(content).hexdigest(), 'ledger': state,
        'research_report_sha256': review['research_report_sha256'],
        'raw_snapshot_sha256': review['research_snapshot_sha256'],
        'sql_executed': False, 'formal_tests_executed': False,
    }
    save(artifacts / 'prepared.json', receipt)
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-ref', required=True)
    parser.add_argument('--definition', type=Path, required=True)
    parser.add_argument('--snapshot', type=Path, required=True)
    parser.add_argument('--research-report', type=Path, required=True)
    parser.add_argument('--fixture', type=Path, required=True)
    parser.add_argument('--artifacts', type=Path, required=True)
    args = parser.parse_args()
    ref = (ROOT / 'database/supabase/.temp/project-ref').read_text().strip()
    if ref != args.project_ref or not re.fullmatch(r'[a-z]{20}', ref):
        parser.error('Linked project must match the explicit destination')
    fixture = within(args.fixture, ROOT / 'database/data')
    if fixture.parent != ROOT / 'database/data' or not re.fullmatch(r'reviewed-aliases-[0-9]{8}-[0-9]{2}\.json', fixture.name):
        parser.error('Use a new dated fixture directly inside database/data')
    artifacts = within(args.artifacts, ROOT / 'collectors/artifacts')
    artifacts.mkdir(parents=True, exist_ok=True)
    paths = [within(path, ROOT) for path in [args.definition, args.snapshot, args.research_report]]
    with httpx.Client(base_url='https://api.supabase.com',
                      headers={'Authorization': 'Bearer ' + management_token()}, timeout=90) as client:
        receipt = prepare(client, ref, definition=paths[0], snapshot=paths[1], report=paths[2],
                          fixture=fixture, artifacts=artifacts)
    print(json.dumps({k: receipt[k] for k in ['review_id', 'rows', 'concepts', 'aliases', 'sha256', 'ledger', 'sql_executed']}), flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
