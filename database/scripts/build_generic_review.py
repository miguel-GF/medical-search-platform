"""Build an auditable review queue for generic-provider discoveries.

Discovery evidence is useful even when it is not safe to publish.  This
script joins the raw generic artifacts with the reviewed mapping fixture and a
small, versioned classification fixture.  Every discovered offer must have a
decision; an unknown label fails closed instead of silently disappearing from
the queue.
"""

from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable, Mapping
from urllib.parse import urlparse

try:
    from .artifact_io import iter_jsonl, read_json_file, safe_http_url
except ImportError:  # pragma: no cover - direct script execution
    from artifact_io import iter_jsonl, read_json_file, safe_http_url


ALLOWED_CLASSIFICATIONS = {
    "reject_noise",
    "category_not_service",
    "ambiguous_modality",
    "ambiguous_panel",
    "new_concept_candidate",
    "possible_alias",
}
ALLOWED_REVIEW_STATUSES = {"pending"}


def normalize(value: str) -> str:
    """Return the same conservative key used by the catalog renderers."""

    plain = "".join(
        character
        for character in unicodedata.normalize("NFKD", value.casefold())
        if not unicodedata.combining(character)
    )
    return re.sub(r"[^a-z0-9]+", " ", plain).strip()


def _read_json(path: Path) -> Any:
    try:
        return read_json_file(path, max_bytes=8 * 1024 * 1024)
    except (OSError, ValueError, UnicodeError) as error:
        raise ValueError(f"invalid JSON file: {path}: {error}") from error


def _host(value: str) -> str:
    return (urlparse(value).hostname or "").casefold().rstrip(".")


def _iter_raw_records(artifact_root: Path) -> Iterable[dict[str, Any]]:
    paths = sorted(artifact_root.rglob("raw_records.jsonl"))
    if not paths:
        raise ValueError(f"artifact root has no raw_records.jsonl files: {artifact_root}")
    for path in paths:
        try:
            rows = iter_jsonl(path)
            for value in rows:
                yield value
        except (OSError, ValueError, UnicodeError) as error:
            raise ValueError(f"cannot read artifact: {path}: {error}") from error


def _load_decisions(value: object) -> dict[tuple[str, str], dict[str, Any]]:
    if not isinstance(value, Mapping) or value.get("version") != "generic-provider-review-puebla-v1":
        raise ValueError("unsupported generic review fixture version")
    decisions_value = value.get("decisions")
    if not isinstance(decisions_value, list):
        raise ValueError("generic review fixture must contain a decisions array")
    decisions: dict[tuple[str, str], dict[str, Any]] = {}
    for index, raw in enumerate(decisions_value):
        if not isinstance(raw, Mapping):
            raise ValueError(f"review decision {index} must be an object")
        source_key = str(raw.get("source_key") or "").strip()
        label_key = str(raw.get("label_key") or "").strip()
        classification = str(raw.get("classification") or "").strip()
        review_status = str(raw.get("review_status") or "").strip()
        action = str(raw.get("action") or "").strip()
        reason = str(raw.get("reason") or "").strip()
        if not source_key or not label_key or not action or not reason:
            raise ValueError(f"review decision {index} is missing required fields")
        if classification not in ALLOWED_CLASSIFICATIONS:
            raise ValueError(f"review decision {index} has unsupported classification")
        if review_status not in ALLOWED_REVIEW_STATUSES:
            raise ValueError(f"review decision {index} must remain pending")
        if raw.get("publish") is not False:
            raise ValueError(f"review decision {index} cannot publish an unmapped label")
        key = (source_key, label_key)
        if key in decisions:
            raise ValueError(f"duplicate review decision: {source_key}:{label_key}")
        decisions[key] = {
            **dict(raw),
            "source_key": source_key,
            "label_key": label_key,
            "classification": classification,
            "review_status": review_status,
            "action": action,
            "reason": reason,
        }
    return decisions


def _approved_keys(mapping_fixture: object) -> set[tuple[str, str]]:
    if not isinstance(mapping_fixture, Mapping) or not isinstance(mapping_fixture.get("mappings"), list):
        raise ValueError("mapping fixture must contain a mappings array")
    result: set[tuple[str, str]] = set()
    for index, raw in enumerate(mapping_fixture["mappings"]):
        if not isinstance(raw, Mapping):
            raise ValueError(f"mapping {index} must be an object")
        source_key = str(raw.get("source_key") or "").strip()
        external_id = str(raw.get("external_record_id") or "").strip()
        if not source_key or not external_id:
            raise ValueError(f"mapping {index} is missing source_key or external_record_id")
        key = (source_key, external_id)
        if key in result:
            raise ValueError(f"duplicate approved mapping: {source_key}:{external_id}")
        result.add(key)
    return result


def _offer_row(raw: Mapping[str, Any]) -> dict[str, Any]:
    payload = raw.get("payload")
    if not isinstance(payload, Mapping):
        raise ValueError(f"offer payload is not an object: {raw.get('external_record_id')}")
    label = str(payload.get("provider_display_name") or "").strip()
    if not label:
        raise ValueError(f"offer has no provider_display_name: {raw.get('external_record_id')}")
    evidence_url = safe_http_url(payload.get("evidence_page_url") or raw.get("source_url"))
    if not evidence_url:
        raise ValueError(f"offer has no evidence URL: {raw.get('external_record_id')}")
    source_key = str(raw.get("source_key") or "").strip()
    external_record_id = str(raw.get("external_record_id") or "").strip()
    if not source_key or not external_record_id:
        raise ValueError("offer is missing source_key or external_record_id")
    return {
        "source_key": source_key,
        "external_record_id": external_record_id,
        "observed_label": label,
        "label_key": normalize(label),
        "evidence_method": str(payload.get("evidence_method") or "unknown"),
        "evidence_url": evidence_url,
        "host": _host(evidence_url),
        "record_hash": str(raw.get("record_hash") or ""),
    }


