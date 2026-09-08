from __future__ import annotations

import hashlib
import json
import os
import re
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, Protocol
from urllib.parse import urlparse, urlunparse
from uuid import uuid4

from .models import Observation, RunSummary, SourceRecord, SourceSpec, isoformat


# Provider responses are untrusted input. Keep one poisoned record from
# turning into an arbitrarily large local artifact or database row, even when
# the upstream response itself is within the HTTP cap.
MAX_RECORD_PAYLOAD_BYTES = 512 * 1024
MAX_RECORD_OBSERVATIONS = 100
MAX_REPORTED_ERRORS = 100
MAX_RECORDS_PER_RUN = 100_000
MAX_OBSERVATION_PAYLOAD_BYTES = 512 * 1024
MAX_MANIFEST_BYTES = 256 * 1024
MAX_ARTIFACT_LINE_BYTES = 2 * 1024 * 1024
MAX_ARTIFACT_BYTES = 256 * 1024 * 1024


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


def _safe_error_detail(error: object) -> str:
    """Bound and redact exception text before it enters manifests or DB logs."""

    detail = str(error).replace("\r", " ").replace("\n", " ")
    # HTTP client exceptions frequently echo the complete request URL. Never
    # persist a URL path/query (which may contain a token unknown to this
    # generic redactor), credentials, or signed material in an artifact.
    detail = re.sub(r"(?i)\bhttps?://[^\s<>\"']+", "[REDACTED]", detail)
    # Non-URL fragments can still expose credential-shaped query parameters.
    detail = re.sub(
        r"(?i)([?&](?:token|api[_-]?key|access[_-]?token|refresh[_-]?token|signature|sig|key)=)[^&#\s]+",
        r"\1[REDACTED]",
        detail,
    )
    detail = re.sub(r"(?i)(bearer\s+)[^\s]+", r"\1[REDACTED]", detail)
    return detail[:500]


def _safe_source_url(value: object) -> str | None:
    """Persist only navigable source locations, never signed query material."""

    if not isinstance(value, str) or not value.strip():
        return None
    try:
        parsed = urlparse(value.strip())
        if parsed.scheme not in {"http", "https"} or not parsed.hostname or parsed.username or parsed.password:
            return None
        # Query strings commonly carry signed URLs/API keys. The source path
        # remains useful for review without persisting retrieval credentials.
        clean = urlunparse((parsed.scheme, parsed.netloc, parsed.path, parsed.params, "", ""))
        return clean[:2_000] if len(clean) <= 2_000 else None
    except ValueError:
        return None


