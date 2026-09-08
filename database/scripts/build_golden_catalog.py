"""Build the versioned golden catalog fixture from collector artifacts.

The generator is intentionally conservative: every Ruiz item starts as an
observed provider service, and only normalized exact labels are shared across
providers. Similar-looking labels remain unmapped for manual review.
"""

from __future__ import annotations

import argparse
import json
import re
import unicodedata
from pathlib import Path
from uuid import NAMESPACE_URL, uuid5

try:
    from .artifact_io import read_json_file, read_jsonl
except ImportError:  # pragma: no cover - direct script execution
    from artifact_io import read_json_file, read_jsonl

BRANDS = {
    "ruiz_puebla": {"brand_key": "ruiz", "brand_name": "Laboratorios Ruiz", "slug": "laboratorios-ruiz"},
    "salud_digna_puebla": {"brand_key": "salud_digna", "brand_name": "Salud Digna", "slug": "salud-digna"},
    "chopo_puebla": {"brand_key": "chopo", "brand_name": "Laboratorio Médico del Chopo", "slug": "laboratorio-medico-del-chopo"},
}


def normalize(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value.casefold())
    plain = "".join(c for c in decomposed if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", " ", plain).strip()


def stable_id(kind: str, key: str) -> str:
    return str(uuid5(NAMESPACE_URL, f"https://pruevia.local/{kind}/{key}"))


def read_rows(path: Path) -> list[dict]:
    return read_jsonl(path)


def service_type(department_slug: str, title: str) -> tuple[str, str]:
    if department_slug in {"resonancia-magnetica", "rayos-x", "tomografia", "ultrasonido", "mastografia", "densitometria"}:
        return "imaging", "imaging"
    if department_slug == "cardiologia":
        return "cardiology", "cardiology"
    if department_slug in {"audiometria", "espirometria"}:
        return "functional_test", "functional_tests"
    if department_slug == "colposcopia":
        return "other", "other"
    if department_slug == "servicios-medicos":
        return "other", "other"
    if any(normalize(title).startswith(prefix) for prefix in ("perfil ", "paquete ", "check up", "chequeo ")):
        return "lab_panel", "laboratory"
    return "lab_test", "laboratory"


def build(
    ruiz_path: Path,
    chopo_path: Path,
    salud_digna_path: Path | None = None,
    *,
    approved_mappings_path: Path | None = None,
    baseline_fixture_path: Path | None = None,
) -> dict:
    ruiz_rows = read_rows(ruiz_path)
    chopo_rows = read_rows(chopo_path)
    salud_digna_rows = read_rows(salud_digna_path) if salud_digna_path else []
    approved_rows: list[dict] = []
    if approved_mappings_path:
        approved_data = read_json_file(approved_mappings_path, max_bytes=8 * 1024 * 1024)
        approved_rows = approved_data.get("mappings", []) if isinstance(approved_data, dict) else approved_data
        if not isinstance(approved_rows, list):
            raise ValueError("approved mappings must contain a mappings list")
    approved_by_chopo: dict[str, dict] = {}
    approved_ruiz_ids: set[str] = set()
    for mapping in approved_rows:
        if not isinstance(mapping, dict):
            raise ValueError("approved mapping entries must be objects")
        chopo_id = str(mapping.get("chopo_external_record_id") or "").strip()
        ruiz_id = str(mapping.get("ruiz_external_record_id") or "").strip()
        reason = str(mapping.get("reason") or "").strip()
        if not chopo_id or not ruiz_id or not reason:
            raise ValueError("approved mappings require Chopo ID, Ruiz ID and reason")
        if chopo_id in approved_by_chopo:
            raise ValueError(f"duplicate approved Chopo mapping: {chopo_id}")
        approved_by_chopo[chopo_id] = {"ruiz_external_record_id": ruiz_id, "reason": reason}
        approved_ruiz_ids.add(ruiz_id)

    ruiz_allowed_ids: set[str] | None = None
    if baseline_fixture_path:
        baseline = read_json_file(baseline_fixture_path, max_bytes=8 * 1024 * 1024)
        if not isinstance(baseline, dict):
            raise ValueError("baseline fixture must be a JSON object")
        ruiz_allowed_ids = {
            str(mapping.get("external_record_id"))
            for mapping in baseline.get("mappings", [])
            if mapping.get("source_key") == "ruiz_puebla"
        }
        ruiz_allowed_ids.update(approved_ruiz_ids)
    items: dict[str, dict] = {}
    mappings: list[dict] = []
    normalization_queue: list[dict] = []

    for row in ruiz_rows:
        payload = row.get("payload", {})
        if row.get("record_type") != "provider_offer_price":
            continue
        external_id = str(payload.get("provider_external_id") or row.get("external_record_id") or "")
        title = str(payload.get("provider_display_name") or "").strip()
        if not external_id or not title:
            continue
        if ruiz_allowed_ids is not None and external_id not in ruiz_allowed_ids:
            continue
        key = f"ruiz:{external_id}"
        kind, category = service_type(str(payload.get("department_slug") or ""), title)
        item = items.setdefault(
            key,
            {
                "item_id": stable_id("catalog-item", key),
                "catalog_key": key,
                "canonical_name": title,
                "normalized_name": normalize(title),
                "item_type": "package" if kind == "lab_panel" else "service",
                "service_type": kind,
                "category_code": category,
                "clinical_equivalence_policy": "manual_if_ambiguous",
                "status": "active",
                "source_note": "Golden V1: exact official Ruiz provider label; no cross-provider equivalence inferred.",
                "provider_aliases": [],
            },
        )
        item["provider_aliases"].append(
            {
                "provider_key": "ruiz_puebla",
                "alias": title,
                "alias_type": "provider_name",
                "confidence": 1.0,
                "source_note": "Official Laboratorios Ruiz catalog observation.",
            }
        )
        mappings.append(
            {
                "source_key": "ruiz_puebla",
                "provider_key": "ruiz",
                "external_record_id": str(row.get("external_record_id")),
                "record_hash": row.get("record_hash"),
                "catalog_key": key,
            }
        )

    ruiz_by_normalized = {item["normalized_name"]: item for item in items.values()}
    for row in chopo_rows:
        payload = row.get("payload", {})
        if row.get("record_type") != "provider_offer_price":
            continue
        title = str(payload.get("provider_display_name") or "").strip()
        external_id = str(row.get("external_record_id") or payload.get("provider_external_id") or "")
        manual_mapping = approved_by_chopo.get(external_id)
        if manual_mapping:
            target = items.get(f"ruiz:{manual_mapping['ruiz_external_record_id']}")
            if target is None:
                raise ValueError(
                    f"approved mapping target is not in the selected Ruiz catalog: {manual_mapping['ruiz_external_record_id']}"
                )
            target["provider_aliases"].append(
                {
                    "provider_key": "chopo_puebla",
                    "alias": title,
                    "alias_type": "provider_name",
                    "confidence": 0.95,
                    "source_note": f"Manual Gate A review: {manual_mapping['reason']}",
                }
            )
            mappings.append(
                {
                    "source_key": "chopo_puebla",
                    "provider_key": "chopo",
                    "external_record_id": external_id,
                    "record_hash": row.get("record_hash"),
                    "catalog_key": target["catalog_key"],
                    "method": "manual",
                    "reason": manual_mapping["reason"],
                }
            )
            continue
        normalized = normalize(title)
        target = ruiz_by_normalized.get(normalized)
        if target:
            target["provider_aliases"].append(
                {
                    "provider_key": "chopo_puebla",
                    "alias": title,
                    "alias_type": "provider_name",
                    "confidence": 1.0,
                    "source_note": "Exact normalized match across official provider catalogs; reviewable mapping.",
                }
            )
            mappings.append(
                {
                    "source_key": "chopo_puebla",
                    "provider_key": "chopo",
                    "external_record_id": str(row.get("external_record_id")),
                    "record_hash": row.get("record_hash"),
                    "catalog_key": target["catalog_key"],
                }
            )
        else:
            normalization_queue.append(
                {
                    "source_key": "chopo_puebla",
                    "raw_record_id": row.get("external_record_id"),
                    "raw_text": title,
                    "normalized_input": normalized,
                    "status": "no_match",
                    "reason": "No exact golden catalog term; fuzzy candidates require manual clinical review.",
                }
            )

    # Salud Digna is an additional provider, never a source of automatic
    # clinical equivalence. Exact normalized labels may be proposed against
    # the Ruiz-anchored golden catalog; all other labels remain reviewable.
    for row in salud_digna_rows:
        payload = row.get("payload", {})
        if row.get("record_type") != "provider_offer_price":
            continue
        title = str(payload.get("provider_display_name") or "").strip()
        normalized = normalize(title)
        target = ruiz_by_normalized.get(normalized)
        if target:
            target["provider_aliases"].append(
                {
                    "provider_key": "salud_digna_puebla",
                    "alias": title,
                    "alias_type": "provider_name",
                    "confidence": 1.0,
                    "source_note": "Exact normalized match across official provider catalogs; reviewable mapping.",
                }
            )
            mappings.append(
                {
                    "source_key": "salud_digna_puebla",
                    "provider_key": "salud_digna",
                    "external_record_id": str(row.get("external_record_id")),
                    "record_hash": row.get("record_hash"),
                    "catalog_key": target["catalog_key"],
                }
            )
        else:
            normalization_queue.append(
                {
                    "source_key": "salud_digna_puebla",
                    "raw_record_id": row.get("external_record_id"),
                    "raw_text": title,
                    "normalized_input": normalized,
                    "status": "no_match",
                    "reason": "No exact golden catalog term; fuzzy candidates require manual clinical review.",
                }
            )

    active_sources = {"ruiz_puebla", "chopo_puebla"}
    if salud_digna_path:
        active_sources.add("salud_digna_puebla")

    if approved_by_chopo:
        missing = set(approved_by_chopo) - {
            str(mapping.get("external_record_id"))
            for mapping in mappings
            if mapping.get("source_key") == "chopo_puebla"
        }
        if missing:
            raise ValueError(f"approved mappings reference missing Chopo records: {sorted(missing)}")

    return {
        "version": "golden-catalog-v1",
        "generated_from": {
            "ruiz": "official Laboratorios Ruiz Puebla collector artifact",
            "chopo": "official Chopo Puebla collector artifact",
            **({"salud_digna": "official Salud Digna Puebla collector artifact"} if salud_digna_path else {}),
        },
        "policy": "Exact observed labels and explicit reviewed Gate A mappings are active; no fuzzy medical equivalence is auto-approved.",
        "brands": {key: BRANDS[key] for key in BRANDS if key in active_sources},
        "items": sorted(items.values(), key=lambda item: item["canonical_name"]),
        "mappings": mappings,
        "normalization_queue": normalization_queue,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ruiz", type=Path, required=True)
    parser.add_argument("--chopo", type=Path, required=True)
    parser.add_argument("--salud-digna", type=Path)
    parser.add_argument("--approved-mappings", type=Path)
    parser.add_argument("--baseline-fixture", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    fixture = build(
        args.ruiz,
        args.chopo,
        args.salud_digna,
        approved_mappings_path=args.approved_mappings,
        baseline_fixture_path=args.baseline_fixture,
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"items": len(fixture["items"]), "mappings": len(fixture["mappings"]), "queue": len(fixture["normalization_queue"])}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
