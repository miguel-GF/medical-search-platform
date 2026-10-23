"""Read-only production catalog and public HTTP checks for the bounded release."""
import argparse
import json
from pathlib import Path

import httpx

import clinical_candidate_evaluation as ev
from release_clinical_reconciliation import EXPORT, PROPOSAL
from run_local_review_queue import query


def public_check(label, expected, status, payload):
    services = [r.get('service', {}) for r in payload.get('results', [])]
    resolved = {s.get('id') for s in services if s.get('resolution_status') == 'resolved'}
    # The existing api_search offer response omits resolution_status. Its exact
    # identity must be checked, rather than treating an absent optional field as
    # proof of no match. api_resolve_search candidates carry explicit status.
    positive = {s.get('id') for s in services}
    ok = status == 200 and (expected is None or (positive == {expected} and all(s.get('resolution_status', 'resolved') == 'resolved' for s in services)))
    if label in ['renina', 'Plasmodium', 'Biometría hemática INR', 'Biometría hemática x2']:
        ok = ok and not resolved
    return {'query': label, 'status': status, 'expected_id': expected, 'returned_ids': sorted(positive), 'resolved_ids': sorted(resolved), 'pass': ok}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--folder', type=Path, required=True)
    parser.add_argument('--reassess-saved-http', action='store_true')
    args = parser.parse_args()
    folder = ev.within_artifacts(args.folder)
    output = folder / 'public-verification'
    if args.reassess_saved_http:
        previous = json.loads((output / 'summary.json').read_bytes())
        public = []
        index = 0
        for case in previous['public_checks']:
            if case.get('selection'):
                public.append(case)
                continue
            record = json.loads((output / ('http-' + str(index) + '.json')).read_bytes())
            assert record['query'] == case['query']
            public.append(public_check(case['query'], case['expected_id'], record['http_status'], record['payload']))
            index += 1
        report = {**previous, 'at': ev.now(), 'public_checks': public, 'pass': not previous['canonical_failures'] and all(c['pass'] for c in public), 'reassessment_reason': 'Offer response omits optional resolution_status; exact identity and any explicit status are checked. Original HTTP receipts and initial report preserved.', 'new_http_requests': 0}
        ev.write_new(output / 'summary-reassessed.json', report)
        print(json.dumps({'canonical_names': report['canonical_names'], 'canonical_correct': report['canonical_correct'], 'public_checks': len(public), 'public_failed': [c for c in public if not c['pass']], 'pass': report['pass'], 'new_http_requests': 0}))
        if not report['pass']:
            raise SystemExit(2)
        return
    output.mkdir(exist_ok=False)
    assert json.loads((folder / 'deployment/verified.json').read_bytes())['deployed']
    active = {r['id'] for r in json.loads((EXPORT / 'catalog.items.json').read_bytes()) if r['status'] == 'active'}
    names = [r for r in json.loads((EXPORT / 'catalog.item_names.json').read_bytes()) if r['is_primary'] and r['item_id'] in active]
    observations = []
    with ev.client() as db:
        for start in range(0, len(names), 30):
            batch = names[start:start + 30]
            sql = ' union all '.join('select ' + ev.q(n['item_id']) + ' expected_id,' + ev.q(n['name']) + " label,coalesce((select jsonb_agg(to_jsonb(r)) from catalog.resolve_items_v6(" + ev.q(n['name']) + ",'health_diagnostics',null,10) r),'[]'::jsonb) results" for n in batch)
            rows = query(db, ev.PROJECT, sql)
            assert len(rows) == len(batch)
            observations.extend(rows)
            ev.write_new(output / ('canonical-batch-' + str(start) + '.json'), rows)
        inventory = query(db, ev.PROJECT, "select (select count(*) from core.provider_brands) brands,(select count(*) from core.provider_locations) locations,(select count(*) from catalog.items where status='active') active_concepts,(select count(*) from supply.offers where status='active') active_offers,(select count(*) from supabase_migrations.schema_migrations) migrations,(select count(*) from audit.events where request_id='canonical-reconciliation-20261023' and action='catalog.clinical_reconciliation_approved') release_audits")
    failures = [r['label'] for r in observations if {x['item_id'] for x in r['results'] if x['resolution_status'] == 'resolved'} != {r['expected_id']}]
    ev.write_new(output / 'inventory.json', inventory)
    assert inventory[0]['release_audits'] == 1 and inventory[0]['migrations'] == 115
    assert inventory[0]['brands'] == 207 and inventory[0]['locations'] == 293
    assert inventory[0]['active_concepts'] == 564 and inventory[0]['active_offers'] == 234
    prep = json.loads((PROPOSAL / 'preparation.json').read_bytes())
    cases = [(r['name'], r['item_id']) for r in prep['imaging_changes']]
    cases += [('t3 libre', 'ee4001a7-229d-5b99-bbbf-9c44aca29fe8')]
    cases += [(name, None) for name in ['hematica', 'biometria', 'orina', 'sangre', 'electro', 'electrocardiograma', 'Biometría hemática', 'renina', 'Plasmodium', 'Biometría hemática INR', 'Biometría hemática x2']]
    public = []
    with httpx.Client(timeout=45) as web:
        for index, (label, expected) in enumerate(cases):
            response = web.get('https://api.pruevia.com.mx/api/v1/search', params={'q': label, 'notice_supported': '1'}, headers={'Origin': 'https://app.pruevia.com.mx'})
            payload = response.json()
            record = {'query': label, 'http_status': response.status_code, 'payload': payload}
            ev.write_new(output / ('http-' + str(index) + '.json'), record)
            services = [r.get('service', {}) for r in payload.get('results', [])]
            public.append(public_check(label, expected, response.status_code, payload))
            if label in ['hematica', 'biometria', 'electro'] and services:
                chosen = services[0]['id']
                selected = web.get('https://api.pruevia.com.mx/api/v1/search', params={'q': label, 'selected_service_id': chosen}, headers={'Origin': 'https://app.pruevia.com.mx'})
                chosen_payload = selected.json()
                selected_services = [r.get('service', {}) for r in chosen_payload.get('results', [])]
                selection_ok = selected.status_code == 200 and len(selected_services) == 1 and selected_services[0].get('id') == chosen and selected_services[0].get('selection_method') == 'user_confirmed'
                ev.write_new(output / ('selection-' + label + '.json'), {'status': selected.status_code, 'payload': chosen_payload, 'pass': selection_ok})
                public.append({'query': label, 'selection': True, 'pass': selection_ok})
    report = {'at': ev.now(), 'canonical_names': len(observations), 'canonical_correct': len(observations) - len(failures), 'canonical_failures': failures, 'public_checks': public, 'pass': not failures and all(r['pass'] for r in public), 'limitations': ['Read-only probes do not establish provider availability for every concept', 'No pending crawler record is closed by this release']}
    ev.write_new(output / 'summary.json', report)
    print(json.dumps({'canonical_names': len(observations), 'canonical_correct': len(observations) - len(failures), 'public_checks': len(public), 'public_failed': [c for c in public if not c['pass']], 'pass': report['pass']}))
    if not report['pass']:
        raise SystemExit(2)


if __name__ == '__main__':
    main()
