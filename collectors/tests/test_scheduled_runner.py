import hashlib
import json
import subprocess
from pathlib import Path
from unittest.mock import MagicMock
from uuid import uuid4

import pytest

from pruevia_collectors.automation_preflight import ApprovedSource, SourceNotApproved
from pruevia_collectors import scheduled_runner


def _connection():
    connection = MagicMock()
    connection.execute.return_value.fetchone.return_value = (True,)
    return connection


def _artifact(root: Path, source_key: str, source_name: str, source_type: str, endpoint_url: str):
    run_id = str(uuid4())
    run_directory = root / source_key / run_id
    run_directory.mkdir(parents=True)
    payload = {"name": "Biometría hemática"}
    record_hash = hashlib.sha256(
        json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()
    (run_directory / "raw_records.jsonl").write_text(
        json.dumps({"source_key": source_key, "record_hash": record_hash,
                    "parse_status": "parsed", "record_type": "offer", "payload": payload}) + "\n",
        encoding="utf-8",
    )
    (run_directory / "observations.jsonl").write_text("", encoding="utf-8")
    (run_directory / "run_manifest.json").write_text(json.dumps({
        "source_key": source_key,
        "source_name": source_name,
        "source_type": source_type,
        "endpoint_url": endpoint_url,
        "run_id": run_id,
        "status": "succeeded",
        "records_received": 1,
        "records_valid": 1,
        "records_rejected": 0,
    }), encoding="utf-8")
    return run_id, run_directory


def test_scheduled_runner_stops_before_network_for_unapproved_source(tmp_path, monkeypatch):
    job = scheduled_runner.SCHEDULED_JOBS["semin_catalog_puebla"]
    monkeypatch.setattr(scheduled_runner, "check_source", MagicMock(side_effect=SourceNotApproved("review required")))
    launch = MagicMock()
    monkeypatch.setattr(scheduled_runner.subprocess, "run", launch)
    connection = _connection()

    with pytest.raises(SourceNotApproved, match="review required"):
        scheduled_runner.run_once(connection, job, tmp_path)

    launch.assert_not_called()
    connection.execute.assert_not_called()


def test_scheduled_runner_validates_and_ingests_only_reviewed_artifact(tmp_path, monkeypatch):
    job = scheduled_runner.SCHEDULED_JOBS["semin_catalog_puebla"]
    approved = ApprovedSource(job.source.source_key, "source-id", "endpoint-id")
    policy_check = MagicMock(return_value=approved)
    monkeypatch.setattr(scheduled_runner, "check_source", policy_check)
    run_id, artifact_directory = _artifact(
        tmp_path, job.source.source_key, job.source.name,
        job.source.source_type, job.source.endpoint_url,
    )
    launch = MagicMock(return_value=subprocess.CompletedProcess(
        [], 0, stdout=json.dumps({"run_id": run_id, "artifact_directory": str(artifact_directory)}), stderr=""
    ))
    monkeypatch.setattr(scheduled_runner.subprocess, "run", launch)
    publisher = MagicMock()
    publisher.publish.return_value = 1
    monkeypatch.setattr(scheduled_runner, "IngestPublisher", MagicMock(return_value=publisher))
    monkeypatch.setenv("PRUEVIA_DATABASE_URL", "private-test-dsn")
    connection = _connection()

    result = scheduled_runner.run_once(connection, job, tmp_path)

    assert result["status"] == "ingested_evidence"
    assert result["raw_records"] == 1
    assert policy_check.call_count == 3
    assert "PRUEVIA_DATABASE_URL" not in launch.call_args.kwargs["env"]
    assert launch.call_args.kwargs["timeout"] == 900
    assert publisher.publish.call_args.kwargs == {"expected_source_id": "source-id"}
    statements = [call.args[0] for call in connection.execute.call_args_list]
    assert any("pg_try_advisory_lock" in statement for statement in statements)
    assert any("pg_advisory_unlock" in statement for statement in statements)


def test_scheduled_runner_does_not_ingest_failed_collector(tmp_path, monkeypatch):
    job = scheduled_runner.SCHEDULED_JOBS["semin_catalog_puebla"]
    monkeypatch.setattr(scheduled_runner, "check_source", MagicMock(
        return_value=ApprovedSource(job.source.source_key, "source-id", "endpoint-id")
    ))
    monkeypatch.setattr(scheduled_runner.subprocess, "run", MagicMock(
        return_value=subprocess.CompletedProcess([], 2, stdout="", stderr="failed")
    ))
    publisher = MagicMock()
    monkeypatch.setattr(scheduled_runner, "IngestPublisher", publisher)
    connection = _connection()

    with pytest.raises(scheduled_runner.ScheduledRunError, match="quarantined"):
        scheduled_runner.run_once(connection, job, tmp_path)

    publisher.assert_not_called()
    assert "pg_advisory_unlock" in connection.execute.call_args.args[0]


def test_scheduled_runner_rejects_overlap_before_network(tmp_path, monkeypatch):
    job = scheduled_runner.SCHEDULED_JOBS["semin_catalog_puebla"]
    monkeypatch.setattr(scheduled_runner, "check_source", MagicMock(
        return_value=ApprovedSource(job.source.source_key, "source-id", "endpoint-id")
    ))
    launch = MagicMock()
    monkeypatch.setattr(scheduled_runner.subprocess, "run", launch)
    connection = _connection()
    connection.execute.return_value.fetchone.return_value = (False,)

    with pytest.raises(scheduled_runner.ScheduledRunError, match="already running"):
        scheduled_runner.run_once(connection, job, tmp_path)

    launch.assert_not_called()
    assert not any("pg_advisory_unlock" in call.args[0] for call in connection.execute.call_args_list)


def test_scheduled_runner_releases_lock_after_timeout(tmp_path, monkeypatch):
    job = scheduled_runner.SCHEDULED_JOBS["semin_catalog_puebla"]
    monkeypatch.setattr(scheduled_runner, "check_source", MagicMock(
        return_value=ApprovedSource(job.source.source_key, "source-id", "endpoint-id")
    ))
    monkeypatch.setattr(scheduled_runner.subprocess, "run", MagicMock(
        side_effect=subprocess.TimeoutExpired(["python"], 1)
    ))
    publisher = MagicMock()
    monkeypatch.setattr(scheduled_runner, "IngestPublisher", publisher)
    connection = _connection()

    with pytest.raises(scheduled_runner.ScheduledRunError, match="time limit"):
        scheduled_runner.run_once(connection, job, tmp_path, timeout_seconds=1)

    publisher.assert_not_called()
    assert "pg_advisory_unlock" in connection.execute.call_args.args[0]


def test_scheduled_runner_rejects_artifact_from_a_different_source(tmp_path, monkeypatch):
    job = scheduled_runner.SCHEDULED_JOBS["semin_catalog_puebla"]
    monkeypatch.setattr(scheduled_runner, "check_source", MagicMock(
        return_value=ApprovedSource(job.source.source_key, "source-id", "endpoint-id")
    ))
    run_id, artifact_directory = _artifact(
        tmp_path, job.source.source_key, "Different provider",
        job.source.source_type, job.source.endpoint_url,
    )
    monkeypatch.setattr(scheduled_runner.subprocess, "run", MagicMock(
        return_value=subprocess.CompletedProcess(
            [], 0, stdout=json.dumps({"run_id": run_id, "artifact_directory": str(artifact_directory)}), stderr=""
        )
    ))
    publisher = MagicMock()
    monkeypatch.setattr(scheduled_runner, "IngestPublisher", publisher)

    with pytest.raises(scheduled_runner.ScheduledRunError, match="does not match"):
        scheduled_runner.run_once(_connection(), job, tmp_path)

    publisher.assert_not_called()
