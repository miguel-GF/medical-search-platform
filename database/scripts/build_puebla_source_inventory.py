"""Build a coverage inventory from the Puebla DENUE snapshot and crawl manifest.

This is a read-only report.  DENUE rows are leads, not verified providers; the
report intentionally keeps priority chains and the long tail separate.
"""

from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import Counter
from pathlib import Path
from typing import Any, Mapping

try:
    from .artifact_io import MAX_FIXTURE_BYTES, read_json_file
except ImportError:  # pragma: no cover
    from artifact_io import MAX_FIXTURE_BYTES, read_json_file


PRIORITY_ALIASES: dict[str, tuple[str, ...]] = {
    "salud_digna": ("salud digna",),
    "chopo": ("chopo", "grupo diagnostico medico proa"),
    "ruiz": ("laboratorio ruiz", "laboratorios ruiz"),
    "semin": ("semin",),
    "dr_simi": ("dr simi", "doctor simi", "sistemas de salud del dr simi", "farmacias lideres"),
    "farmacias_del_ahorro": ("farmacias del ahorro", "comercializadora farmaceutica de chiapas"),
    "polanco": ("laboratorio medico polanco",),
    "linfolab": ("linfolab",),
    "exacta": ("exacta", "laboratorios bio analisis", "quimica exacta"),
    "gaya": ("gaya", "biotec genus"),
    "guadalupe": ("guadalupe",),
    "asesores": ("asesores especializados en laboratorios", "laboratorio asesores"),
}


def normalize(value: object) -> str:
    plain = "".join(char for char in unicodedata.normalize("NFKD", str(value or "").casefold()) if not unicodedata.combining(char))
    return re.sub(r"[^a-z0-9]+", " ", plain).strip()


def _json(path: Path) -> Mapping[str, Any]:
    value = read_json_file(path, max_bytes=MAX_FIXTURE_BYTES)
    if not isinstance(value, Mapping):
        raise ValueError(f"JSON must be an object: {path}")
    return value


def _rows(fixture: Mapping[str, Any]) -> list[Mapping[str, Any]]:
    candidates = fixture.get("candidates")
    review_queue = fixture.get("review_queue", [])
    if not isinstance(candidates, list) or not isinstance(review_queue, list):
        raise ValueError("DENUE fixture must contain candidates and review_queue arrays")
    return [row for group in (candidates, review_queue) for row in group if isinstance(row, Mapping)]


def _priority_key(row: Mapping[str, Any]) -> str | None:
    haystack = normalize(f"{row.get('name', '')} {row.get('legal_name', '')}")
    for key, aliases in PRIORITY_ALIASES.items():
        if any(normalize(alias) in haystack for alias in aliases):
            return key
    return None


def build_inventory(fixture: Mapping[str, Any], discovery: Mapping[str, Any] | None = None) -> dict[str, Any]:
    rows = _rows(fixture)
    direct = [row for row in rows if str(row.get("classification") or "") == "direct_clinical"]
    related = [row for row in rows if str(row.get("classification") or "") == "related_clinical"]
    host_counter: Counter[str] = Counter()
    for row in direct:
        value = str(row.get("website_url") or "").strip()
        if value:
            host = re.sub(r"^https?://", "", value.casefold()).split("/", 1)[0].removeprefix("www.")
            host_counter[host] += 1
    groups: dict[str, dict[str, Any]] = {
        key: {"denue_records": 0, "with_website": 0, "without_website": 0}
        for key in PRIORITY_ALIASES
    }
    ungrouped = 0
    for row in direct:
        key = _priority_key(row)
        if key is None:
            ungrouped += 1
            continue
        group = groups[key]
        group["denue_records"] += 1
        if str(row.get("website_url") or "").strip():
            group["with_website"] += 1
        else:
            group["without_website"] += 1
    result: dict[str, Any] = {
        "version": "puebla-source-inventory-v1",
        "source_fixture": fixture.get("source_run_id"),
        "denue": {
            "source_records": fixture.get("source_records", len(rows)),
            "direct_clinical": len(direct),
            "related_clinical": len(related),
            "direct_with_website": sum(bool(str(row.get("website_url") or "").strip()) for row in direct),
            "direct_without_website": sum(not bool(str(row.get("website_url") or "").strip()) for row in direct),
            "unique_website_hosts": len(host_counter),
            "ungrouped_direct_records": ungrouped,
        },
        "priority_groups": groups,
        "top_hosts": [{"host": host, "records": count} for host, count in host_counter.most_common(30)],
    }
    if discovery is not None:
        providers = discovery.get("providers")
        if not isinstance(providers, list):
            raise ValueError("discovery manifest providers must be an array")
        status_counts = Counter(str(row.get("status") or "unknown") for row in providers if isinstance(row, Mapping))
        result["generic_discovery"] = {
            "hosts_considered": len(providers),
            "status_counts": dict(sorted(status_counts.items())),
            "records_valid": sum(int(row.get("records_valid") or 0) for row in providers if isinstance(row, Mapping)),
            "locations": sum(int(row.get("locations") or 0) for row in providers if isinstance(row, Mapping)),
            "offers": sum(int(row.get("offers") or 0) for row in providers if isinstance(row, Mapping)),
        }
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a read-only Puebla provider source inventory")
    parser.add_argument("--denue-fixture", type=Path, required=True)
    parser.add_argument("--discovery-manifest", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        report = build_inventory(_json(args.denue_fixture), _json(args.discovery_manifest) if args.discovery_manifest else None)
    except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
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
