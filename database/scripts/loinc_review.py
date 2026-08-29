"""Build a version-bound, candidate-only LOINC review report."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from uuid import UUID

try:
    from .loinc_release import INDEX_MANIFEST_SUFFIX, rank_candidates
except ImportError:  # pragma: no cover - supports direct script execution
    from loinc_release import INDEX_MANIFEST_SUFFIX, rank_candidates


def _manifest_path(index_path: Path) -> Path:
    return index_path.with_suffix(index_path.suffix + INDEX_MANIFEST_SUFFIX)


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _load_manifest(index_path: Path) -> dict:
    path = _manifest_path(index_path)
    if not path.exists():
        raise ValueError(f"LOINC index manifest is required: {path}")
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise ValueError(f"Invalid LOINC index manifest: {path}") from error
    if not isinstance(manifest, dict):
        raise ValueError("LOINC index manifest must be an object")
    version = str(manifest.get("loinc_version") or "").strip()
    expected_hash = str(manifest.get("index_sha256") or "").strip().lower()
    if not version or not expected_hash:
        raise ValueError("LOINC index manifest requires loinc_version and index_sha256")
    if expected_hash != _sha256_file(index_path).lower():
        raise ValueError("LOINC index SHA-256 does not match its manifest")
    return manifest


def load_queue(path: Path) -> dict:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise ValueError(f"Invalid LOINC review queue JSON: {path}") from error
    if not isinstance(payload, dict):
        raise ValueError("LOINC review queue root must be an object")
    queue_version = str(payload.get("queue_version") or "").strip()
    if not queue_version:
        raise ValueError("LOINC review queue requires queue_version")
    items = payload.get("items")
    if not isinstance(items, list) or not items:
        raise ValueError("LOINC review queue requires a non-empty items array")
    seen: set[str] = set()
    for index, item in enumerate(items):
        if not isinstance(item, dict):
            raise ValueError(f"queue item {index} must be an object")
        item_id = str(item.get("item_id") or "").strip()
        try:
            UUID(item_id)
        except ValueError as error:
            raise ValueError(f"queue item {index} has invalid item_id") from error
        if item_id in seen:
            raise ValueError(f"duplicate queue item: {item_id}")
        seen.add(item_id)
        if not str(item.get("canonical_name") or "").strip():
            raise ValueError(f"queue item {index} requires canonical_name")
        queries = item.get("queries")
        if not isinstance(queries, list) or not queries:
            raise ValueError(f"queue item {index} requires a non-empty queries array")
        normalized_queries: set[str] = set()
        for query in queries:
            if not isinstance(query, str) or not query.strip():
                raise ValueError(f"queue item {index} queries must be non-empty strings")
            normalized = " ".join(query.casefold().split())
            if normalized in normalized_queries:
                raise ValueError(f"queue item {index} contains duplicate query: {query}")
            normalized_queries.add(normalized)
    return payload


def build_report(
    queue: dict,
    index_path: Path,
    *,
    limit: int = 10,
    active_only: bool = True,
) -> dict:
    if limit < 1 or limit > 100:
        raise ValueError("candidate limit must be between 1 and 100")
    manifest = _load_manifest(index_path)
    items = []
    for item in queue["items"]:
        query_results = []
        for query in item["queries"]:
            query_results.append(
                {
                    "query": query,
                    "candidates": rank_candidates(
                        index_path,
                        query,
                        limit=limit,
                        active_only=active_only,
                    ),
                }
            )
        items.append(
            {
                "item_id": item["item_id"],
                "canonical_name": item["canonical_name"],
                "review_status": "pending",
                "clinical_review_required": True,
                "queries": query_results,
            }
        )
    return {
        "queue_version": queue["queue_version"],
        "loinc_version": manifest["loinc_version"],
        "index": str(index_path),
        "index_manifest": str(_manifest_path(index_path)),
        "review_status": "pending",
        "publication_allowed": False,
        "items": items,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--queue", type=Path, required=True)
    parser.add_argument("--index", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--limit", type=int, default=10)
    parser.add_argument("--include-deprecated", action="store_true")
    args = parser.parse_args(argv)
    report = build_report(
        load_queue(args.queue),
        args.index,
        limit=args.limit,
        active_only=not args.include_deprecated,
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        json.dumps(
            {
                "output": str(args.output),
                "items": len(report["items"]),
                "publication_allowed": False,
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
