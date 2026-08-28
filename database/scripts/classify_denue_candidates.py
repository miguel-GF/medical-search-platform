"""Classify and deduplicate DENUE location evidence without publishing claims.

DENUE searches are intentionally broad.  This module turns a succeeded DENUE
artifact into a deterministic review fixture:

* ``direct_clinical`` contains establishments whose DENUE economic activity is
  the medical-diagnostic class used for the initial provider universe;
* ``related_clinical`` is a review queue for names/activities that may be
  useful but are not safe to treat as diagnostic providers automatically; and
* ``non_clinical`` is excluded from the candidate list.

The output is evidence and candidate metadata only.  It does not create a
canonical provider, prove that a provider offers a test, or verify a brand.
"""

from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


CLASSIFIER_VERSION = "denue-candidates-v1"
DIRECT_ACTIVITY = "laboratorios medicos y de diagnostico del sector privado"
RELATED_ACTIVITIES = {
    "laboratorios de pruebas",
    "consultorios dentales del sector privado",
}


def repair_text(value: object | None) -> str:
    """Repair the common UTF-8-as-Latin-1 mojibake returned by DENUE exports."""

    text = str(value or "").strip()
    if not text:
        return ""
    if any(marker in text for marker in ("Ã", "Â", "â")):
        try:
            repaired = text.encode("latin-1").decode("utf-8")
            if "�" not in repaired:
                return repaired
        except (UnicodeEncodeError, UnicodeDecodeError):
            pass
    return text


def normalize(value: object | None) -> str:
    decomposed = unicodedata.normalize("NFKD", repair_text(value).casefold())
    plain = "".join(char for char in decomposed if not unicodedata.combining(char))
    return re.sub(r"[^a-z0-9]+", " ", plain).strip()


def _payload(row: dict[str, Any]) -> dict[str, Any]:
    payload = row.get("payload")
    if not isinstance(payload, dict):
        raise ValueError("DENUE raw record payload must be an object")
    return payload


def _coordinates(payload: dict[str, Any]) -> tuple[float, float] | None:
    try:
        latitude = float(payload.get("Latitud"))
        longitude = float(payload.get("Longitud"))
    except (TypeError, ValueError):
        return None
    if not (-90 <= latitude <= 90 and -180 <= longitude <= 180):
        return None
    return latitude, longitude


def _address_key(payload: dict[str, Any]) -> str:
    fields = (
        payload.get("Calle"),
        payload.get("Num_Exterior"),
        payload.get("Num_Interior"),
        payload.get("Colonia"),
        payload.get("CP"),
    )
    return normalize(" ".join(repair_text(value) for value in fields if value not in (None, "")))


def dedupe_key(payload: dict[str, Any]) -> str:
    """Keep branches separate while collapsing repeated observations of a site."""

    legal = normalize(payload.get("Razon_social"))
    name = normalize(payload.get("Nombre"))
    coords = _coordinates(payload)
    identity = legal or name or "unknown"
    if coords:
        return f"{identity}|{coords[0]:.5f}|{coords[1]:.5f}"
    return f"{identity}|{_address_key(payload)}"


def _brand_match(payload: dict[str, Any]) -> dict[str, Any] | None:
    name = normalize(payload.get("Nombre"))
    legal = normalize(payload.get("Razon_social"))
    combined = f"{name} {legal}".strip()
    if "chopo" in combined:
        return {"brand_key": "chopo", "status": "matched", "confidence": 0.99, "method": "explicit_name"}
    if "salud digna" in combined:
        return {"brand_key": "salud_digna", "status": "matched", "confidence": 0.99, "method": "explicit_name"}
    if "laboratorio ruiz" in name:
        return {"brand_key": "ruiz", "status": "matched", "confidence": 0.99, "method": "explicit_name"}
    # L.R. locations sharing Laboratorio Médico Polanco are useful leads, but
    # the abbreviation alone is not enough to assert the Ruiz brand.
    if re.search(r"(?:^| )l r(?: |$)", name) and legal == "laboratorio medico polanco":
        return {"brand_key": "ruiz", "status": "review_required", "confidence": 0.55, "method": "legal_name_plus_abbreviation"}
    return None


