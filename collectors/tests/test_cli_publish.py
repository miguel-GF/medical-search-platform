import json
from pathlib import Path

from pruevia_collectors.cli_publish import artifact_counts, load_summary


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
