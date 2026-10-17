"""One bounded collector run, prepared for a future approved scheduler.

No source is enabled merely by importing this module. The database policy is
checked before the first external request and again before ingest publication.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from uuid import UUID

import psycopg
from psycopg import Connection

from .automation_preflight import SCHEDULE_CANDIDATES, SourceNotApproved, check_source
from .cli_publish import load_summary, validated_artifact_counts
from .config import COLLECTORS_ROOT, load_local_environment
from .models import SourceSpec
from .publisher import IngestPublisher, _safe_endpoint_url


@dataclass(frozen=True)
class ScheduledJob:
    source: SourceSpec
    module: str
    arguments: tuple[str, ...]


# Start with one bounded catalog pilot. Additional adapters need a reviewed
# complete-snapshot plan before they can update freshness on a schedule.
SCHEDULED_JOBS = {
    "semin_catalog_puebla": ScheduledJob(
        source=SCHEDULE_CANDIDATES["semin_catalog_puebla"],
        module="pruevia_collectors.cli_semin",
        arguments=("--max-pages", "8", "--max-results", "150", "--max-details", "150"),
    ),
}


class ScheduledRunError(RuntimeError):
    """The scheduled run stopped without publishing evidence."""


def run_once(
    connection: Connection,
    job: ScheduledJob,
    artifact_root: Path,
    *,
    timeout_seconds: int = 900,
) -> dict[str, object]:
    if not 1 <= timeout_seconds <= 1800:
        raise ValueError("timeout must be between 1 and 1800 seconds")
    approved = check_source(connection, job.source)
    lock_key = f"pruevia:collector:{job.source.source_key}"
    locked = connection.execute(
        "select pg_try_advisory_lock(hashtextextended(%s, 0))", (lock_key,)
    ).fetchone()
    if not locked or locked[0] is not True:
        raise ScheduledRunError("collector already running for this source")
    try:
        approved = check_source(connection, job.source)
        root = artifact_root.resolve()
        child_environment = os.environ.copy()
        child_environment.pop("PRUEVIA_DATABASE_URL", None)
        command = [
            sys.executable, "-m", job.module, *job.arguments,
            "--artifact-root", str(root),
        ]
        try:
            completed = subprocess.run(
                command,
                cwd=COLLECTORS_ROOT,
                env=child_environment,
                text=True,
                capture_output=True,
                timeout=timeout_seconds,
                check=False,
            )
        except subprocess.TimeoutExpired as error:
            raise ScheduledRunError("collector exceeded its time limit") from error
        if completed.returncode != 0:
            raise ScheduledRunError("collector failed or quarantined its run")
        try:
            payload = json.loads(completed.stdout)
            run_id = str(UUID(payload["run_id"]))
            run_directory = Path(payload["artifact_directory"]).resolve()
        except (TypeError, ValueError, KeyError, json.JSONDecodeError) as error:
            raise ScheduledRunError("collector did not return a valid run summary") from error
        if run_directory != root / job.source.source_key / run_id:
            raise ScheduledRunError("collector returned an unexpected artifact path")
        artifact_source, summary = load_summary(run_directory)
        if (
            summary.run_id != run_id
            or summary.status != "succeeded"
            or artifact_source.source_key != job.source.source_key
            or artifact_source.name != job.source.name
            or artifact_source.source_type != job.source.source_type
            or _safe_endpoint_url(artifact_source.endpoint_url) != _safe_endpoint_url(job.source.endpoint_url)
        ):
            raise ScheduledRunError("collector artifact does not match the reviewed source")
        validated_artifact_counts(artifact_source, summary)
        reviewed_again = check_source(connection, job.source)
        if reviewed_again != approved:
            raise ScheduledRunError("source identity changed during collection")
        published = IngestPublisher(connection).publish(
            artifact_source, summary, expected_source_id=approved.source_id
        )
        return {
            "source_key": job.source.source_key,
            "run_id": run_id,
            "status": "ingested_evidence",
            "raw_records": published,
        }
    finally:
        connection.execute(
            "select pg_advisory_unlock(hashtextextended(%s, 0))", (lock_key,)
        )


def main() -> int:
    load_local_environment()
    parser = argparse.ArgumentParser(description="Run one approved, bounded Pruevia collector")
    parser.add_argument("source_key", choices=sorted(SCHEDULED_JOBS))
    parser.add_argument("--artifact-root", type=Path, default=Path("artifacts/scheduled"))
    parser.add_argument("--timeout-seconds", type=int, default=900)
    args = parser.parse_args()
    database_url = os.getenv("PRUEVIA_DATABASE_URL")
    if not database_url:
        parser.error("PRUEVIA_DATABASE_URL is required")
    try:
        with psycopg.connect(database_url) as connection:
            result = run_once(
                connection, SCHEDULED_JOBS[args.source_key], args.artifact_root,
                timeout_seconds=args.timeout_seconds,
            )
    except (SourceNotApproved, ScheduledRunError) as error:
        print(json.dumps({"source_key": args.source_key, "status": "stopped", "reason": str(error)}))
        return 2
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
