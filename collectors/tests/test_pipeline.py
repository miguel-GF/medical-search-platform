import json
from pathlib import Path

from pruevia_collectors.models import Observation, SourceRecord, SourceSpec
from pruevia_collectors.pipeline import CollectorRunner


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
