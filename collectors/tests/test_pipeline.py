import json
from pathlib import Path
import pytest

from pruevia_collectors.models import Observation, SourceRecord, SourceSpec
from pruevia_collectors import pipeline
from pruevia_collectors.pipeline import CollectorRunner, MAX_ARTIFACT_LINE_BYTES


class StaticCollector:
    def __init__(self, source: SourceSpec, records: list[SourceRecord]) -> None:
        self.source = source
        self.records = records

    def collect(self):
        return iter(self.records)


def record(source_key: str, external_id: str, value: str = "ok") -> SourceRecord:
    return SourceRecord(
        source_key=source_key,
        record_type="provider_location",
        external_record_id=external_id,
        payload={"external_id": external_id, "name": value},
        observations=(
            Observation(
                entity_type="provider_location",
                attribute_name="name",
                observed_value=value,
            ),
        ),
    )


def test_runner_writes_raw_records_observations_and_manifest(tmp_path: Path):
    source = SourceSpec("fixture", "Fixture", "manual", usage_policy_status="approved")
    summary = CollectorRunner(tmp_path).run(StaticCollector(source, [record("fixture", "1")]))

    assert summary.status == "succeeded"
    run_dir = Path(summary.artifact_directory)
    manifest = json.loads((run_dir / "run_manifest.json").read_text(encoding="utf-8"))
    raw = (run_dir / "raw_records.jsonl").read_text(encoding="utf-8").splitlines()
    observations = (run_dir / "observations.jsonl").read_text(encoding="utf-8").splitlines()
    assert manifest["records_valid"] == 1
    assert len(raw) == 1
    assert len(observations) == 1


def test_duplicate_records_are_rejected_and_not_observed(tmp_path: Path):
    source = SourceSpec("fixture", "Fixture", "manual")
    duplicate = record("fixture", "1")
    summary = CollectorRunner(tmp_path).run(StaticCollector(source, [duplicate, duplicate]))

    assert summary.status == "succeeded"
    assert summary.records_received == 2
    assert summary.records_valid == 1
    assert summary.records_rejected == 1
    assert "duplicate record hash" in summary.errors[0]


def test_volume_drop_quarantines_run_and_observations(tmp_path: Path):
    source = SourceSpec("fixture", "Fixture", "manual", max_negative_deviation_pct=50)
    summary = CollectorRunner(tmp_path).run(StaticCollector(source, [record("fixture", "1")]), previous_success_count=10)

    assert summary.status == "quarantined"
    assert summary.deviation_percentage == -90.0
    observations_path = Path(summary.artifact_directory) / "observations.jsonl"
    observation = json.loads(observations_path.read_text(encoding="utf-8").strip())
    assert observation["status"] == "quarantined"


def test_expected_minimum_quarantines_empty_result(tmp_path: Path):
    source = SourceSpec("fixture", "Fixture", "manual", expected_min_records=1)
    summary = CollectorRunner(tmp_path).run(StaticCollector(source, []))

    assert summary.status == "quarantined"
    assert summary.records_received == 0


def test_adapter_failure_after_partial_data_is_quarantined(tmp_path: Path):
    source = SourceSpec("fixture", "Fixture", "manual")

    class FailingCollector:
        def __init__(self):
            self.source = source

        def collect(self):
            yield record("fixture", "1")
            raise RuntimeError("upstream returned 503")

    summary = CollectorRunner(tmp_path).run(FailingCollector())
    assert summary.status == "quarantined"
    assert "collector failure" in summary.errors[0]


def test_runner_rejects_oversized_payloads_and_redacts_error_urls(tmp_path: Path):
    source = SourceSpec("fixture", "Fixture", "manual")
    oversized = SourceRecord(
        source_key="fixture",
        record_type="provider_location",
        payload={"description": "x" * (512 * 1024)},
    )

    class FailingCollector:
        def __init__(self):
            self.source = source

        def collect(self):
            yield oversized
            raise RuntimeError("upstream https://example.test/?token=do-not-persist")

    summary = CollectorRunner(tmp_path).run(FailingCollector())
    assert summary.records_rejected == 1
    assert any("safety limit" in error for error in summary.errors)
    assert all("do-not-persist" not in error for error in summary.errors)


def test_runner_rejects_oversized_observation_values(tmp_path: Path):
    source = SourceSpec("fixture", "Fixture", "manual")
    oversized = SourceRecord(
        source_key="fixture",
        record_type="provider_location",
        payload={"name": "ok"},
        observations=(
            Observation(
                entity_type="provider_location",
                attribute_name="notes",
                observed_value="x" * (512 * 1024),
            ),
        ),
    )
    summary = CollectorRunner(tmp_path).run(StaticCollector(source, [oversized]))

    assert summary.records_rejected == 1
    assert any("observation payload exceeds" in error for error in summary.errors)
    assert (Path(summary.artifact_directory) / "observations.jsonl").read_text(encoding="utf-8") == ""


