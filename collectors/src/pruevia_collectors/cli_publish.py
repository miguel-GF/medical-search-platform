from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import psycopg

from .config import load_local_environment
from .models import RunSummary, SourceSpec
from .publisher import IngestPublisher


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Publish a collector artifact into Supabase ingest")
    parser.add_argument("artifact_directory", type=Path)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="validate and summarize the artifact without connecting to the database",
    )
    parser.add_argument(
        "--database-url",
        default=None,
        help="Postgres DSN; defaults to PRUEVIA_DATABASE_URL",
    )
    return parser


def load_summary(artifact_directory: Path) -> tuple[SourceSpec, RunSummary]:
    manifest_path = artifact_directory / "run_manifest.json"
    if not manifest_path.exists():
        raise FileNotFoundError(f"run manifest not found: {manifest_path}")
    with manifest_path.open("rb") as handle:
        manifest_bytes = handle.read(256 * 1024 + 1)
    if len(manifest_bytes) > 256 * 1024:
        raise ValueError("run manifest exceeds the safety limit")
    manifest = json.loads(manifest_bytes.decode("utf-8"))
    if not isinstance(manifest, dict):
        raise ValueError("run manifest must be a JSON object")
    source = SourceSpec(
        source_key=manifest["source_key"],
        name=manifest["source_name"],
        source_type=manifest["source_type"],
        usage_policy_status=manifest.get("usage_policy_status", "review_required"),
        endpoint_type=manifest.get("endpoint_type", "other"),
        endpoint_url=manifest.get("endpoint_url"),
        parser_version=manifest.get("parser_version", "0.1.0"),
    )
    summary = RunSummary(
        source_key=manifest["source_key"],
        run_id=manifest["run_id"],
        status=manifest["status"],
        records_received=int(manifest["records_received"]),
        records_valid=int(manifest["records_valid"]),
        records_rejected=int(manifest["records_rejected"]),
        records_published=int(manifest.get("records_published", 0)),
        previous_success_count=manifest.get("previous_success_count"),
        deviation_percentage=manifest.get("deviation_percentage"),
        artifact_directory=str(artifact_directory),
        errors=tuple(manifest.get("errors", ())),
    )
    return source, summary


def artifact_counts(artifact_directory: Path) -> dict[str, int]:
    raw_path = artifact_directory / "raw_records.jsonl"
    observations_path = artifact_directory / "observations.jsonl"
    if not raw_path.exists() or not observations_path.exists():
        raise FileNotFoundError(f"collector artifacts are incomplete: {artifact_directory}")
    raw_rows = IngestPublisher._read_jsonl(raw_path)
    observation_rows = IngestPublisher._read_jsonl(observations_path)
    return {
        "raw_records": len(raw_rows),
        "parsed_raw_records": sum(row.get("parse_status") == "parsed" for row in raw_rows),
        "observations": len(observation_rows),
        "quarantined_observations": sum(row.get("status") == "quarantined" for row in observation_rows),
    }


def main() -> int:
    load_local_environment()
    args = build_parser().parse_args()
    source, summary = load_summary(args.artifact_directory)
    counts = artifact_counts(args.artifact_directory)
    result: dict[str, object] = {"source_key": source.source_key, "run_id": summary.run_id, **counts}
    if args.dry_run:
        result["action"] = "dry_run"
    else:
        database_url = args.database_url or os.getenv("PRUEVIA_DATABASE_URL")
        if not database_url:
            raise SystemExit("PRUEVIA_DATABASE_URL is required unless --dry-run is used")
        with psycopg.connect(database_url) as connection:
            result["records_published"] = IngestPublisher(connection).publish(source, summary)
        result["action"] = "published"
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
