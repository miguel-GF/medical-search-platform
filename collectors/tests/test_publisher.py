import hashlib
import json
from pathlib import Path
from unittest.mock import MagicMock

import pytest

from pruevia_collectors.models import RunSummary, SourceSpec
from pruevia_collectors import publisher as publisher_module
from pruevia_collectors.publisher import IngestPublisher


def test_publisher_requires_complete_artifacts(tmp_path: Path):
    connection = MagicMock()
    publisher = IngestPublisher(connection)
    summary = RunSummary(
        source_key="fixture",
        run_id="run-1",
        status="succeeded",
        records_received=0,
        records_valid=0,
        records_rejected=0,
        records_published=0,
        previous_success_count=None,
        deviation_percentage=None,
        artifact_directory=str(tmp_path),
    )

    try:
        publisher.publish(SourceSpec("fixture", "Fixture", "manual"), summary)
    except FileNotFoundError as error:
        assert "artifacts are incomplete" in str(error)
    else:
        raise AssertionError("publisher should reject incomplete artifacts")


def test_publisher_does_not_publish_without_a_raw_record(tmp_path: Path):
    (tmp_path / "raw_records.jsonl").write_text("", encoding="utf-8")
    (tmp_path / "observations.jsonl").write_text("", encoding="utf-8")
    connection = MagicMock()
    connection.execute.return_value.fetchone.return_value = ("source-id",)
    connection.transaction.return_value.__enter__.return_value = connection
    summary = RunSummary(
        source_key="fixture",
        run_id="run-1",
        status="succeeded",
        records_received=0,
        records_valid=0,
        records_rejected=0,
        records_published=0,
        previous_success_count=None,
        deviation_percentage=None,
        artifact_directory=str(tmp_path),
    )

    IngestPublisher(connection).publish(SourceSpec("fixture", "Fixture", "manual"), summary)
    # Source and endpoint lookups are allowed; no raw/observation insert occurs.
    statements = [call.args[0] for call in connection.execute.call_args_list]
    assert not any("insert into ingest.raw_records" in statement for statement in statements)
    assert not any("insert into ingest.source_observations" in statement for statement in statements)


def test_publisher_strips_signed_endpoint_material_before_persisting(tmp_path: Path):
    (tmp_path / "raw_records.jsonl").write_text("", encoding="utf-8")
    (tmp_path / "observations.jsonl").write_text("", encoding="utf-8")
    connection = MagicMock()
    connection.execute.return_value.fetchone.return_value = ("source-id",)
    connection.transaction.return_value.__enter__.return_value = connection
    summary = RunSummary(
        source_key="fixture",
        run_id="run-1",
        status="succeeded",
        records_received=0,
        records_valid=0,
        records_rejected=0,
        records_published=0,
        previous_success_count=None,
        deviation_percentage=None,
        artifact_directory=str(tmp_path),
    )

    IngestPublisher(connection).publish(
        SourceSpec(
            "fixture",
            "Fixture",
            "manual",
            endpoint_url="https://example.test/catalog?access_token=do-not-persist#fragment",
        ),
        summary,
    )

    endpoint_updates = [
        call for call in connection.execute.call_args_list
        if "update ingest.source_endpoints" in call.args[0]
    ]
    assert endpoint_updates
    assert endpoint_updates[0].args[1][2] == "https://example.test/catalog"


def test_new_source_cannot_self_approve_from_collector_manifest(tmp_path: Path):
    (tmp_path / "raw_records.jsonl").write_text("", encoding="utf-8")
    (tmp_path / "observations.jsonl").write_text("", encoding="utf-8")
    connection = MagicMock()
    connection.transaction.return_value.__enter__.return_value = connection
    connection.execute.side_effect = [
        MagicMock(fetchone=MagicMock(return_value=None)),
        MagicMock(fetchone=MagicMock(return_value=("new-source-id",))),
        MagicMock(fetchone=MagicMock(return_value=None)),
        MagicMock(fetchone=MagicMock(return_value=("endpoint-id",))),
        MagicMock(fetchone=MagicMock(return_value=("run-id",))),
        MagicMock(),
        MagicMock(),
    ]
    summary = RunSummary(
        source_key="fixture", run_id="run-id", status="succeeded",
        records_received=0, records_valid=0, records_rejected=0,
        records_published=0, previous_success_count=None,
        deviation_percentage=None, artifact_directory=str(tmp_path),
    )

    IngestPublisher(connection).publish(
        SourceSpec("fixture", "Fixture", "provider_official", usage_policy_status="approved"),
        summary,
    )

    source_inserts = [
        call for call in connection.execute.call_args_list
        if "insert into ingest.sources(" in call.args[0]
    ]
    assert len(source_inserts) == 1
    assert "'review_required'" in source_inserts[0].args[0]
    assert "approved" not in source_inserts[0].args[1]