def classify_record(row: dict[str, Any], *, duplicate_count: int = 1) -> dict[str, Any]:
    payload = _payload(row)
    name = repair_text(payload.get("Nombre"))
    legal_name = repair_text(payload.get("Razon_social"))
    activity = repair_text(payload.get("Clase_actividad"))
    activity_key = normalize(activity)
    name_key = normalize(name)
    if activity_key == DIRECT_ACTIVITY:
        classification = "direct_clinical"
        review_status = "candidate"
        reason = "DENUE activity is the medical diagnostic laboratory class"
    elif activity_key in RELATED_ACTIVITIES or any(
        token in f"{name_key} {normalize(legal_name)}"
        for token in ("radiologia", "ultrasonido", "imagenologia", "medicina nuclear")
    ):
        classification = "related_clinical"
        review_status = "review_required"
        reason = "Potentially clinical, but activity/name requires human validation"
    else:
        classification = "non_clinical"
        review_status = "excluded"
        reason = "Broad DENUE condition matched a non-diagnostic activity"

    coords = _coordinates(payload)
    result: dict[str, Any] = {
        "external_record_id": str(row.get("external_record_id") or payload.get("Id") or ""),
        "record_hash": row.get("record_hash"),
        "source_url": row.get("source_url"),
        "name": name,
        "legal_name": legal_name,
        "activity": activity,
        "postal_code": repair_text(payload.get("CP")),
        "address": {
            "street": repair_text(payload.get("Calle")),
            "exterior_number": repair_text(payload.get("Num_Exterior")),
            "interior_number": repair_text(payload.get("Num_Interior")),
            "neighborhood": repair_text(payload.get("Colonia")),
            "locality": repair_text(payload.get("Localidad")),
            "municipality": repair_text(payload.get("Municipio")),
            "state": repair_text(payload.get("Entidad") or "Puebla"),
        },
        "coordinates": {"latitude": coords[0], "longitude": coords[1]} if coords else None,
        "phone": repair_text(payload.get("Telefono")),
        "website_url": repair_text(payload.get("Sitio_internet")),
        "classification": classification,
        "review_status": review_status,
        "reason": reason,
        "dedupe_key": dedupe_key(payload),
        "duplicate_count": duplicate_count,
    }
    brand = _brand_match(payload)
    if brand:
        result["brand_match"] = brand
    return result


def read_artifact(artifact: Path) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    manifest_path = artifact / "run_manifest.json"
    raw_path = artifact / "raw_records.jsonl"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    rows = [json.loads(line) for line in raw_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if manifest.get("source_key") != "denue":
        raise ValueError("artifact source_key must be denue")
    if manifest.get("status") != "succeeded" or manifest.get("errors"):
        raise ValueError("only succeeded DENUE artifacts without errors can be classified")
    if len(rows) != int(manifest.get("records_valid", -1)):
        raise ValueError("raw record count does not match manifest")
    for row in rows:
        if row.get("source_key") != "denue" or row.get("record_type") != "provider_location_discovered":
            raise ValueError("artifact contains a non-DENUE location record")
    return manifest, rows


def classify(artifact: Path) -> dict[str, Any]:
    manifest, rows = read_artifact(artifact)
    dedupe_counts = Counter(dedupe_key(_payload(row)) for row in rows)
    classified = [classify_record(row, duplicate_count=dedupe_counts[dedupe_key(_payload(row))]) for row in rows]
    classified.sort(key=lambda item: (item["classification"], normalize(item["name"]), item["external_record_id"]))
    groups: dict[str, list[str]] = defaultdict(list)
    for item in classified:
        groups[item["dedupe_key"]].append(item["external_record_id"])
    duplicate_groups = [
        {"dedupe_key": key, "external_record_ids": ids, "count": len(ids)}
        for key, ids in sorted(groups.items())
        if len(ids) > 1
    ]
    counts = Counter(item["classification"] for item in classified)
    direct_records = [item for item in classified if item["classification"] == "direct_clinical"]
    related_records = [item for item in classified if item["classification"] == "related_clinical"]

    def collapse(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
        by_key: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for item in items:
            by_key[item["dedupe_key"]].append(item)
        collapsed: list[dict[str, Any]] = []
        for key, group in by_key.items():
            representative = dict(sorted(group, key=lambda item: item["external_record_id"])[0])
            representative["source_record_ids"] = [item["external_record_id"] for item in sorted(group, key=lambda item: item["external_record_id"])]
            representative["source_record_hashes"] = [item["record_hash"] for item in sorted(group, key=lambda item: item["external_record_id"])]
            representative["duplicate_count"] = len(group)
            collapsed.append(representative)
        return sorted(collapsed, key=lambda item: (normalize(item["name"]), item["external_record_id"]))

    direct = collapse(direct_records)
    related = collapse(related_records)
    brand_counts = Counter(
        item["brand_match"]["brand_key"]
        for item in classified
        if item.get("brand_match", {}).get("status") == "matched"
    )
    brand_review_counts = Counter(
        item["brand_match"]["brand_key"]
        for item in classified
        if item.get("brand_match", {}).get("status") == "review_required"
    )
    return {
        "version": CLASSIFIER_VERSION,
        "source_key": "denue",
        "source_run_id": str(manifest["run_id"]),
        "source_finished_at": manifest.get("finished_at"),
        "source_records": len(rows),
        "summary": {
            "direct_clinical_records": len(direct_records),
            "direct_clinical_candidates": len(direct),
            "related_clinical_records": len(related_records),
            "related_clinical_review": len(related),
            "non_clinical_excluded": counts.get("non_clinical", 0),
            "unique_dedupe_groups": len(groups),
            "duplicate_groups": len(duplicate_groups),
            "known_brand_matches": dict(sorted(brand_counts.items())),
            "known_brand_review": dict(sorted(brand_review_counts.items())),
        },
        "duplicate_groups": duplicate_groups,
        "candidates": direct,
        "review_queue": related,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Classify a succeeded DENUE artifact into provider candidates")
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = classify(args.artifact)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result["summary"], ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