def build_report(
    records: Iterable[Mapping[str, Any]],
    mapping_fixture: object,
    review_fixture: object,
    *,
    expected_discovered_offers: int | None = None,
) -> dict[str, Any]:
    """Build a report and fail if any unmapped offer lacks a decision."""

    approved = _approved_keys(mapping_fixture)
    decisions = _load_decisions(review_fixture)
    offers: list[dict[str, Any]] = []
    seen_ids: set[tuple[str, str]] = set()
    approved_seen: set[tuple[str, str]] = set()
    for raw in records:
        if str(raw.get("record_type") or "") not in {"provider_offer_discovered", "provider_offer_price"}:
            continue
        row = _offer_row(raw)
        key = (row["source_key"], row["external_record_id"])
        if key in seen_ids:
            raise ValueError(f"duplicate generic offer record: {key[0]}:{key[1]}")
        seen_ids.add(key)
        if key in approved:
            approved_seen.add(key)
            continue
        offers.append(row)

    missing_approved = sorted(approved - seen_ids)
    if missing_approved:
        formatted = ", ".join(f"{source}:{external_id}" for source, external_id in missing_approved)
        raise ValueError(f"approved mappings do not match any discovered offer: {formatted}")

    if expected_discovered_offers is not None and len(offers) + len(approved_seen) != expected_discovered_offers:
        raise ValueError(
            "discovered offer count does not match manifest: "
            f"observed={len(offers) + len(approved_seen)} expected={expected_discovered_offers}"
        )

    queue: list[dict[str, Any]] = []
    missing: list[dict[str, str]] = []
    grouped: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in offers:
        key = (row["source_key"], row["label_key"])
        decision = decisions.get(key)
        if decision is None:
            missing.append({"source_key": row["source_key"], "label_key": row["label_key"]})
            continue
        grouped[key].append(row)
        queue.append({
            **row,
            "classification": decision["classification"],
            "review_status": decision["review_status"],
            "publish": False,
            "action": decision["action"],
            "reason": decision["reason"],
        })
    if missing:
        missing_unique = sorted({(item["source_key"], item["label_key"]) for item in missing})
        raise ValueError("unclassified generic offers: " + ", ".join(f"{source}:{label}" for source, label in missing_unique))

    stale = sorted(key for key in decisions if key not in grouped)
    if stale:
        formatted = ", ".join(f"{source}:{label}" for source, label in stale)
        raise ValueError(f"review decisions do not match any unmapped offer: {formatted}")

    label_rows: list[dict[str, Any]] = []
    for key in sorted(grouped):
        rows = sorted(grouped[key], key=lambda item: item["external_record_id"])
        decision = decisions[key]
        expected_count = decision.get("expected_record_count")
        if isinstance(expected_count, bool) or not isinstance(expected_count, int) or expected_count != len(rows):
            raise ValueError(
                f"review decision count mismatch for {key[0]}:{key[1]}: "
                f"observed={len(rows)} expected={expected_count}"
            )
        label_rows.append({
            "source_key": key[0],
            "label_key": key[1],
            "observed_labels": sorted({row["observed_label"] for row in rows}),
            "record_count": len(rows),
            "external_record_ids": [row["external_record_id"] for row in rows],
            "classification": decision["classification"],
            "review_status": decision["review_status"],
            "publish": False,
            "action": decision["action"],
            "reason": decision["reason"],
        })

    return {
        "version": "generic-provider-review-puebla-v1",
        "discovered_offers": len(offers) + len(approved_seen),
        "approved_mapping_records": len(approved_seen),
        "unmapped_offer_records": len(offers),
        "classified_offer_records": len(queue),
        "unclassified_offer_records": 0,
        "decision_counts": dict(sorted(Counter(row["classification"] for row in queue).items())),
        "review_status_counts": dict(sorted(Counter(row["review_status"] for row in queue).items())),
        "labels": label_rows,
        "records": sorted(queue, key=lambda item: (item["source_key"], item["label_key"], item["external_record_id"])),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the Puebla generic-label review queue")
    parser.add_argument("--artifact-root", type=Path, required=True)
    parser.add_argument("--mapping-fixture", type=Path, required=True)
    parser.add_argument("--review-fixture", type=Path, required=True)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        manifest = _read_json(args.manifest) if args.manifest else None
        if manifest is not None and manifest.get("version") != "puebla-generic-discovery-v1":
            raise ValueError("unsupported discovery manifest version")
        totals = manifest.get("totals", {}) if isinstance(manifest, Mapping) else {}
        expected = int(totals["offers"]) if isinstance(totals, Mapping) and "offers" in totals else None
        report = build_report(
            _iter_raw_records(args.artifact_root),
            _read_json(args.mapping_fixture),
            _read_json(args.review_fixture),
            expected_discovered_offers=expected,
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
