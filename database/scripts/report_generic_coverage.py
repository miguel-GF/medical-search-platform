"""Summarize generic Puebla discovery, review and retry coverage.

This report intentionally separates discovered evidence from approved
canonical mappings.  A large number of pages or labels never counts as search
coverage until a reviewed mapping exists.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Mapping

try:  # Package import for tests; direct import for the CLI entrypoint.
    from .artifact_io import MAX_FIXTURE_BYTES, read_json_file
except ImportError:  # pragma: no cover - exercised by direct script invocation
    from artifact_io import MAX_FIXTURE_BYTES, read_json_file


def _json(path: Path) -> Mapping[str, Any]:
    try:
        value = read_json_file(path, max_bytes=MAX_FIXTURE_BYTES)
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as error:
        raise ValueError(f"invalid coverage JSON: {path}: {error}") from error
    if not isinstance(value, Mapping):
        raise ValueError(f"coverage JSON must be an object: {path}")
    return value


def build_report(
    manifest: Mapping[str, Any],
    mapping_fixture: Mapping[str, Any],
    retry_manifest: Mapping[str, Any] | None = None,
    *,
    denue_source_records: int | None = None,
) -> dict[str, Any]:
    if manifest.get("version") != "puebla-generic-discovery-v1":
        raise ValueError("unsupported discovery manifest version")
    mappings = mapping_fixture.get("mappings")
    if not isinstance(mappings, list):
        raise ValueError("mapping fixture must contain a mappings array")
    providers = manifest.get("providers")
    if not isinstance(providers, list):
        raise ValueError("discovery manifest must contain a providers array")
    unique_mapping_records = {(str(row.get("source_key")), str(row.get("external_record_id"))) for row in mappings if isinstance(row, Mapping)}
    totals = manifest.get("totals")
    if not isinstance(totals, Mapping):
        raise ValueError("discovery manifest must contain totals")
    discovered_offers = int(totals.get("offers", 0))
    status_counts = manifest.get("status_counts", {})
    inferred_status = "succeeded" if status_counts and all(key == "succeeded" for key in status_counts) else "partial"
    result: dict[str, Any] = {
        "version": "puebla-generic-coverage-v1",
        "discovery_status": manifest.get("status") or inferred_status,
        "denue_source_records": denue_source_records if denue_source_records is not None else manifest.get("denue_source_records", manifest.get("source_records")),
        "denue_rows_considered": manifest.get("denue_rows_considered"),
        "rows_with_website": manifest.get("rows_with_website"),
        "unique_hosts": manifest.get("unique_hosts"),
        "status_counts": status_counts,
        "pages_fetched": totals.get("pages_fetched", 0),
        "pages_failed": totals.get("pages_failed", 0),
        "discovered_locations": totals.get("locations", 0),
        "discovered_offers": discovered_offers,
        "approved_mapping_records": len(unique_mapping_records),
        "unmapped_offer_records": max(0, discovered_offers - len(unique_mapping_records)),
        "approved_catalog_items": len({str(row.get("catalog_item_id")) for row in mappings if isinstance(row, Mapping)}),
        "approved_mapping_providers": len({str(row.get("provider_key")) for row in mappings if isinstance(row, Mapping)}),
    }
    if retry_manifest is not None:
        if retry_manifest.get("version") != "puebla-generic-retry-v1":
            raise ValueError("unsupported retry manifest version")
        result["retry"] = {
            "providers_considered": retry_manifest.get("providers_considered", 0),
            "status_counts": retry_manifest.get("status_counts", {}),
            "totals": retry_manifest.get("totals", {}),
        }
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Report Puebla generic discovery coverage")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--mapping-fixture", type=Path, required=True)
    parser.add_argument("--retry-manifest", type=Path)
    parser.add_argument("--denue-source-records", type=int)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        report = build_report(
            _json(args.manifest),
            _json(args.mapping_fixture),
            _json(args.retry_manifest) if args.retry_manifest else None,
            denue_source_records=args.denue_source_records,
        )
    except ValueError as error:
        print(json.dumps({"status": "blocked", "error": str(error)}, ensure_ascii=False, indent=2))
        return 2
    encoded = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    print(encoded, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
