from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from psycopg import Connection
from psycopg.types.json import Jsonb

from .models import RunSummary, SourceSpec


class IngestPublisher:
    """Publishes collector evidence into the ingest schema only.

    This deliberately stops before canonical provider/catalog publishing. A later
    normalization workflow must review observations before creating core/supply
    entities.
    """

    def __init__(self, connection: Connection) -> None:
        self.connection = connection

    def publish(self, source: SourceSpec, summary: RunSummary) -> int:
        artifact_dir = Path(summary.artifact_directory)
        raw_path = artifact_dir / "raw_records.jsonl"
        observations_path = artifact_dir / "observations.jsonl"
        if not raw_path.exists() or not observations_path.exists():
            raise FileNotFoundError(f"collector artifacts are incomplete: {artifact_dir}")
        raw_rows, observation_rows = self._validate_artifacts(source, summary, raw_path, observations_path)

        with self.connection.transaction():
            source_id = self._ensure_source(source)
            endpoint_id = self._ensure_endpoint(source_id, source)
            crawl_run_id, inserted = self._create_crawl_run(endpoint_id, summary)
            if not inserted:
                row = self.connection.execute(
                    "select records_published from ingest.crawl_runs where id = %s",
                    (crawl_run_id,),
                ).fetchone()
                return int(row[0]) if row else 0
            raw_record_ids = self._insert_raw_records(source_id, crawl_run_id, raw_rows)
            self._insert_observations(source_id, raw_record_ids, observation_rows)
            self._finish_crawl_run(crawl_run_id, summary, len(raw_record_ids))
        return len(raw_record_ids)

    @staticmethod
    def _canonical_json(value: object) -> str:
        return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), default=str)

    def _validate_artifacts(self, source: SourceSpec, summary: RunSummary, raw_path: Path, observations_path: Path) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
        if summary.status not in {"succeeded", "quarantined", "failed"}:
            raise ValueError(f"unsupported collector run status: {summary.status}")
        try:
            raw_rows = [json.loads(line) for line in raw_path.read_text(encoding="utf-8").splitlines() if line]
            observation_rows = [json.loads(line) for line in observations_path.read_text(encoding="utf-8").splitlines() if line]
        except (OSError, json.JSONDecodeError) as error:
            raise ValueError(f"collector artifact JSON is invalid: {error}") from error
        if len(raw_rows) != summary.records_received:
            raise ValueError("raw record count does not match the run summary")
        parsed_hashes: set[str] = set()
        parsed_count = rejected_count = 0
        for row in raw_rows:
            if row.get("source_key") != source.source_key:
                raise ValueError("raw record source_key does not match the collector source")
            if row.get("parse_status") != "parsed":
                rejected_count += 1
                continue
            parsed_count += 1
            record_hash = row.get("record_hash")
            if not isinstance(record_hash, str) or len(record_hash) != 64:
                raise ValueError("raw record has an invalid hash")
            expected_hash = hashlib.sha256(self._canonical_json(row.get("payload")).encode("utf-8")).hexdigest()
            if record_hash != expected_hash:
                raise ValueError("raw record hash does not match its payload")
            parsed_hashes.add(record_hash)
        if parsed_count != summary.records_valid or rejected_count != summary.records_rejected:
            raise ValueError("raw record counts do not match the run summary")
        if any(row.get("record_hash") not in parsed_hashes for row in observation_rows):
            raise ValueError("observations contain a hash without a parsed raw record")
        return raw_rows, observation_rows

    def _ensure_source(self, source: SourceSpec) -> str:
        row = self.connection.execute(
            """
            select id
            from ingest.sources
            where name = %s and source_type = %s
            order by created_at
            limit 1
            """,
            (source.name, source.source_type),
        ).fetchone()
        if row:
            self.connection.execute(
                """
                update ingest.source_endpoints
                set endpoint_type = %s, parser_version = %s, url = %s,
                    expected_min_records = %s, expected_max_records = %s,
                    max_negative_deviation_pct = %s, updated_at = now()
                where source_id = %s and name = %s
                """,
                (
                    source.endpoint_type,
                    source.parser_version,
                    source.endpoint_url,
                    source.expected_min_records,
                    source.expected_max_records,
                    source.max_negative_deviation_pct,
                    row[0],
                    f"{source.name} collector endpoint",
                ),
            )
            return str(row[0])
        return str(
            self.connection.execute(
                """
                insert into ingest.sources(name, source_type, trust_rank, usage_policy_status)
                values (%s, %s, %s, %s)
                returning id
                """,
                (source.name, source.source_type, 80, source.usage_policy_status),
            ).fetchone()[0]
        )

    def _ensure_endpoint(self, source_id: str, source: SourceSpec) -> str:
        endpoint_name = f"{source.name} collector endpoint"
        row = self.connection.execute(
            """
            select id
            from ingest.source_endpoints
            where source_id = %s and name = %s
            order by created_at
            limit 1
            """,
            (source_id, endpoint_name),
        ).fetchone()
        if row:
            return str(row[0])
        return str(
            self.connection.execute(
                """
                insert into ingest.source_endpoints(
                  source_id, name, endpoint_type, parser_name, parser_version,
                  url, expected_min_records, expected_max_records, max_negative_deviation_pct
                )
                values (%s, %s, %s, 'pruevia_collectors', %s, %s, %s, %s, %s)
                returning id
                """,
                (
                    source_id,
                    endpoint_name,
                    source.endpoint_type,
                    source.parser_version,
                    source.endpoint_url,
                    source.expected_min_records,
                    source.expected_max_records,
                    source.max_negative_deviation_pct,
                ),
            ).fetchone()[0]
        )

    def _create_crawl_run(self, endpoint_id: str, summary: RunSummary) -> tuple[str, bool]:
        row = self.connection.execute(
            """
                insert into ingest.crawl_runs(
                  id, source_endpoint_id, started_at, finished_at, status,
                  records_received, records_valid, records_rejected, records_published,
                  previous_success_count, deviation_percentage, error_summary, metadata
                )
                values (%s, %s, now(), now(), %s, %s, %s, %s, 0, %s, %s, %s, %s)
                on conflict (id) do nothing
                returning id
                """,
            (
                summary.run_id,
                endpoint_id,
                summary.status,
                summary.records_received,
                summary.records_valid,
                summary.records_rejected,
                summary.previous_success_count,
                summary.deviation_percentage,
                "\n".join(summary.errors) or None,
                Jsonb({"artifact_directory": summary.artifact_directory}),
            ),
        ).fetchone()
        if row:
            return str(row[0]), True
        existing = self.connection.execute(
            "select id from ingest.crawl_runs where id = %s",
            (summary.run_id,),
        ).fetchone()
        if not existing:
            raise RuntimeError(f"crawl run {summary.run_id} was not created")
        return str(existing[0]), False

    def _insert_raw_records(self, source_id: str, crawl_run_id: str, raw_rows: list[dict[str, Any]]) -> dict[str, str]:
        record_ids: dict[str, str] = {}
        for row in raw_rows:
            record_hash = row.get("record_hash")
            if not record_hash or row.get("parse_status") != "parsed":
                continue
            inserted = self.connection.execute(
                """
                insert into ingest.raw_records(
                  crawl_run_id, source_id, external_record_id, record_type,
                  payload, record_hash, observed_at, parse_status
                )
                values (%s, %s, %s, %s, %s, %s, %s, %s)
                on conflict (crawl_run_id, record_hash) do update
                  set payload = excluded.payload
                returning id
                """,
                (
                    crawl_run_id,
                    source_id,
                    row.get("external_record_id"),
                    row["record_type"],
                    Jsonb(row["payload"]),
                    record_hash,
                    row.get("observed_at"),
                    row.get("parse_status", "parsed"),
                ),
            ).fetchone()
            record_ids[record_hash] = str(inserted[0])
        return record_ids

    def _insert_observations(self, source_id: str, record_ids: dict[str, str], observation_rows: list[dict[str, Any]]) -> int:
        inserted_count = 0
        for row in observation_rows:
            raw_record_id = record_ids.get(row.get("record_hash"))
            self.connection.execute(
                """
                insert into ingest.source_observations(
                  source_id, raw_record_id, entity_type, entity_id,
                  attribute_name, observed_value, observed_at, confidence, status
                )
                values (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    source_id,
                    raw_record_id,
                    row["entity_type"],
                    row.get("entity_id"),
                    row.get("attribute_name"),
                    Jsonb(row.get("observed_value")),
                    row.get("observed_at"),
                    row.get("confidence", 1.0),
                    row.get("status", "candidate"),
                ),
            )
            inserted_count += 1
        return inserted_count

    def _finish_crawl_run(self, crawl_run_id: str, summary: RunSummary, published_count: int) -> None:
        self.connection.execute(
            "update ingest.crawl_runs set records_published = %s where id = %s",
            (published_count if summary.status == "succeeded" else 0, crawl_run_id),
        )
        if summary.status == "succeeded":
            self.connection.execute(
                """
                update ingest.source_endpoints se
                set last_success_at = now(), updated_at = now()
                from ingest.crawl_runs cr
                where cr.id = %s and se.id = cr.source_endpoint_id
                """,
                (crawl_run_id,),
            )
