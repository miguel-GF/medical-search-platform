from __future__ import annotations

import hashlib
import json
import re
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, Protocol
from uuid import uuid4

from .models import Observation, RunSummary, SourceRecord, SourceSpec, isoformat


class Collector(Protocol):
    source: SourceSpec

    def collect(self) -> Iterable[SourceRecord]:
        """Return parsed records without publishing canonical facts."""


def _json_default(value: object) -> str:
    if isinstance(value, datetime):
        return isoformat(value)
    raise TypeError(f"Unsupported JSON value: {type(value).__name__}")


def canonical_json(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), default=_json_default)


def record_hash(record: SourceRecord) -> str:
    return hashlib.sha256(canonical_json(record.payload).encode("utf-8")).hexdigest()


def slugify(value: str) -> str:
    value = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return value or "source"


class JsonlRunStore:
    """Append-only local artifact store used by collectors and CI."""

    def __init__(self, root: str | Path) -> None:
        self.root = Path(root)

    def source_root(self, source_key: str) -> Path:
        return self.root / slugify(source_key)

    def last_success_count(self, source_key: str) -> int | None:
        manifests = sorted(self.source_root(source_key).glob("*/run_manifest.json"), reverse=True)
        for manifest_path in manifests:
            try:
                manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            if manifest.get("status") == "succeeded":
                return int(manifest["records_received"])
        return None

    def create_run(self, source_key: str) -> tuple[str, Path]:
        run_id = str(uuid4())
        run_dir = self.source_root(source_key) / run_id
        run_dir.mkdir(parents=True, exist_ok=False)
        return run_id, run_dir


class CollectorRunner:
    """Runs an adapter, persists evidence, and applies quarantine safety."""

    def __init__(self, artifact_root: str | Path) -> None:
        self.store = JsonlRunStore(artifact_root)

    def run(self, collector: Collector, *, previous_success_count: int | None = None) -> RunSummary:
        source = collector.source
        if previous_success_count is None:
            previous_success_count = self.store.last_success_count(source.source_key)
        run_id, run_dir = self.store.create_run(source.source_key)
        raw_path = run_dir / "raw_records.jsonl"
        observations_path = run_dir / "observations.jsonl"
        errors: list[str] = []
        seen_hashes: set[str] = set()
        records_received = records_valid = records_rejected = 0

        with raw_path.open("w", encoding="utf-8", newline="\n") as raw_file, observations_path.open(
            "w", encoding="utf-8", newline="\n"
        ) as observations_file:
            try:
                records = collector.collect()
                for record in records:
                    records_received += 1
                    try:
                        current_hash = record_hash(record)
                        if current_hash in seen_hashes:
                            raise ValueError("duplicate record hash in run")
                        seen_hashes.add(current_hash)
                        raw_row = {
                            "source_key": record.source_key,
                            "record_type": record.record_type,
                            "external_record_id": record.external_record_id,
                            "source_url": record.source_url,
                            "record_hash": current_hash,
                            "observed_at": isoformat(record.observed_at),
                            "parse_status": "parsed",
                            "payload": record.payload,
                        }
                        raw_file.write(canonical_json(raw_row) + "\n")
                        for observation in record.observations:
                            observations_file.write(
                                canonical_json(
                                    {
                                        "source_key": record.source_key,
                                        "record_hash": current_hash,
                                        "entity_type": observation.entity_type,
                                        "entity_id": observation.entity_id,
                                        "attribute_name": observation.attribute_name,
                                        "observed_value": observation.observed_value,
                                        "confidence": observation.confidence,
                                        "status": observation.status,
                                        "observed_at": isoformat(record.observed_at),
                                    }
                                )
                                + "\n"
                            )
                        records_valid += 1
                    except (TypeError, ValueError, KeyError) as error:
                        records_rejected += 1
                        errors.append(f"record {records_received}: {error}")
                        raw_file.write(
                            canonical_json(
                                {
                                    "source_key": getattr(record, "source_key", source.source_key),
                                    "record_type": getattr(record, "record_type", "unknown"),
                                    "parse_status": "invalid",
                                    "error_detail": str(error),
                                }
                            )
                            + "\n"
                        )
            except Exception as error:  # adapters must not hide transport/parser failures
                errors.append(f"collector failure: {error}")

        deviation = None
        if previous_success_count and previous_success_count > 0:
            deviation = round((records_received - previous_success_count) / previous_success_count * 100, 4)

        status = "succeeded"
        if errors and records_valid == 0:
            status = "failed"
        if source.expected_min_records is not None and records_received < source.expected_min_records:
            status = "quarantined"
            errors.append(f"received {records_received}, below expected minimum {source.expected_min_records}")
        if source.expected_max_records is not None and records_received > source.expected_max_records:
            status = "quarantined"
            errors.append(f"received {records_received}, above expected maximum {source.expected_max_records}")
        if deviation is not None and deviation < -source.max_negative_deviation_pct:
            status = "quarantined"
            errors.append(f"negative deviation {deviation}% exceeds safety limit")

        if status == "quarantined":
            self._mark_observations_quarantined(observations_path)
        records_published = 0
        manifest = {
            "source_key": source.source_key,
            "source_name": source.name,
            "source_type": source.source_type,
            "usage_policy_status": source.usage_policy_status,
            "run_id": run_id,
            "status": status,
            "records_received": records_received,
            "records_valid": records_valid,
            "records_rejected": records_rejected,
            "records_published": records_published,
            "previous_success_count": previous_success_count,
            "deviation_percentage": deviation,
            "errors": errors,
            "finished_at": isoformat(datetime.now(timezone.utc)),
        }
        (run_dir / "run_manifest.json").write_text(canonical_json(manifest) + "\n", encoding="utf-8")
        return RunSummary(
            source_key=source.source_key,
            run_id=run_id,
            status=status,
            records_received=records_received,
            records_valid=records_valid,
            records_rejected=records_rejected,
            records_published=records_published,
            previous_success_count=previous_success_count,
            deviation_percentage=deviation,
            artifact_directory=str(run_dir),
            errors=tuple(errors),
        )

    @staticmethod
    def _mark_observations_quarantined(path: Path) -> None:
        if not path.exists():
            return
        rows = []
        for line in path.read_text(encoding="utf-8").splitlines():
            row = json.loads(line)
            row["status"] = "quarantined"
            rows.append(canonical_json(row))
        path.write_text("\n".join(rows) + ("\n" if rows else ""), encoding="utf-8")
