import json
from pathlib import Path
from unittest.mock import MagicMock

from pruevia_collectors.models import RunSummary, SourceSpec
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


def test_publisher_is_idempotent_for_an_existing_crawl_run(tmp_path: Path):
    (tmp_path / "raw_records.jsonl").write_text('{"record_hash":"hash"}\n', encoding="utf-8")
    (tmp_path / "observations.jsonl").write_text("", encoding="utf-8")
    connection = MagicMock()
    connection.transaction.return_value.__enter__.return_value = connection
    connection.execute.side_effect = [
        MagicMock(fetchone=MagicMock(return_value=("source-id",))),
        MagicMock(fetchone=MagicMock(return_value=("endpoint-id",))),
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
