"""Prioritize public terminology research and retain evidenced unresolved work.

Local planning only. A hold never approves an equivalence, closes a record or
prevents reassessment after its source context, evidence, dependency or expiry
changes. No HTTP, SQL, scheduling or apply operation is provided.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
from uuid import UUID

from normalization_memory import context, digest, plan

ROOT = Path(__file__).resolve().parents[2]
REASONS = {'source_definition_incomplete', 'representation_missing', 'resolver_requirement_loss'}


def checked_file(reference: dict) -> bool:
    path = (ROOT / reference['path']).resolve()
    path.relative_to(ROOT)
    return path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == reference['sha256']


def signature(row: dict) -> str:
    return digest({'raw_text': row.get('raw_text'), 'context': context(row)})


def schedule(memory: dict, rows: list[dict], receipt: dict) -> dict:
    if not isinstance(rows, list) or any(not isinstance(row, dict) or row.get('input_type') != 'crawler'
                                        or context(row).get('patient_data_present') for row in rows):
        raise ValueError('Only public crawler contexts without patient identifiers are accepted')
    result = plan(memory, rows)
    if receipt.get('version') != 1 or not isinstance(receipt.get('holds'), list):
        raise ValueError('Expected version 1 research receipt with explicit holds')
    if receipt.get('project_ref') != memory['project_ref']:
        raise ValueError('Research receipt belongs to another project')
    now = datetime.now(timezone.utc)
    holds = {}
    for hold in receipt['holds']:
        UUID(hold['provider_brand_id'])
        key = (hold['provider_brand_id'], hold['normalized_input'])
        if key in holds or hold.get('reason') not in REASONS:
            raise ValueError('Duplicate hold or unknown research reason')
        if not hold.get('context_signatures') or not hold.get('evidence') or not hold.get('retry_when'):
            raise ValueError('Hold requires contexts, pinned evidence and a useful retry condition')
        if hold['reason'] != 'source_definition_incomplete' and not hold.get('dependencies'):
            raise ValueError('Implementation hold requires pinned dependency files')
        observed = datetime.fromisoformat(hold['observed_at'])
        expires = datetime.fromisoformat(hold['expires_at'])
        if observed.tzinfo is None or expires.tzinfo is None or expires <= observed:
            raise ValueError('Research dates must be ordered and include timezone')
        if (expires - observed).total_seconds() > 7 * 86400:
            raise ValueError('Research hold cannot suppress rechecks beyond seven days')
        files = hold['evidence'] + hold.get('dependencies', [])
        valid = observed <= now < expires and all(checked_file(ref) for ref in files)
        holds[key] = (hold, valid)
    grouped = defaultdict(list)
    row_by_id = {row['id']: row for row in rows}
    if len(row_by_id) != len(rows):
        raise ValueError('Duplicate input IDs; incomplete research inventory')
    for decision in result['decisions']:
        grouped[(decision['provider_brand_id'], decision['label'])].append(decision)
    queue = []
    for key, decisions in grouped.items():
        outcomes = sorted({item['outcome'] for item in decisions})
        hold, valid = holds.get(key, (None, False))
        current = {signature(row_by_id[item['input_id']]) for item in decisions}
        reusable = outcomes == ['reusable_exact_context']
        unsupported = any(outcome in {
            'unsupported_input', 'incomplete_input', 'input_normalization_changed',
            'unsupported_patient_context', 'unrecognized_source_fields',
        } for outcome in outcomes)
        deferred = bool(valid and not unsupported and not reusable
                        and current == set(hold['context_signatures']))
        state = ('exact_reuse_proposed' if reusable else 'source_schema_review' if unsupported
                 else 'waiting_for_change' if deferred else 'research_needed')
        task = {'provider_brand_id': key[0], 'normalized_input': key[1],
                'occurrences': len(decisions), 'state': state, 'outcomes': outcomes,
                'context_signatures': sorted(current), 'approved': False,
                'writes_performed': False, 'offer_approved': False}
        if deferred:
            task.update(reason=hold['reason'], retry_when=hold['retry_when'],
                        expires_at=hold['expires_at'], evidence=hold['evidence'])
        elif hold:
            task['previous_hold_requires_reassessment'] = True
        queue.append(task)
    queue.sort(key=lambda task: (-task['occurrences'], task['normalized_input'], str(task['provider_brand_id'])))
    states = sorted({task['state'] for task in queue})
    return {'version': 1, 'observed_at': now.isoformat(), 'project_ref': memory['project_ref'],
            'shadow_only': True, 'database_writes': 0, 'http_requests': 0,
            'input_memory_sha256': digest(memory), 'research_receipt_sha256': digest(receipt),
            'rows': len(rows), 'groups': len(queue),
            'groups_by_state': {state: sum(task['state'] == state for task in queue) for state in states},
            'rows_by_state': {state: sum(task['occurrences'] for task in queue if task['state'] == state) for state in states},
            'queue': queue}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--memory', type=Path, required=True)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--research-receipt', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = schedule(json.loads(args.memory.read_text(encoding='utf-8')),
                      json.loads(args.input.read_text(encoding='utf-8')),
                      json.loads(args.research_receipt.read_text(encoding='utf-8')))
    # Preserve prior planning evidence instead of silently replacing it.
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('x', encoding='utf-8') as target:
        json.dump(result, target, ensure_ascii=False, indent=2)
        target.write('\n')
    print(json.dumps({key: result[key] for key in
                      ('rows', 'groups', 'groups_by_state', 'rows_by_state', 'database_writes', 'http_requests')}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
