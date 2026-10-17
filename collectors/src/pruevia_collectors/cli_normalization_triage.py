"""Fetch grouped crawler backlog and catalog terms with service-role read access."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from urllib.parse import urlparse

import httpx
from dotenv import load_dotenv

from pruevia_collectors.normalization_triage import triage


def _safe_supabase_url(value: str) -> str:
    parsed = urlparse(value)
    if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise ValueError('SUPABASE_URL must be a clean HTTPS origin')
    if parsed.path not in {'', '/'}:
        raise ValueError('SUPABASE_URL must not include a path')
    return value.rstrip('/')


def _fetch_pages(client: httpx.Client, rpc_name: str, page_size: int, *, max_rows: int) -> list[dict]:
    rows: list[dict] = []
    while len(rows) < max_rows:
        payload = {'p_limit': page_size, 'p_offset': len(rows)}
        if rpc_name == 'api_admin_normalization_groups':
            payload.update({'p_status': None, 'p_query': None})
        response = client.post(f'/rest/v1/rpc/{rpc_name}', json=payload)
        response.raise_for_status()
        batch = response.json()
        if not isinstance(batch, list):
            raise ValueError(f'{rpc_name} did not return a list')
        rows.extend(batch)
        if len(batch) < page_size:
            return rows
    raise ValueError(f'{rpc_name} reached its pagination limit; refuse an incomplete report')


def main() -> None:
    parser = argparse.ArgumentParser(description='Read-only normalization triage; never writes to Supabase')
    parser.add_argument('--groups-fixture', type=Path)
    parser.add_argument('--terms-fixture', type=Path)
    parser.add_argument('--env-file', type=Path, help='local ignored environment file; never printed')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if bool(args.groups_fixture) != bool(args.terms_fixture):
        parser.error('both fixture files are required together')
    if args.env_file:
        load_dotenv(args.env_file, override=False)

    if args.groups_fixture:
        groups = json.loads(args.groups_fixture.read_text(encoding='utf-8'))
        terms = json.loads(args.terms_fixture.read_text(encoding='utf-8'))
    else:
        endpoint = _safe_supabase_url(os.environ.get('SUPABASE_URL', ''))
        key = os.environ.get('SUPABASE_SECRET_KEY') or os.environ.get('SUPABASE_SERVICE_ROLE_KEY')
        if not key:
            parser.error('SUPABASE_SECRET_KEY or SUPABASE_SERVICE_ROLE_KEY is required')
        # This endpoint is service-role only, bounded and read-only. Do not log
        # request headers or response bodies on failure.
        with httpx.Client(base_url=endpoint, headers={
            'apikey': key, 'Authorization': f'Bearer {key}',
        }, timeout=30.0) as client:
            groups = _fetch_pages(client, 'api_admin_normalization_groups', 200, max_rows=100000)
            terms = _fetch_pages(client, 'api_admin_catalog_terms', 500, max_rows=100000)

    report = triage(groups, terms)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f"Read-only triage: {report['group_count']} groups, {report['represented_rows']} rows. Report: {args.output}")


if __name__ == '__main__':
    main()
