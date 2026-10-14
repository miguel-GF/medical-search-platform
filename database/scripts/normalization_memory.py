"""Compile verified terminology decisions and plan reuse without writing to DB.

The memory is portable across markets, but exact context reuse remains scoped to
the researched provider. New providers receive candidates, never inherited RAW
claims. This tool has no apply/approval/publication operation.
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sys

import httpx

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'collectors/src'))
from pruevia_collectors.normalization import normalize_text
from publish_denue_bulk_linked import management_token
from reviewed_alias_batch import reviewed_targets
from run_local_review_queue import ledger, query, save
from render_ingest_artifact import q

VERSION = 'normalization-memory-shadow-v3'
CLINICAL_FIELDS = (
    'provider_display_name', 'sample_type', 'description', 'category', 'area', 'benefit_description',
    'room', 'pre_exam_instructions', 'other_instructions', 'specialty',
)
STUDY_FIELDS = ('Estudio', 'Preparacion', 'Descripcion')
PAYLOAD_OTHER_FIELDS = {
    'market', 'prices', 'catalog_rank', 'claim_status', 'detail_endpoint_captured',
    'duration_minutes', 'home_service', 'location_external_id', 'location_slug',
    'price_claim_status', 'product_url', 'provider_brand', 'provider_created_at',
    'provider_external_id', 'provider_last_updated_at',
    'provider_sku', 'raw_study', 'turnaround',
    # Inspected source metadata: extraction provenance and commercial pagination.
    # evidence_method="heading_pattern" describes HTML capture, not an assay.
    'discount_text', 'page_number', 'price_text', 'evidence_method',
    'evidence_page_url', 'provider_brand_hint',
}
STUDY_OTHER_FIELDS = {
    'CatSubestudiosId', 'Descuento', 'Estatus', 'EstatusPrecioFijo',
    'EstatusPromocion', 'EstudioID', 'Fecha', 'Horario', 'HorarioText', 'IVA',
    'Id', 'IdCita', 'IdCitaSisPrev', 'IdPaciente', 'IdPacienteSisPrev',
    'IdPaquete', 'IdServicio', 'IdSubEstudio', 'MontoIVA', 'Nombre', 'Precio',
    'PrecioBase', 'PrecioOriginal', 'PrecioPromocion', 'Sucursal', 'VigenciaFin',
    'VigenciaInicio',
}


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def digest(data: object) -> str:
    return hashlib.sha256(json.dumps(data, ensure_ascii=False, sort_keys=True,
                                    separators=(',', ':')).encode('utf-8')).hexdigest()


def context(row: dict) -> dict:
    """Discard commercial fields and patient placeholders; retain clinical text."""
    if 'clinical_context' in row:
        return row['clinical_context']
    payload = row.get('payload', {})
    if not isinstance(payload, dict):
        raise ValueError('Crawler payload must be an object')
    study = payload.get('raw_study') or {}
    if not isinstance(study, dict):
        raise ValueError('Crawler context must be an object')
    return {
        **{field: payload.get(field) for field in CLINICAL_FIELDS},
        'raw_study': {field: study.get(field) for field in STUDY_FIELDS},
        'unknown_fields': sorted(set(payload) - set(CLINICAL_FIELDS) - PAYLOAD_OTHER_FIELDS),
        'unknown_study_fields': sorted(set(study) - set(STUDY_FIELDS) - STUDY_OTHER_FIELDS),
        'patient_data_present': any(study.get(field) not in (None, '', 0, '0')
                                    for field in ('IdPaciente', 'IdPacienteSisPrev')),
    }


def context_sql() -> str:
    fields = ','.join(f'{q(field)},rr.payload->{q(field)}' for field in CLINICAL_FIELDS)
    study = ','.join(f'{q(field)},rr.payload->\'raw_study\'->{q(field)}' for field in STUDY_FIELDS)
    known = ','.join(q(field) for field in sorted(set(CLINICAL_FIELDS) | PAYLOAD_OTHER_FIELDS))
    known_study = ','.join(q(field) for field in sorted(set(STUDY_FIELDS) | STUDY_OTHER_FIELDS))
    return f"""jsonb_build_object({fields},
      'raw_study',jsonb_build_object({study}),
      'unknown_fields',(select coalesce(jsonb_agg(k order by k),'[]'::jsonb)
        from jsonb_object_keys(rr.payload) k where k not in ({known})),
      'unknown_study_fields',(select coalesce(jsonb_agg(k order by k),'[]'::jsonb)
        from jsonb_object_keys(coalesce(rr.payload->'raw_study','{{}}'::jsonb)) k
        where k not in ({known_study})),
      'patient_data_present',coalesce(rr.payload->'raw_study'->>'IdPaciente','') not in ('','0')
        or coalesce(rr.payload->'raw_study'->>'IdPacienteSisPrev','') not in ('','0'))"""


def compile_memory(client: httpx.Client, ref: str, paths: list[Path]) -> dict:
    fixtures, ignored = [], []
    for path in paths:
        content = path.read_bytes()
        fixture = json.loads(content)
        state = ledger(client, ref, fixture)
        if state != 'already_applied':
            ignored.append({'fixture': path.relative_to(ROOT).as_posix(), 'ledger': state})
            continue
        fixtures.append((path, hashlib.sha256(content).hexdigest(), fixture))
    if not fixtures:
        raise ValueError('No fully applied reviews were verified')
    ids = ','.join(q(fixture['review_id']) for _, _, fixture in fixtures)
    rows = query(client, ref, f"""select nr.id,nr.provider_brand_id,nr.normalized_input,
      nr.raw_text,nr.input_type,nd.selected_item_id,
      nd.metadata->>'terminology_review_id' as review_id,
      {context_sql()} as clinical_context
      from ingest.normalization_runs nr
      join ingest.normalization_decisions nd on nd.normalization_run_id=nr.id
      join ingest.raw_records rr on rr.id=nr.raw_record_id
      where nr.input_type='crawler' and nr.status='resolved'
        and nd.metadata->>'terminology_review_id' in ({ids})
      order by nr.id limit 20001""")
    if len(rows) > 20000:
        raise ValueError('Decision export limit exceeded; do not use partial evidence')
    grouped = defaultdict(list)
    for row in rows:
        grouped[(row['review_id'], row['provider_brand_id'], row['normalized_input'],
                 row['selected_item_id'])].append(row)
    rules, aliases = [], []
    for path, sha, fixture in fixtures:
        for alias in fixture['aliases']:
            base = {
                'alias': alias['alias'], 'item_id': alias['item_id'],
                'canonical_name': alias['canonical_name'],
                'alias_scope': alias.get('alias_scope', 'global'),
                'provider_brand_id': alias['provider_brand_id'],
                'review_id': fixture['review_id'], 'fixture_sha256': sha,
                'fixture': path.relative_to(ROOT).as_posix(),
                'evidence_url': alias['evidence_url'], 'reason': alias['reason'],
            }
            aliases.append(base)
            for target in reviewed_targets(alias):
                key = (fixture['review_id'], target['provider_brand_id'],
                       alias['alias'], alias['item_id'])
                observed = grouped[key]
                if len(observed) != target['expected_rows']:
                    raise ValueError('Observed contexts differ from the verified review scope')
                signatures = sorted({digest({'raw_text': row['raw_text'],
                                              'context': context(row)}) for row in observed})
                rules.append({**base, 'provider_brand_id': target['provider_brand_id'],
                              'raw_guard': target.get('raw_guard'),
                              'source_attributes': target.get('source_attributes', {}),
                              'context_signatures': signatures,
                              'historical_rows': len(observed)})
    return {'version': VERSION, 'built_at': now(), 'project_ref': ref,
            'remote_ledger_verified': True, 'shadow_only': True,
            'reviews': len(fixtures), 'aliases': aliases, 'rules': rules,
            'historical_rows': len(rows), 'ignored_fixtures': ignored,
            'expires_after_hours': 24, 'contexts': rows}


def plan(memory: dict, rows: list[dict]) -> dict:
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        raise ValueError('Plan input must be an array of public crawler context objects')
    if (memory.get('version') != VERSION or not memory.get('remote_ledger_verified')
            or memory.get('shadow_only') is not True):
        raise ValueError('A verified shadow memory is required')
    age = datetime.now(timezone.utc) - datetime.fromisoformat(memory['built_at'])
    if not 0 <= age.total_seconds() <= memory['expires_after_hours'] * 3600:
        raise ValueError('Memory snapshot expired; refresh active aliases and ledger')
    by_label, by_target = defaultdict(list), defaultdict(list)
    for alias in memory['aliases']:
        by_label[alias['alias']].append(alias)
    for rule in memory['rules']:
        by_target[(rule['provider_brand_id'], rule['alias'])].append(rule)
    outputs = []
    for row in rows:
        label = normalize_text(row.get('raw_text') or row.get('normalized_input'))
        provider = row.get('provider_brand_id')
        item = {'input_id': row.get('id'), 'label': label, 'provider_brand_id': provider,
                'outcome': 'needs_source_evidence', 'planned_item_id': None,
                'writes_performed': False, 'offer_approved': False,
                'market_claim_inherited': False, 'candidate_item_ids': [],
                'next_action': 'research_provider_definition'}
        if row.get('input_type') != 'crawler':
            item.update(outcome='unsupported_input', next_action='use_dedicated_input_pipeline')
        elif not provider or not label:
            item.update(outcome='incomplete_input', next_action='fetch_missing_source_fields')
        elif row.get('normalized_input') and label != row['normalized_input']:
            item.update(outcome='input_normalization_changed', next_action='inspect_original_label')
        else:
            clinical = context(row)
            candidates = [alias for alias in by_label[label]
                          if alias['alias_scope'] == 'global' or alias['provider_brand_id'] == provider]
            item['candidate_item_ids'] = sorted({alias['item_id'] for alias in candidates})
            if clinical.get('patient_data_present'):
                item.update(outcome='unsupported_patient_context', next_action='isolate_private_input')
            elif clinical.get('unknown_fields') or clinical.get('unknown_study_fields'):
                item.update(outcome='unrecognized_source_fields', next_action='inspect_source_schema')
            elif len(item['candidate_item_ids']) > 1:
                item.update(outcome='ambiguous_approved_alias', next_action='research_disambiguation')
            else:
                signature = digest({'raw_text': row.get('raw_text'), 'context': clinical})
                matched = [rule for rule in by_target[(provider, label)]
                           if signature in rule['context_signatures']]
                matched_ids = {rule['item_id'] for rule in matched}
                matched_attributes = {digest(rule['source_attributes']) for rule in matched}
                if len(matched_ids) == 1 and len(matched_attributes) == 1:
                    item.update(outcome='reusable_exact_context', planned_item_id=matched[0]['item_id'],
                                review_ids=sorted({rule['review_id'] for rule in matched}),
                                source_attributes=matched[0]['source_attributes'],
                                next_action='preview_guarded_reuse_after_runtime_authorization')
                elif len(matched_ids) > 1 or len(matched_attributes) > 1:
                    item.update(outcome='ambiguous_context', next_action='research_disambiguation')
                elif by_target[(provider, label)]:
                    item.update(outcome='source_context_changed', next_action='fetch_changed_definition')
                elif candidates:
                    item.update(outcome='candidate_from_shared_catalog',
                                next_action='verify_new_provider_context')
        outputs.append(item)
    tasks = {}
    for row in outputs:
        if row['outcome'] == 'reusable_exact_context':
            continue
        key = (row['provider_brand_id'], row['label'], row['outcome'])
        task = tasks.setdefault(key, {
            'provider_brand_id': row['provider_brand_id'], 'label': row['label'],
            'outcome': row['outcome'], 'next_action': row['next_action'],
            'occurrences': 0, 'candidate_item_ids': row['candidate_item_ids'],
            'state': 'waiting_for_source_evidence',
            'retry_when': 'source_definition_or_rule_version_changes',
        })
        task['occurrences'] += 1
    return {'version': VERSION, 'observed_at': now(), 'shadow_only': True,
            'memory_sha256': digest(memory), 'rows': len(outputs),
            'outcomes': dict(Counter(row['outcome'] for row in outputs)),
            'writes_performed': False, 'decisions': outputs,
            'research_task_count': len(tasks), 'research_queue': list(tasks.values())}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    build = commands.add_parser('build')
    build.add_argument('--project-ref', required=True)
    build.add_argument('--output', type=Path, required=True)
    build.add_argument('--fixture-glob', default='reviewed-aliases-*.json')
    planning = commands.add_parser('plan')
    planning.add_argument('--memory', type=Path, required=True)
    planning.add_argument('--input', type=Path, required=True)
    planning.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.command == 'build':
        ref = (ROOT / 'database/supabase/.temp/project-ref').read_text().strip()
        if ref != args.project_ref:
            parser.error('Linked destination does not match --project-ref')
        paths = sorted((ROOT / 'database/data').glob(args.fixture_glob))
        if any(path.parent != ROOT / 'database/data' for path in paths):
            parser.error('Fixtures must reside directly inside database/data')
        with httpx.Client(base_url='https://api.supabase.com',
                          headers={'Authorization': 'Bearer ' + management_token()}, timeout=90) as client:
            result = compile_memory(client, ref, paths)
    else:
        memory = json.loads(args.memory.read_text(encoding='utf-8'))
        rows = json.loads(args.input.read_text(encoding='utf-8'))
        if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
            parser.error('--input must contain an array of crawler context objects')
        result = plan(memory, rows)
    save(args.output, result)
    print(json.dumps({key: result[key] for key in
                      ('version', 'shadow_only', 'reviews', 'historical_rows', 'rows', 'outcomes')
                      if key in result}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