def test_scheduled_ingest_rejects_changed_source_identity_before_writing(tmp_path: Path):
    (tmp_path / "raw_records.jsonl").write_text("", encoding="utf-8")
    (tmp_path / "observations.jsonl").write_text("", encoding="utf-8")
    connection = MagicMock()
    connection.transaction.return_value.__enter__.return_value = connection
    connection.execute.return_value.fetchone.return_value = ("other-source",)
    summary = RunSummary(
        source_key="fixture", run_id="run-id", status="succeeded",
        records_received=0, records_valid=0, records_rejected=0,
        records_published=0, previous_success_count=None,
        deviation_percentage=None, artifact_directory=str(tmp_path),
    )

    with pytest.raises(ValueError, match="identity changed"):
        IngestPublisher(connection).publish(
            SourceSpec("fixture", "Fixture", "provider_official"),
            summary,
            expected_source_id="reviewed-source",
        )

    assert len(connection.execute.call_args_list) == 1


def test_publisher_rejects_oversized_payload_before_database_write(tmp_path: Path):
    payload = {"value": "x" * (512 * 1024)}
    record_hash = hashlib.sha256(
        json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()
    (tmp_path / "raw_records.jsonl").write_text(
        json.dumps({
            "source_key": "fixture",
            "record_hash": record_hash,
            "parse_status": "parsed",
            "record_type": "fixture",
            "payload": payload,
        }) + "\n",
        encoding="utf-8",
    )
    (tmp_path / "observations.jsonl").write_text("", encoding="utf-8")
    connection = MagicMock()
    summary = RunSummary(
        source_key="fixture",
        run_id="run-oversized",
        status="succeeded",
        records_received=1,
        records_valid=1,
        records_rejected=0,
        records_published=0,
        previous_success_count=None,
        deviation_percentage=None,
        artifact_directory=str(tmp_path),
    )

    try:
        IngestPublisher(connection).publish(SourceSpec("fixture", "Fixture", "manual"), summary)
    except ValueError as error:
        assert "exceeds the safety limit" in str(error)
    else:
        raise AssertionError("publisher should reject oversized payloads")
    connection.execute.assert_not_called()


def test_publisher_rejects_non_object_artifact_rows(tmp_path: Path):
    (tmp_path / "raw_records.jsonl").write_text("null\n", encoding="utf-8")
    (tmp_path / "observations.jsonl").write_text("", encoding="utf-8")
    connection = MagicMock()
    summary = RunSummary(
        source_key="fixture",
        run_id="run-malformed",
        status="succeeded",
        records_received=1,
        records_valid=0,
        records_rejected=1,
        records_published=0,
        previous_success_count=None,
        deviation_percentage=None,
        artifact_directory=str(tmp_path),
    )

    try:
        IngestPublisher(connection).publish(SourceSpec("fixture", "Fixture", "manual"), summary)
    except ValueError as error:
        assert "JSON is invalid" in str(error)
    else:
        raise AssertionError("publisher should reject non-object rows")
    connection.execute.assert_not_called()


def test_publisher_rejects_oversized_artifact_file(tmp_path: Path, monkeypatch):
    monkeypatch.setattr(publisher_module, "MAX_ARTIFACT_BYTES", 10)
    (tmp_path / "raw_records.jsonl").write_text('{"row": 1}\n', encoding="utf-8")
    (tmp_path / "observations.jsonl").write_text("", encoding="utf-8")
    connection = MagicMock()
    summary = RunSummary(
        source_key="fixture",
        run_id="run-large-artifact",
        status="succeeded",
        records_received=0,
        records_valid=0,
        records_rejected=0,
        records_published=0,
        previous_success_count=None,
        deviation_percentage=None,
        artifact_directory=str(tmp_path),
    )

    try:
        IngestPublisher(connection).publish(SourceSpec("fixture", "Fixture", "manual"), summary)
    except ValueError as error:
        assert "artifact exceeds" in str(error)
    else:
        raise AssertionError("publisher should reject oversized artifact files")
    connection.execute.assert_not_called()


def test_publisher_is_idempotent_for_an_existing_crawl_run(tmp_path: Path):
    payload = {"name": "fixture"}
    record_hash = hashlib.sha256(json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()
    (tmp_path / "raw_records.jsonl").write_text(json.dumps({"source_key": "fixture", "record_hash": record_hash, "parse_status": "parsed", "record_type": "fixture", "payload": payload}) + "\n", encoding="utf-8")
    (tmp_path / "observations.jsonl").write_text("", encoding="utf-8")
    connection = MagicMock()
    connection.transaction.return_value.__enter__.return_value = connection
    connection.execute.side_effect = [
        MagicMock(fetchone=MagicMock(return_value=("source-id",))),
        MagicMock(fetchone=MagicMock(return_value=("endpoint-id",))),
        MagicMock(),
        MagicMock(fetchone=MagicMock(return_value=None)),
        MagicMock(fetchone=MagicMock(return_value=("run-1",))),
        MagicMock(fetchone=MagicMock(return_value=(7,))),
    ]
    summary = RunSummary(
        source_key="fixture",
        run_id="run-1",
        status="succeeded",
        records_received=1,
        records_valid=1,
        records_rejected=0,
        records_published=1,
        previous_success_count=None,
        deviation_percentage=None,
        artifact_directory=str(tmp_path),
    )

    assert IngestPublisher(connection).publish(SourceSpec("fixture", "Fixture", "manual"), summary) == 7
    statements = [call.args[0] for call in connection.execute.call_args_list]
    assert not any("insert into ingest.raw_records" in statement for statement in statements)
