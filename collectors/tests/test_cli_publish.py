import hashlib
import json
from pathlib import Path

import pytest

from pruevia_collectors.cli_publish import artifact_counts, load_summary, validated_artifact_counts
from pruevia_collectors.models import RunSummary, SourceSpec


def test_publish_cli_loads_manifest_and_counts_artifacts(tmp_path: Path):
    (tmp_path / "run_manifest.json").write_text(
        json.dumps(
            {
                "source_key": "chopo_puebla",
                "source_name": "Chopo Puebla",
                "source_type": "provider_official",
                "usage_policy_status": "review_required",
                "endpoint_type": "html",
                "endpoint_url": "https://example.test/estudios",
                "parser_version": "0.1.0",
                "run_id": "run-1",
                "status": "succeeded",
                "records_received": 1,
                "records_valid": 1,
                "records_rejected": 0,
                "records_published": 0,
                "previous_success_count": None,
                "deviation_percentage": None,
                "errors": [],
            }
        ),
        encoding="utf-8",
    )
    (tmp_path / "raw_records.jsonl").write_text(
        json.dumps({"parse_status": "parsed"}) + "\n" + json.dumps({"parse_status": "invalid"}) + "\n",
        encoding="utf-8",
    )
    (tmp_path / "observations.jsonl").write_text(
        json.dumps({"status": "candidate"}) + "\n" + json.dumps({"status": "quarantined"}) + "\n",
        encoding="utf-8",
    )

    source, summary = load_summary(tmp_path)

    assert source.endpoint_type == "html"
    assert source.endpoint_url == "https://example.test/estudios"
    assert summary.status == "succeeded"
    assert artifact_counts(tmp_path) == {
        "raw_records": 2,
        "parsed_raw_records": 1,
        "observations": 2,
        "quarantined_observations": 1,
    }


def test_dry_run_validation_rejects_tampered_payload_without_database(tmp_path: Path):
    payload = {"name": "original"}
    original_hash = hashlib.sha256(
        json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()
    (tmp_path / "raw_records.jsonl").write_text(
        json.dumps({
            "source_key": "fixture", "record_hash": original_hash,
            "parse_status": "parsed", "record_type": "fixture",
            "payload": {"name": "altered"},
        }) + "\n",
        encoding="utf-8",
    )
    (tmp_path / "observations.jsonl").write_text("", encoding="utf-8")
    summary = RunSummary(
        source_key="fixture", run_id="run-id", status="succeeded",
        records_received=1, records_valid=1, records_rejected=0,
        records_published=0, previous_success_count=None,
        deviation_percentage=None, artifact_directory=str(tmp_path),
    )

    with pytest.raises(ValueError, match="hash does not match"):
        validated_artifact_counts(SourceSpec("fixture", "Fixture", "manual"), summary)


def test_dry_run_validation_counts_valid_artifact(tmp_path: Path):
    payload = {"name": "original"}
    record_hash = hashlib.sha256(
        json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()
    (tmp_path / "raw_records.jsonl").write_text(
        json.dumps({
            "source_key": "fixture", "record_hash": record_hash,
            "parse_status": "parsed", "record_type": "fixture", "payload": payload,
        }) + "\n",
        encoding="utf-8",
    )
    (tmp_path / "observations.jsonl").write_text("", encoding="utf-8")
    summary = RunSummary(
        source_key="fixture", run_id="run-id", status="succeeded",
        records_received=1, records_valid=1, records_rejected=0,
        records_published=0, previous_success_count=None,
        deviation_percentage=None, artifact_directory=str(tmp_path),
    )

    assert validated_artifact_counts(SourceSpec("fixture", "Fixture", "manual"), summary) == {
        "raw_records": 1,
        "parsed_raw_records": 1,
        "observations": 0,
        "quarantined_observations": 0,
    }
