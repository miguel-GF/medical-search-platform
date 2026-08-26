from __future__ import annotations

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

        with self.connection.transaction():
            source_id = self._ensure_source(source)
            endpoint_id = self._ensure_endpoint(source_id, source)
            crawl_run_id = self._create_crawl_run(endpoint_id, summary)
            raw_record_ids = self._insert_raw_records(source_id, crawl_run_id, raw_path)
            self._insert_observations(source_id, raw_record_ids, observations_path)
            self._finish_crawl_run(crawl_run_id, summary, len(raw_record_ids))
        return len(raw_record_ids)

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
                  expected_min_records, expected_max_records, max_negative_deviation_pct
                )
                values (%s, %s, 'api', 'pruevia_collectors', '0.1.0', %s, %s, %s)
                returning id
                """,
                (
                    source_id,
                    endpoint_name,
                    source.expected_min_records,
                    source.expected_max_records,
                    source.max_negative_deviation_pct,
                ),
            ).fetchone()[0]
        )

    def _create_crawl_run(self, endpoint_id: str, summary: RunSummary) -> str:
        return str(
            self.connection.execute(
                """
                insert into ingest.crawl_runs(
                  id, source_endpoint_id, started_at, finished_at, status,
                  records_received, records_valid, records_rejected, records_published,
                  previous_success_count, deviation_percentage, error_summary, metadata
                )
                values (%s, %s, now(), now(), %s, %s, %s, %s, 0, %s, %s, %s, %s)
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
            ).fetchone()[0]
        )

    def _insert_raw_records(self, source_id: str, crawl_run_id: str, raw_path: Path) -> dict[str, str]:
        record_ids: dict[str, str] = {}
        for line in raw_path.read_text(encoding="utf-8").splitlines():
            row: dict[str, Any] = json.loads(line)
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

    def _insert_observations(self, source_id: str, record_ids: dict[str, str], observations_path: Path) -> int:
        inserted_count = 0
        for line in observations_path.read_text(encoding="utf-8").splitlines():
            row: dict[str, Any] = json.loads(line)
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
            (0 if summary.status == "quarantined" else published_count, crawl_run_id),
        )
