"""Match DENUE candidate locations to provider location evidence conservatively.

This is an identity reconciliation report, not a publisher.  A match requires
an explicit DENUE brand signal plus a nearby provider location whose branch
name or postal code supports the same site.  Ambiguous brand signals (such as
``L.R.``) never become an automatic match.
"""

from __future__ import annotations

import argparse
import json
import math
from collections import Counter
from pathlib import Path
from typing import Any, Mapping

try:
    from .classify_denue_candidates import normalize, repair_text
except ImportError:  # pragma: no cover - direct script execution
    from classify_denue_candidates import normalize, repair_text


MATCHER_VERSION = "denue-location-matcher-v1"
MAX_STRONG_DISTANCE_METERS = 350.0
MAX_REVIEW_DISTANCE_METERS = 1_000.0
NAME_STOPWORDS = {
    "laboratorio",
    "laboratorios",
    "medico",
    "medicos",
    "medica",
    "del",
    "de",
    "la",
    "el",
    "los",
    "las",
    "sucursal",
    "plaza",
    "lr",
    "l",
    "r",
}


def display_path(path: Path) -> str:
    """Keep generated fixtures portable across Windows and POSIX checkouts."""

    return path.as_posix()


def _coordinates(value: object) -> tuple[float, float] | None:
    if not isinstance(value, Mapping):
        return None
    try:
        latitude = float(value.get("latitude"))
        longitude = float(value.get("longitude"))
    except (TypeError, ValueError):
        return None
    if not (-90 <= latitude <= 90 and -180 <= longitude <= 180):
        return None
    return latitude, longitude


def distance_meters(left: tuple[float, float] | None, right: tuple[float, float] | None) -> float | None:
    if left is None or right is None:
        return None
    radius = 6_371_000.0
    left_lat, left_lon = math.radians(left[0]), math.radians(left[1])
    right_lat, right_lon = math.radians(right[0]), math.radians(right[1])
    delta_lat = right_lat - left_lat
    delta_lon = right_lon - left_lon
    haversine = math.sin(delta_lat / 2) ** 2 + math.cos(left_lat) * math.cos(right_lat) * math.sin(delta_lon / 2) ** 2
    return 2 * radius * math.asin(math.sqrt(haversine))


def branch_name_similarity(left: str, right: str) -> float:
    left_tokens = set(normalize(left).split()) - NAME_STOPWORDS
    right_tokens = set(normalize(right).split()) - NAME_STOPWORDS
    if not left_tokens or not right_tokens:
        return 0.0
    return len(left_tokens & right_tokens) / max(len(left_tokens), len(right_tokens))


def read_provider_locations(artifact: Path, brand_key: str) -> list[dict[str, Any]]:
    manifest = json.loads((artifact / "run_manifest.json").read_text(encoding="utf-8"))
    if manifest.get("status") != "succeeded" or manifest.get("errors"):
        raise ValueError(f"provider artifact is not a succeeded run: {artifact}")
    locations: list[dict[str, Any]] = []
    for line in (artifact / "raw_records.jsonl").read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        if row.get("record_type") != "provider_location_discovered":
            continue
        payload = row.get("payload")
        if not isinstance(payload, dict):
            continue
        coords = _coordinates(payload.get("coordinates"))
        if coords is None:
            continue
        locations.append(
            {
                "brand_key": brand_key,
                "source_key": row.get("source_key"),
                "source_run_id": manifest.get("run_id"),
                "external_record_id": str(row.get("external_record_id") or payload.get("provider_external_id") or ""),
                "record_hash": row.get("record_hash"),
                "source_url": row.get("source_url") or payload.get("location_url"),
                "name": repair_text(payload.get("provider_display_name")),
                "address": repair_text(payload.get("address_line_1")),
                "postal_code": repair_text(payload.get("postal_code")),
                "coordinates": {"latitude": coords[0], "longitude": coords[1]},
            }
        )
    return locations


def _best_location(candidate: dict[str, Any], locations: list[dict[str, Any]]) -> dict[str, Any] | None:
    candidate_coords = _coordinates(candidate.get("coordinates"))
    candidate_postal = normalize(candidate.get("postal_code"))
    scored: list[tuple[float, dict[str, Any]]] = []
    for location in locations:
        location_coords = _coordinates(location.get("coordinates"))
        distance = distance_meters(candidate_coords, location_coords)
        similarity = branch_name_similarity(candidate.get("name", ""), location.get("name", ""))
        same_postal = bool(candidate_postal and candidate_postal == normalize(location.get("postal_code")))
        distance_score = 0.0 if distance is None else max(0.0, 1.0 - min(distance, 1_000.0) / 1_000.0)
        score = similarity * 0.55 + (0.25 if same_postal else 0.0) + distance_score * 0.20
        scored.append(
            (
                score,
                {
                    "location": location,
                    "distance_meters": None if distance is None else round(distance, 2),
                    "name_similarity": round(similarity, 4),
                    "same_postal_code": same_postal,
                    "score": round(score, 5),
                },
            )
        )
    return max(scored, key=lambda item: (item[0], -(item[1]["distance_meters"] or 1_000_000)))[1] if scored else None


