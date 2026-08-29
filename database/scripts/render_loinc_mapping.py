"""Validate a reviewed LOINC mapping fixture and render an idempotent SQL migration."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


LOINC_SYSTEM = "http://loinc.org"
LOINC_CODE_RE = re.compile(r"^[A-Za-z0-9]{1,12}-[0-9]$")
MAPPING_TYPES = {"exact", "narrower", "broader", "related", "local"}
STATUSES = {"active", "deprecated", "rejected"}
ATTRIBUTE_FIELDS = (
    "component",
    "property",
    "time_aspect",
    "system",
    "scale_type",
    "method",
    "order_observation",
)
ORDER_OBSERVATION = {"order", "observation", "both", "unknown"}


def _sql(value: object) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    escaped = str(value).replace("'", "''")
    return f"'{escaped}'"


def load_fixture(path: Path) -> dict:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("LOINC fixture root must be an object")
    version = str(payload.get("loinc_version") or "").strip()
    if not version:
        raise ValueError("LOINC fixture requires loinc_version")
    mappings = payload.get("mappings")
    if not isinstance(mappings, list):
        raise ValueError("LOINC fixture requires a mappings array")
    return payload


def validate_fixture(payload: dict) -> None:
    seen: set[tuple[str, str]] = set()
    for index, mapping in enumerate(payload["mappings"]):
        if not isinstance(mapping, dict):
            raise ValueError(f"mapping {index} must be an object")
        item_id = str(mapping.get("item_id") or "").strip()
        if not item_id:
            raise ValueError(f"mapping {index} requires item_id")
        code = str(mapping.get("loinc_code") or "").strip()
        if not LOINC_CODE_RE.fullmatch(code):
            raise ValueError(f"mapping {index} has invalid LOINC code: {code!r}")
        identity = (item_id, code)
        if identity in seen:
            raise ValueError(f"duplicate mapping: {item_id} / {code}")
        seen.add(identity)
        mapping_type = str(mapping.get("mapping_type") or "exact")
        if mapping_type not in MAPPING_TYPES:
            raise ValueError(f"mapping {index} has invalid mapping_type: {mapping_type}")
        status = str(mapping.get("status") or "active")
        if status not in STATUSES:
            raise ValueError(f"mapping {index} has invalid status: {status}")
        if mapping_type == "exact" and not mapping.get("verified", False):
            raise ValueError(f"exact mapping {index} must set verified=true")
        attrs = mapping.get("attributes") or {}
        if not isinstance(attrs, dict):
            raise ValueError(f"mapping {index} attributes must be an object")
        order_observation = attrs.get("order_observation")
        if order_observation is not None and order_observation not in ORDER_OBSERVATION:
            raise ValueError(f"mapping {index} has invalid order_observation: {order_observation}")


def render(payload: dict) -> str:
    validate_fixture(payload)
    version = str(payload["loinc_version"])
    lines = [
        "-- Generated from a reviewed LOINC mapping fixture.",
        "-- Do not edit manually; regenerate after reviewer approval.",
        "begin;",
    ]
    for mapping in payload["mappings"]:
        item_id = str(mapping["item_id"])
        code = str(mapping["loinc_code"])
        mapping_type = str(mapping.get("mapping_type") or "exact")
        status = str(mapping.get("status") or "active")
        note = str(mapping.get("source_note") or f"Reviewed LOINC {version}")
        lines.append(
            "insert into catalog.item_identifiers "
            "(item_id, system, code, version, mapping_type, status, source_note) values ("
            f"{_sql(item_id)}, {_sql(LOINC_SYSTEM)}, {_sql(code)}, {_sql(version)}, "
            f"{_sql(mapping_type)}, {_sql(status)}, {_sql(note)}) "
            "on conflict (item_id, system, code, version) do update set "
            "mapping_type = excluded.mapping_type, status = excluded.status, "
            "source_note = excluded.source_note;"
        )

        attributes = mapping.get("attributes") or {}
        assignments = []
        for field in ATTRIBUTE_FIELDS:
            if field in attributes:
                assignments.append(f"{field} = coalesce(excluded.{field}, health.lab_service_definitions.{field})")
        assignments.extend(
            [
                "loinc_version = excluded.loinc_version",
                "verified = excluded.verified",
                "source_note = excluded.source_note",
            ]
        )
        values = [attributes.get(field) for field in ATTRIBUTE_FIELDS]
        if values[-1] is None:
            values[-1] = "unknown"
        values.extend([version, bool(mapping.get("verified", False)), note])
        lines.append(
            "insert into health.lab_service_definitions "
            "(service_id, component, property, time_aspect, system, scale_type, method, "
            "order_observation, loinc_version, verified, source_note) values ("
            f"{_sql(item_id)}, "
            + ", ".join(_sql(value) for value in values)
            + ") on conflict (service_id) do update set "
            + ", ".join(assignments)
            + ";"
        )
    lines.append("commit;")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    payload = load_fixture(args.fixture)
    sql = render(payload)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(sql, encoding="utf-8", newline="\n")
    print(json.dumps({"mappings": len(payload["mappings"]), "output": str(args.output)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