class JsonlRunStore:
    """Append-only local artifact store used by collectors and CI."""

    def __init__(self, root: str | Path) -> None:
        self.root = Path(root)

    def source_root(self, source_key: str) -> Path:
        return self.root / slugify(source_key)

    def last_success_count(self, source_key: str) -> int | None:
        candidates: list[tuple[str, Path, dict]] = []
        for manifest_path in self.source_root(source_key).glob("*/run_manifest.json"):
            try:
                with manifest_path.open("rb") as handle:
                    raw_manifest = handle.read(MAX_MANIFEST_BYTES + 1)
                if len(raw_manifest) > MAX_MANIFEST_BYTES:
                    continue
                manifest = json.loads(raw_manifest.decode("utf-8"))
            except (OSError, UnicodeDecodeError, json.JSONDecodeError):
                continue
            if isinstance(manifest, dict) and manifest.get("status") == "succeeded":
                candidates.append((str(manifest.get("finished_at", "")), manifest_path, manifest))
        for _, _, manifest in sorted(candidates, key=lambda item: item[0], reverse=True):
            try:
                return int(manifest["records_received"])
            except (KeyError, TypeError, ValueError):
                continue
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
        collector_failure = False
        seen_hashes: set[str] = set()
        records_received = records_valid = records_rejected = 0
        artifact_bytes = 0

        def add_error(message: str) -> None:
            if len(errors) < MAX_REPORTED_ERRORS:
                errors.append(message[:600])
            elif len(errors) == MAX_REPORTED_ERRORS:
                errors.append("additional errors omitted")

        with raw_path.open("w", encoding="utf-8", newline="\n") as raw_file, observations_path.open(
            "w", encoding="utf-8", newline="\n"
        ) as observations_file:
            try:
                records = collector.collect()
                for record in records:
                    records_received += 1
                    if records_received > MAX_RECORDS_PER_RUN:
                        collector_failure = True
                        add_error(f"record count exceeds safety limit ({MAX_RECORDS_PER_RUN})")
                        break
                    try:
                        if len(record.observations) > MAX_RECORD_OBSERVATIONS:
                            raise ValueError("record contains too many observations")
                        serialized_payload = canonical_json(record.payload)
                        if len(serialized_payload.encode("utf-8")) > MAX_RECORD_PAYLOAD_BYTES:
                            raise ValueError("record payload exceeds the safety limit")
                        current_hash = hashlib.sha256(serialized_payload.encode("utf-8")).hexdigest()
                        if current_hash in seen_hashes:
                            raise ValueError("duplicate record hash in run")
                        seen_hashes.add(current_hash)
                        raw_row = {
                            "source_key": record.source_key,
                            "record_type": record.record_type,
                            "external_record_id": record.external_record_id,
                            "source_url": _safe_source_url(record.source_url),
                            "record_hash": current_hash,
                            "observed_at": isoformat(record.observed_at),
                            "parse_status": "parsed",
                            "payload": record.payload,
                        }
                        serialized_observations: list[str] = []
                        for observation in record.observations:
                            serialized_observation = canonical_json(
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
                            if len(serialized_observation.encode("utf-8")) > MAX_OBSERVATION_PAYLOAD_BYTES:
                                raise ValueError("observation payload exceeds the safety limit")
                            serialized_observations.append(serialized_observation + "\n")
                        serialized_raw = canonical_json(raw_row) + "\n"
                        serialized_bytes = len(serialized_raw.encode("utf-8")) + sum(
                            len(value.encode("utf-8")) for value in serialized_observations
                        )
                        if artifact_bytes + serialized_bytes > MAX_ARTIFACT_BYTES:
                            collector_failure = True
                            add_error(f"artifact exceeds safety limit ({MAX_ARTIFACT_BYTES} bytes)")
                            break
                        raw_file.write(serialized_raw)
                        observations_file.writelines(serialized_observations)
                        artifact_bytes += serialized_bytes
                        records_valid += 1
                    except (TypeError, ValueError, KeyError) as error:
                        records_rejected += 1
                        add_error(f"record {records_received}: {_safe_error_detail(error)}")
                        invalid_row = canonical_json(
                            {
                                "source_key": getattr(record, "source_key", source.source_key),
                                "record_type": getattr(record, "record_type", "unknown"),
                                "parse_status": "invalid",
                                # Invalid records are still persisted for
                                # audit, but parser/transport exceptions
                                # can echo signed URLs or API tokens.
                                "error_detail": _safe_error_detail(error),
                            }
                        ) + "\n"
                        invalid_bytes = len(invalid_row.encode("utf-8"))
                        if artifact_bytes + invalid_bytes > MAX_ARTIFACT_BYTES:
                            collector_failure = True
                            add_error(f"artifact exceeds safety limit ({MAX_ARTIFACT_BYTES} bytes)")
                            break
                        raw_file.write(invalid_row)
                        artifact_bytes += invalid_bytes
            except Exception as error:  # adapters must not hide transport/parser failures
                collector_failure = True
                add_error(f"collector failure: {_safe_error_detail(error)}")

            # Adapters that intentionally continue after a per-page failure
            # expose those failures without aborting the rest of the batch.
            # Treat the run as partial/quarantined evidence rather than
            # silently calling an incomplete crawl successful.
            adapter_errors = getattr(collector, "errors", ())
            if adapter_errors:
                collector_failure = True
                for error in adapter_errors:
                    add_error(f"adapter: {_safe_error_detail(error)}")

        deviation = None
        if previous_success_count and previous_success_count > 0:
            deviation = round((records_received - previous_success_count) / previous_success_count * 100, 4)

        status = "succeeded"
        if collector_failure:
            status = "failed" if records_valid == 0 else "quarantined"
        if source.expected_min_records is not None and records_received < source.expected_min_records:
            status = "quarantined"
            add_error(f"received {records_received}, below expected minimum {source.expected_min_records}")
        if source.expected_max_records is not None and records_received > source.expected_max_records:
            status = "quarantined"
            add_error(f"received {records_received}, above expected maximum {source.expected_max_records}")
        if deviation is not None and deviation < -source.max_negative_deviation_pct:
            status = "quarantined"
            add_error(f"negative deviation {deviation}% exceeds safety limit")

        if status == "quarantined":
            self._mark_observations_quarantined(observations_path)
        records_published = 0
        manifest = {
            "source_key": source.source_key,
            "source_name": source.name,
            "source_type": source.source_type,
            "usage_policy_status": source.usage_policy_status,
            "endpoint_type": source.endpoint_type,
            # Endpoint metadata is operational evidence too; strip any query,
            # fragment or credentials before it reaches a manifest/database.
            "endpoint_url": _safe_source_url(source.endpoint_url),
            "parser_version": source.parser_version,
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
        temporary = path.with_name(f".{path.name}.quarantine.tmp")
        try:
            with path.open("rb") as source, temporary.open("w", encoding="utf-8", newline="\n") as target:
                line_number = 0
                total_bytes = 0
                while True:
                    raw_line = source.readline(MAX_ARTIFACT_LINE_BYTES + 1)
                    if not raw_line:
                        break
                    line_number += 1
                    total_bytes += len(raw_line)
                    if total_bytes > MAX_ARTIFACT_BYTES:
                        raise ValueError(f"observation artifact exceeds {MAX_ARTIFACT_BYTES} bytes")
                    if len(raw_line) > MAX_ARTIFACT_LINE_BYTES:
                        raise ValueError(f"observation artifact line {line_number} exceeds the safety limit")
                    row = json.loads(raw_line.decode("utf-8"))
                    if not isinstance(row, dict):
                        raise ValueError(f"observation artifact row {line_number} must be an object")
                    row["status"] = "quarantined"
                    target.write(canonical_json(row) + "\n")
            os.replace(temporary, path)
        except Exception:
            temporary.unlink(missing_ok=True)
            raise
