"""Validate a reviewed LOINC mapping fixture and render an idempotent SQL migration."""

from __future__ import annotations

import argparse
import hashlib
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
INDEX_ATTRIBUTE_FIELDS = {
    "component": "COMPONENT",
    "property": "PROPERTY",
    "time_aspect": "TIME_ASPCT",
    "system": "SYSTEM",
    "scale_type": "SCALE_TYP",
    "method": "METHOD_TYP",
    "order_observation": "ORDER_OBS",
}


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


def _load_index(index_path: Path) -> dict[str, dict[str, str]]:
    rows: dict[str, dict[str, str]] = {}
    with index_path.open("r", encoding="utf-8") as source:
        for line_number, line in enumerate(source, start=1):
            if not line.strip():
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError as error:
                raise ValueError(f"Invalid LOINC index JSON at {index_path}:{line_number}") from error
            if not isinstance(row, dict):
                raise ValueError(f"LOINC index row {line_number} must be an object")
            code = str(row.get("LOINC_NUM") or "").strip()
            if not LOINC_CODE_RE.fullmatch(code):
                raise ValueError(f"LOINC index row {line_number} has invalid LOINC_NUM: {code!r}")
            if code in rows:
                raise ValueError(f"LOINC index contains duplicate code: {code}")
            rows[code] = {str(key): str(value or "").strip() for key, value in row.items()}
    return rows


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _validate_index_manifest(
    payload: dict,
    index_path: Path,
    *,
    required: bool,
) -> None:
    manifest_path = index_path.with_suffix(index_path.suffix + ".manifest.json")
    if not manifest_path.exists():
        if required:
            raise ValueError(f"LOINC index manifest is required: {manifest_path}")
        return
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise ValueError(f"Invalid LOINC index manifest: {manifest_path}") from error
    if not isinstance(manifest, dict):
        raise ValueError("LOINC index manifest must be an object")
    expected_version = str(payload.get("loinc_version") or "").strip()
    if str(manifest.get("loinc_version") or "").strip() != expected_version:
        raise ValueError("LOINC fixture version does not match the supplied index manifest")
    expected_hash = str(manifest.get("index_sha256") or "").strip().lower()
    if not expected_hash or expected_hash != _sha256_file(index_path).lower():
        raise ValueError("LOINC index SHA-256 does not match its manifest")


def _normalized_attribute(value: object) -> str:
    return " ".join(str(value or "").casefold().split())


def _validate_index_mapping(mapping: dict, index_row: dict[str, str], index_code: str) -> None:
    index_status = _normalized_attribute(index_row.get("STATUS"))
    mapping_status = _normalized_attribute(mapping.get("status") or "active")
    if mapping_status == "active" and index_status not in {"active", "trial"}:
        raise ValueError(
            f"LOINC {index_code} is {index_row.get('STATUS')!r} in the supplied index; "
            "an active mapping is not allowed"
        )
    attributes = mapping.get("attributes") or {}
    for fixture_field, index_field in INDEX_ATTRIBUTE_FIELDS.items():
        expected = _normalized_attribute(attributes.get(fixture_field))
        if not expected:
            continue
        actual = _normalized_attribute(index_row.get(index_field))
        if expected != actual:
            raise ValueError(
                f"LOINC {index_code} attribute {fixture_field} does not match the supplied index"
            )


def validate_fixture(
    payload: dict,
    *,
    index_path: Path | None = None,
    require_index_manifest: bool = False,
) -> None:
    seen: set[tuple[str, str]] = set()
    index_rows = _load_index(index_path) if index_path else None
    if index_path:
        _validate_index_manifest(payload, index_path, required=require_index_manifest)
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
        if status == "active" and not mapping.get("approved", False):
            raise ValueError(
                f"active mapping {index} must set approved=true"
            )
        attrs = mapping.get("attributes") or {}
        if not isinstance(attrs, dict):
            raise ValueError(f"mapping {index} attributes must be an object")
        order_observation = attrs.get("order_observation")
        if order_observation is not None and order_observation not in ORDER_OBSERVATION:
            raise ValueError(f"mapping {index} has invalid order_observation: {order_observation}")
        if index_rows is not None:
            index_row = index_rows.get(code)
            if index_row is None:
                raise ValueError(f"LOINC code {code} is not present in the supplied index")
            _validate_index_mapping(mapping, index_row, code)


def render(
    payload: dict,
    *,
    index_path: Path | None = None,
    require_index_manifest: bool = False,
) -> str:
    validate_fixture(
        payload,
        index_path=index_path,
        require_index_manifest=require_index_manifest,
    )
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
            "(item_id, system, code, version, mapping_type, status, source_note, verified, approved_at) values ("
            f"{_sql(item_id)}, {_sql(LOINC_SYSTEM)}, {_sql(code)}, {_sql(version)}, "
            f"{_sql(mapping_type)}, {_sql(status)}, {_sql(note)}, "
            f"{_sql(bool(mapping.get('verified', False)))}, "
            f"{'now()' if mapping.get('approved', False) else 'null'}) "
            "on conflict (item_id, system, code, version) do update set "
            "mapping_type = excluded.mapping_type, status = excluded.status, "
            "source_note = excluded.source_note, verified = excluded.verified, "
            "approved_at = excluded.approved_at;"
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
    parser.add_argument(
        "--index",
        type=Path,
        required=True,
        help="active LOINC JSONL index generated from the reviewed release",
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    payload = load_fixture(args.fixture)
    sql = render(payload, index_path=args.index, require_index_manifest=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(sql, encoding="utf-8", newline="\n")
    print(json.dumps({"mappings": len(payload["mappings"]), "output": str(args.output)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