def match(candidates_fixture: Path, provider_artifacts: Mapping[str, Path]) -> dict[str, Any]:
    fixture = json.loads(candidates_fixture.read_text(encoding="utf-8"))
    candidates = fixture.get("candidates")
    if not isinstance(candidates, list):
        raise ValueError("DENUE candidate fixture must contain a candidates list")
    provider_locations: list[dict[str, Any]] = []
    for brand_key, artifact in sorted(provider_artifacts.items()):
        provider_locations.extend(read_provider_locations(artifact, brand_key))
    by_brand: dict[str, list[dict[str, Any]]] = {}
    for location in provider_locations:
        by_brand.setdefault(location["brand_key"], []).append(location)

    results: list[dict[str, Any]] = []
    for candidate in candidates:
        brand = candidate.get("brand_match")
        base: dict[str, Any] = {
            "external_record_id": candidate.get("external_record_id"),
            "source_record_ids": candidate.get("source_record_ids", [candidate.get("external_record_id")]),
            "source_record_hashes": candidate.get("source_record_hashes", [candidate.get("record_hash")]),
            "record_hash": candidate.get("record_hash"),
            "name": candidate.get("name"),
            "legal_name": candidate.get("legal_name"),
            "coordinates": candidate.get("coordinates"),
            "source_url": candidate.get("source_url"),
            "brand_match": brand,
        }
        if not brand:
            base.update({"status": "unmatched", "reason": "No known provider brand signal in DENUE"})
            results.append(base)
            continue
        brand_key = brand.get("brand_key")
        locations = by_brand.get(brand_key, [])
        best = _best_location(candidate, locations)
        if best is None:
            base.update(
                {
                    "status": "review_required",
                    "reason": "Brand signal exists but no provider location artifact was supplied or had coordinates",
                }
            )
        else:
            location = best["location"]
            strong_geometry = (
                best["distance_meters"] is not None
                and best["distance_meters"] <= MAX_STRONG_DISTANCE_METERS
                and (
                    best["name_similarity"] > 0
                    or (best["same_postal_code"] and best["distance_meters"] <= 100.0)
                )
            )
            review_geometry = best["distance_meters"] is not None and best["distance_meters"] <= MAX_REVIEW_DISTANCE_METERS
            if brand.get("status") == "matched" and strong_geometry:
                status = "matched"
                reason = "Explicit DENUE brand plus nearby provider location evidence"
            else:
                status = "review_required"
                reason = "Location is a lead, but brand or branch identity still requires review"
            if not review_geometry:
                reason = "Brand signal exists, but no nearby provider location corroborates this site"
            base.update(
                {
                    "status": status,
                    "reason": reason,
                    "provider_location": {
                        "source_key": location["source_key"],
                        "source_run_id": location["source_run_id"],
                        "external_record_id": location["external_record_id"],
                        "record_hash": location["record_hash"],
                        "source_url": location["source_url"],
                        "name": location["name"],
                        "address": location["address"],
                        "postal_code": location["postal_code"],
                        "coordinates": location["coordinates"],
                    },
                    "comparison": {
                        "distance_meters": best["distance_meters"],
                        "name_similarity": best["name_similarity"],
                        "same_postal_code": best["same_postal_code"],
                        "score": best["score"],
                    },
                }
            )
        results.append(base)

    results.sort(key=lambda item: (item["status"], normalize(item.get("name")), str(item.get("external_record_id"))))
    counts = Counter(item["status"] for item in results)
    nearby_review_leads = sum(
        1
        for item in results
        if item["status"] == "review_required"
        and item.get("comparison", {}).get("distance_meters") is not None
        and item["comparison"]["distance_meters"] <= MAX_STRONG_DISTANCE_METERS
        and item["comparison"].get("name_similarity", 0) > 0
    )
    return {
        "version": MATCHER_VERSION,
        "source_fixture": display_path(candidates_fixture),
        "source_run_id": fixture.get("source_run_id"),
        "provider_artifacts": {
            key: {
                "artifact": display_path(path),
                "location_records": len(by_brand.get(key, [])),
            }
            for key, path in sorted(provider_artifacts.items())
        },
        "summary": {
            "denue_candidates": len(candidates),
            "matched": counts.get("matched", 0),
            "review_required": counts.get("review_required", 0),
            "nearby_review_leads": nearby_review_leads,
            "unmatched": counts.get("unmatched", 0),
        },
        "matches": [item for item in results if item["status"] == "matched"],
        "review_queue": [item for item in results if item["status"] == "review_required"],
        "unmatched": [item for item in results if item["status"] == "unmatched"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Match DENUE candidates to provider location artifacts")
    parser.add_argument("--candidates", type=Path, required=True)
    parser.add_argument("--provider-artifact", action="append", default=[], metavar="BRAND=PATH")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    artifacts: dict[str, Path] = {}
    for value in args.provider_artifact:
        if "=" not in value:
            raise SystemExit("--provider-artifact must use BRAND=PATH")
        brand_key, path = value.split("=", 1)
        if not brand_key.strip() or brand_key in artifacts:
            raise SystemExit("provider artifact brand keys must be unique and non-empty")
        artifacts[brand_key.strip()] = Path(path)
    result = match(args.candidates, artifacts)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result["summary"], ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