def test_quarantine_reader_rejects_oversized_lines_before_buffering(tmp_path: Path):
    path = tmp_path / "observations.jsonl"
    path.write_bytes(b"x" * (MAX_ARTIFACT_LINE_BYTES + 1))

    try:
        CollectorRunner._mark_observations_quarantined(path)
    except ValueError as error:
        assert "exceeds the safety limit" in str(error)
    else:
        raise AssertionError("oversized quarantine line was accepted")


def test_runner_halts_before_artifact_disk_exhaustion(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(pipeline, "MAX_ARTIFACT_BYTES", 10)
    source = SourceSpec("fixture", "Fixture", "manual")

    summary = CollectorRunner(tmp_path).run(StaticCollector(source, [record("fixture", "1")]))

    assert summary.status == "failed"
    assert summary.records_valid == 0
    assert any("artifact exceeds safety limit" in error for error in summary.errors)


def test_runner_removes_signed_query_material_from_source_urls(tmp_path: Path):
    source = SourceSpec("fixture", "Fixture", "manual")
    unsafe = SourceRecord(
        source_key="fixture",
        record_type="provider_location",
        source_url="https://example.test/source?access_token=do-not-persist#fragment",
        payload={"name": "ok"},
    )
    summary = CollectorRunner(tmp_path).run(StaticCollector(source, [unsafe]))
    raw = json.loads((Path(summary.artifact_directory) / "raw_records.jsonl").read_text(encoding="utf-8"))
    assert raw["source_url"] == "https://example.test/source"
    assert "do-not-persist" not in json.dumps(raw)


def test_runner_removes_signed_query_material_from_endpoint_metadata(tmp_path: Path):
    source = SourceSpec(
        "fixture",
        "Fixture",
        "manual",
        endpoint_url="https://example.test/catalog?session=do-not-persist#fragment",
    )
    summary = CollectorRunner(tmp_path).run(StaticCollector(source, []))
    manifest = json.loads((Path(summary.artifact_directory) / "run_manifest.json").read_text(encoding="utf-8"))
    assert manifest["endpoint_url"] == "https://example.test/catalog"
    assert "do-not-persist" not in json.dumps(manifest)


def test_invalid_record_artifacts_redact_exception_urls(tmp_path: Path):
    source = SourceSpec("fixture", "Fixture", "manual")

    class InvalidRecord:
        source_key = "fixture"
        record_type = "provider_location"
        payload = {"name": "ok"}

        @property
        def observations(self):
            raise ValueError("parser rejected https://example.test/?access_token=do-not-persist")

    summary = CollectorRunner(tmp_path).run(StaticCollector(source, [InvalidRecord()]))
    raw = json.loads((Path(summary.artifact_directory) / "raw_records.jsonl").read_text(encoding="utf-8"))
    assert raw["parse_status"] == "invalid"
    assert "do-not-persist" not in json.dumps(raw)
    assert "[REDACTED]" in raw["error_detail"]


def test_invalid_record_artifacts_redact_unrecognized_query_material(tmp_path: Path):
    source = SourceSpec("fixture", "Fixture", "manual")

    class InvalidRecord:
        source_key = "fixture"
        record_type = "provider_location"
        payload = {"name": "ok"}

        @property
        def observations(self):
            raise ValueError("parser rejected https://example.test/?session=private-value")

    summary = CollectorRunner(tmp_path).run(StaticCollector(source, [InvalidRecord()]))
    raw = json.loads((Path(summary.artifact_directory) / "raw_records.jsonl").read_text(encoding="utf-8"))
    assert "private-value" not in json.dumps(raw)
    assert "[REDACTED]" in raw["error_detail"]


def test_runner_bounds_reported_error_count(tmp_path: Path):
    source = SourceSpec("fixture", "Fixture", "manual")

    class NoisyCollector:
        def __init__(self):
            self.source = source
            self.errors = [f"error-{index}" for index in range(500)]

        def collect(self):
            return iter(())

    summary = CollectorRunner(tmp_path).run(NoisyCollector())
    assert len(summary.errors) == 101
    assert summary.errors[-1] == "additional errors omitted"


def test_last_success_uses_manifest_time_not_uuid_order(tmp_path: Path):
    source = SourceSpec("fixture", "Fixture", "manual")
    store = CollectorRunner(tmp_path).store
    for run_id, finished_at, count in (
        ("ffffffff-ffff-4fff-8fff-ffffffffffff", "2026-01-01T00:00:00Z", 10),
        ("00000000-0000-4000-8000-000000000000", "2026-01-02T00:00:00Z", 20),
    ):
        run_dir = store.source_root(source.source_key) / run_id
        run_dir.mkdir(parents=True)
        (run_dir / "run_manifest.json").write_text(
            json.dumps({"status": "succeeded", "records_received": count, "finished_at": finished_at}),
            encoding="utf-8",
        )
    assert store.last_success_count(source.source_key) == 20
