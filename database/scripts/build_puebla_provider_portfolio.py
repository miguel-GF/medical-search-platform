"""Build a compact, auditable Puebla provider portfolio report.

The report joins DENUE identity candidates with the bounded generic discovery
manifest.  It is deliberately not a publication step: all identities remain
verification_pending and discovered labels remain candidate evidence until a
reviewed mapping is rendered separately.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any, Mapping
from urllib.parse import urlparse

try:
    from .artifact_io import MAX_FIXTURE_BYTES, read_json_file
except ImportError:  # pragma: no cover
    from artifact_io import MAX_FIXTURE_BYTES, read_json_file


PORTFOLIO_VERSION = "puebla-provider-portfolio-v1"


def _json(path: Path) -> Mapping[str, Any]:
    value = read_json_file(path, max_bytes=MAX_FIXTURE_BYTES)
    if not isinstance(value, Mapping):
        raise ValueError(f"JSON must be an object: {path}")
    return value


def _provider_rows(value: object) -> list[Mapping[str, Any]]:
    if not isinstance(value, list):
        raise ValueError("mapping fixture providers must be an array")
    rows = [row for row in value if isinstance(row, Mapping)]
    if len(rows) != len(value):
        raise ValueError("mapping fixture providers must contain objects")
    return rows


def _denue_rows(value: object) -> dict[str, Mapping[str, Any]]:
    if not isinstance(value, list):
        raise ValueError("DENUE candidates must be an array")
    result: dict[str, Mapping[str, Any]] = {}
    for row in value:
        if not isinstance(row, Mapping):
            raise ValueError("DENUE candidates must contain objects")
        key = str(row.get("external_record_id") or "").strip()
        if key:
            result[key] = row
    return result


def _host(value: object) -> str:
    try:
        host = (urlparse(str(value or "")).hostname or "").casefold().rstrip(".")
    except ValueError:
        return ""
    return host[4:] if host.startswith("www.") else host


def build_portfolio(
    manifest: Mapping[str, Any],
    mapping_fixture: Mapping[str, Any],
    denue_fixture: Mapping[str, Any],
) -> dict[str, Any]:
    if manifest.get("version") != "puebla-generic-discovery-v1":
        raise ValueError("unsupported Puebla discovery manifest version")
    providers = manifest.get("providers")
    if not isinstance(providers, list):
        raise ValueError("discovery manifest providers must be an array")
    manifest_by_key: dict[str, Mapping[str, Any]] = {}
    for row in providers:
        if not isinstance(row, Mapping):
            continue
        for url in row.get("seed_urls") or []:
            host = _host(url)
            if host:
                manifest_by_key[host] = row
    denue = _denue_rows(denue_fixture.get("candidates"))
    mapping_rows = _provider_rows(mapping_fixture.get("providers"))
    mappings = mapping_fixture.get("mappings")
    if not isinstance(mappings, list):
        raise ValueError("mapping fixture mappings must be an array")
    approved_counts = Counter(
        str(row.get("source_key") or "")
        for row in mappings
        if isinstance(row, Mapping)
    )
    portfolio: list[dict[str, Any]] = []
    for provider in mapping_rows:
        source_key = str(provider.get("source_key") or "").strip()
        if not source_key:
            raise ValueError("provider source_key cannot be empty")
        website = str(provider.get("website_url") or "").strip()
        host = _host(website)
        discovery = manifest_by_key.get(host) or {}
        denue_ids = [str(value).strip() for value in provider.get("denue_record_ids") or [] if str(value).strip()]
        locations = []
        for denue_id in denue_ids:
            row = denue.get(denue_id)
            if row is None:
                raise ValueError(f"provider {source_key} references missing DENUE row {denue_id}")
            locations.append(
                {
                    "denue_record_id": denue_id,
                    "name": row.get("name"),
                    "postal_code": row.get("postal_code"),
                    "phone": row.get("phone"),
                    "coordinates": row.get("coordinates"),
                }
            )
        portfolio.append(
            {
                "source_key": source_key,
                "provider_key": str(provider.get("provider_key") or ""),
                "brand_name": str(provider.get("brand_name") or ""),
                "website_url": website,
                "identity_status": "verification_pending",
                "discovery_status": discovery.get("status", "not_crawled"),
                "discovery_run_id": discovery.get("run_id"),
                "records_received": int(discovery.get("records_received", 0) or 0),
                "records_valid": int(discovery.get("records_valid", 0) or 0),
                "discovered_offers": int(discovery.get("offers", 0) or 0),
                "discovered_locations": int(discovery.get("locations", 0) or 0),
                "priced_offers": int(discovery.get("priced_offers", 0) or 0),
                "approved_exact_mappings": approved_counts.get(source_key, 0),
                "denue_locations": locations,
                "identity_note": str(provider.get("identity_note") or ""),
            }
        )
    totals = {
        "providers": len(portfolio),
        "providers_with_website_evidence": sum(row["discovery_status"] in {"succeeded", "quarantined"} for row in portfolio),
        "denue_locations": sum(len(row["denue_locations"]) for row in portfolio),
        "discovered_offers": sum(row["discovered_offers"] for row in portfolio),
        "discovered_locations": sum(row["discovered_locations"] for row in portfolio),
        "priced_offers": sum(row["priced_offers"] for row in portfolio),
        "approved_exact_mappings": sum(row["approved_exact_mappings"] for row in portfolio),
    }
    return {
        "version": PORTFOLIO_VERSION,
        "policy": "Candidate identity and public website evidence only; no provider or clinical offer is verified by this report.",
        "source_run_id": manifest.get("fixture_source_run_id"),
        "discovery_manifest": "puebla_generic_discovery_manifest.json",
        "totals": totals,
        "providers": sorted(portfolio, key=lambda row: (row["brand_name"].casefold(), row["source_key"])),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the Puebla candidate provider portfolio")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--mapping-fixture", type=Path, required=True)
    parser.add_argument("--denue-fixture", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        report = build_portfolio(_json(args.manifest), _json(args.mapping_fixture), _json(args.denue_fixture))
    except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        print(json.dumps({"status": "blocked", "error": str(error)}, ensure_ascii=False, indent=2))
        return 2
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": "succeeded", "providers": report["totals"]["providers"], "offers": report["totals"]["discovered_offers"]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
