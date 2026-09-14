"""Measure an anonymized query corpus against the public package resolver.

This is a read-only diagnostic, not a release gate.  It keeps the expected
user intent separate from the resolver result so an unresolved catalog gap is
not confused with a safe abstention, and it reports unexpected resolutions for
review instead of treating them as wins.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
import os
from pathlib import Path
from typing import Any, Mapping, Sequence

import psycopg


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_FIXTURE = ROOT / "database" / "fixtures" / "public_query_research_v1.json"
MAX_QUERY_LENGTH = 120
RESOLUTION_ACTIONS = {"resolve", "resolve_plus_preparation"}


def read_fixture(path: Path) -> list[dict[str, Any]]:
    """Load only the bounded, anonymized records used for measurement."""
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError(f"invalid query fixture: {path}: {error}") from error
    if not isinstance(value, Mapping) or value.get("version") != "public-query-research-v1":
        raise ValueError("unsupported query fixture version")
    records = value.get("records")
    if not isinstance(records, list) or not records:
        raise ValueError("query fixture must contain a non-empty records array")
    forbidden = {"username", "author", "email", "address", "diagnosis", "post_body"}
    if forbidden.intersection(value):
        raise ValueError("query fixture contains forbidden personal-data fields")
    result: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    for record in records:
        if not isinstance(record, Mapping):
            raise ValueError("query fixture contains a malformed record")
        record_id = record.get("id")
        query = record.get("query")
        action = record.get("expected_action")
        if (
            not isinstance(record_id, str)
            or not record_id
            or record_id in seen_ids
            or not isinstance(query, str)
            or not query.strip()
            or len(query) > MAX_QUERY_LENGTH
            or not isinstance(action, str)
            or not action
        ):
            raise ValueError("query fixture contains an invalid id, query or expected_action")
        seen_ids.add(record_id)
        result.append({"id": record_id, "query": query, "expected_action": action})
    return result


def _as_payload(value: Any) -> Mapping[str, Any]:
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except json.JSONDecodeError:
            value = None
    if not isinstance(value, Mapping):
        return {}
    return value


def summarize_results(results: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    """Build a stable summary without retaining query text or RPC internals."""
    expected = Counter(str(row.get("expected_action", "unknown")) for row in results)
    actual = Counter(str(row.get("actual_status", "invalid")) for row in results)
    strict_resolve = [row for row in results if row.get("expected_action") == "resolve"]
    resolution_expected = [row for row in results if row.get("expected_action") in RESOLUTION_ACTIONS]
    resolved_expected = [row for row in resolution_expected if row.get("actual_status") == "resolved"]
    unexpected_resolved = [
        row for row in results
        if row.get("actual_status") == "resolved" and row.get("expected_action") not in RESOLUTION_ACTIONS
    ]
    return {
        "records": len(results),
        "expected_action_counts": dict(sorted(expected.items())),
        "actual_status_counts": dict(sorted(actual.items())),
        "strict_resolve": {
            "total": len(strict_resolve),
            "resolved": sum(row.get("actual_status") == "resolved" for row in strict_resolve),
            "not_resolved": sum(row.get("actual_status") != "resolved" for row in strict_resolve),
        },
        "resolution_expected": {
            "total": len(resolution_expected),
            "resolved": len(resolved_expected),
            "not_resolved": len(resolution_expected) - len(resolved_expected),
        },
        "unexpected_resolved_count": len(unexpected_resolved),
        "unexpected_resolved_ids": sorted(str(row["id"]) for row in unexpected_resolved),
        "unresolved_expected_ids": sorted(
            str(row["id"]) for row in resolution_expected if row.get("actual_status") != "resolved"
        ),
    }


def measure(dsn: str, records: Sequence[Mapping[str, Any]]) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    """Call one package RPC per fixture row inside a read-only transaction."""
    results: list[dict[str, Any]] = []
    with psycopg.connect(dsn, connect_timeout=15, options="-c default_transaction_read_only=on") as connection:
        with connection.cursor() as cursor:
            for record in records:
                cursor.execute(
                    "select public.api_resolve_package(%s::jsonb)",
                    (json.dumps([record["query"]], ensure_ascii=False),),
                )
                payload = _as_payload(cursor.fetchone()[0] if cursor.description else None)
                items = payload.get("items")
                item_list = items if isinstance(items, list) else []
                statuses = [
                    str(item.get("status", "invalid"))
                    for item in item_list
                    if isinstance(item, Mapping)
                ]
                package_status = payload.get("package_status")
                actual_status = (
                    statuses[0]
                    if len(statuses) == 1
                    else str(package_status) if isinstance(package_status, str) else "invalid"
                )
                results.append({
                    "id": record["id"],
                    "expected_action": record["expected_action"],
                    "actual_status": actual_status,
                    "package_status": package_status if isinstance(package_status, str) else None,
                    "coverage_status": payload.get("coverage_status") if isinstance(payload.get("coverage_status"), str) else None,
                    "item_count": len(item_list),
                    "resolved_item_count": sum(status == "resolved" for status in statuses),
                    "candidate_count": sum(
                        len(item.get("candidates", []))
                        for item in item_list
                        if isinstance(item, Mapping) and isinstance(item.get("candidates"), list)
                    ),
                })
    return summarize_results(results), results


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dsn", default=os.getenv("PRUEVIA_DATABASE_URL"), help="PostgreSQL DSN; defaults to PRUEVIA_DATABASE_URL")
    parser.add_argument("--fixture", type=Path, default=DEFAULT_FIXTURE)
    parser.add_argument("--output", type=Path, help="Optional JSON report path")
    args = parser.parse_args()
    if not args.dsn:
        parser.error("PRUEVIA_DATABASE_URL or --dsn is required")
    try:
        records = read_fixture(args.fixture)
        summary, results = measure(args.dsn, records)
    except (OSError, ValueError, psycopg.Error) as error:
        print(json.dumps({"status": "blocked", "error": str(error)}, ensure_ascii=False, indent=2))
        return 2
    report = {
        "version": "query-coverage-report-v1",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "fixture": str(args.fixture),
        "read_only": True,
        "summary": summary,
        "results": results,
    }
    encoded = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    print(encoded, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
