"""Retrieve cached LOINC candidates from NLM for curated public terminology.

Only an explicit terminology-only fixture is accepted. No patient inputs, RAW
records, model approvals, database writes or paid APIs are part of this command.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import time

import httpx

from run_local_review_queue import save

ENDPOINT = 'https://clinicaltables.nlm.nih.gov/api/loinc_items/v3/search'
FIELDS = 'COMPONENT,PROPERTY,METHOD_TYP,EXTERNAL_COPYRIGHT_NOTICE,isCopyrighted'


def retrieve(terms: list[str], cache: Path, *, cache_hours: int = 168) -> dict:
    receipts = []
    cache.mkdir(parents=True, exist_ok=True)
    with httpx.Client(timeout=30, follow_redirects=False,
                      headers={'User-Agent': 'Pruevia/terminology-research',
                               'Accept': 'application/json'}) as client:
        for term in dict.fromkeys(terms):
            params = {'terms': term, 'count': 7, 'df': 'LONG_COMMON_NAME,LOINC_NUM',
                      'ef': FIELDS, 'excludeCopyrighted': 'true'}
            key = hashlib.sha256(json.dumps(params, sort_keys=True).encode()).hexdigest()
            path = cache / (key + '.json')
            cached = json.loads(path.read_text(encoding='utf-8')) if path.exists() else None
            if cached:
                age = datetime.now(timezone.utc) - datetime.fromisoformat(cached['observed_at'])
                if (cached.get('http_status') == 200 and cached.get('endpoint') == ENDPOINT
                        and cached.get('params') == params
                        and 0 <= age.total_seconds() < cache_hours * 3600):
                    receipts.append({**cached, 'cache_hit': True})
                    continue
            receipt = {'term': term, 'endpoint': ENDPOINT, 'params': params,
                       'observed_at': datetime.now(timezone.utc).isoformat(),
                       'cache_hit': False, 'candidate_only': True,
                       'loinc_mapping_approved': False}
            try:
                response = client.get(ENDPOINT, params=params)
                receipt.update(http_status=response.status_code,
                               response_sha256=hashlib.sha256(response.content).hexdigest(),
                               retry_after=response.headers.get('Retry-After'))
                if response.status_code == 200:
                    data = response.json()
                    if (not isinstance(data, list) or len(data) < 4
                            or not isinstance(data[1], list) or len(data[1]) > 7
                            or not isinstance(data[2], dict) or not isinstance(data[3], list)
                            or len(data[3]) != len(data[1])):
                        raise ValueError('Unexpected NLM response shape')
                    receipt.update(total_reported=data[0], returned=len(data[1]),
                                   response=data, total_is_service_estimate=True)
                else:
                    receipt['error'] = 'upstream_http_error'
            except (httpx.HTTPError, ValueError):
                receipt['error'] = 'transport_or_response_error'
            save(path, receipt)
            receipts.append(receipt)
            # A source failure ends this run; replay resumes from cached successes.
            if receipt.get('error'):
                break
            time.sleep(1)
    return {'observed_at': datetime.now(timezone.utc).isoformat(),
            'mode': 'public_terminology_candidates', 'requested': len(set(terms)),
            'observed': len(receipts), 'complete': len(receipts) == len(set(terms)),
            'writes_to_database': False, 'paid_services_used': False,
            'receipts': receipts}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--terms', type=Path, required=True)
    parser.add_argument('--cache', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--loinc-index', type=Path)
    args = parser.parse_args()
    fixture = json.loads(args.terms.read_text(encoding='utf-8'))
    if (fixture.get('purpose') != 'public_catalog_terminology_only'
            or set(fixture) != {'purpose', 'terms'} or not isinstance(fixture['terms'], list)
            or not 1 <= len(fixture['terms']) <= 100
            or any(not isinstance(term, str) or not 1 <= len(term) <= 120
                   or any(ord(char) < 32 for char in term) for term in fixture['terms'])):
        parser.error('Provide 1–100 curated public terminology strings without patient information')
    result = retrieve(fixture['terms'], args.cache)
    if args.loinc_index:
        from loinc_release import _iter_index_rows
        manifest_path = args.loinc_index.with_suffix(args.loinc_index.suffix + '.manifest.json')
        manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
        actual_sha = hashlib.sha256(args.loinc_index.read_bytes()).hexdigest()
        if actual_sha != manifest.get('index_sha256'):
            parser.error('Local LOINC index checksum does not match its manifest')
        requested_codes = {code for receipt in result['receipts']
                           for code in receipt.get('response', [None, []])[1]}
        indexed = {row['LOINC_NUM']: row for row in _iter_index_rows(args.loinc_index)
                   if row['LOINC_NUM'] in requested_codes}
        for receipt in result['receipts']:
            receipt['local_code_details'] = [
                {'code': code, 'local_release': indexed.get(code), 'candidate_only': True,
                 'local_index_version': manifest['loinc_version'],
                 'missing_from_local_index': code not in indexed}
                for code in receipt.get('response', [None, []])[1]
            ]
        result['local_index'] = {'version': manifest['loinc_version'], 'sha256': actual_sha,
                                 'nlm_version_equivalence_claimed': False}
    save(args.output, result)
    print(json.dumps({'complete': result['complete'], 'observed': result['observed'],
                      'responses': [{'term': receipt['term'], 'status': receipt.get('http_status'),
                                     'candidates': receipt.get('total_reported'),
                                     'cache_hit': receipt['cache_hit']}
                                    for receipt in result['receipts']]}))
    return 0 if result['complete'] and all(not r.get('error') for r in result['receipts']) else 1


if __name__ == '__main__':
    raise SystemExit(main())
