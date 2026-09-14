import json
from pathlib import Path

import pytest

from database.scripts import report_query_coverage
from database.scripts.report_query_coverage import _validate_origin, read_fixture, summarize_results


ROOT = Path(__file__).parents[1]


def test_query_fixture_is_bounded_and_anonymized():
    records = read_fixture(ROOT / "fixtures" / "public_query_research_v1.json")
    assert len(records) == 64
    assert all(set(row) == {"id", "query", "expected_action"} for row in records)
    assert max(len(row["query"]) for row in records) <= 120


def test_summary_keeps_strict_resolution_separate_from_expected_preparation():
    report = summarize_results([
        {"id": "strict", "expected_action": "resolve", "actual_status": "resolved"},
        {"id": "prep", "expected_action": "resolve_plus_preparation", "actual_status": "no_match"},
        {"id": "gap", "expected_action": "catalog_gap", "actual_status": "resolved"},
    ])
    assert report["strict_resolve"] == {"total": 1, "resolved": 1, "not_resolved": 0}
    assert report["resolution_expected"] == {"total": 2, "resolved": 1, "not_resolved": 1}
    assert report["unexpected_resolved_count"] == 1
    assert report["unexpected_resolved_ids"] == ["gap"]
    assert report["unresolved_expected_ids"] == ["prep"]


def test_fixture_rejects_personal_data_fields(tmp_path):
    fixture = {
        "version": "public-query-research-v1",
        "author": "should not be retained",
        "records": [{"id": "one", "query": "BH", "expected_action": "resolve"}],
    }
    path = tmp_path / "fixture.json"
    path.write_text(json.dumps(fixture), encoding="utf-8")
    with pytest.raises(ValueError, match="forbidden"):
        read_fixture(path)


def test_fixture_rejects_personal_data_fields_inside_records(tmp_path):
    fixture = {
        "version": "public-query-research-v1",
        "records": [{"id": "one", "query": "BH", "expected_action": "resolve", "email": "not-retained"}],
    }
    path = tmp_path / "fixture.json"
    path.write_text(json.dumps(fixture), encoding="utf-8")
    with pytest.raises(ValueError, match="forbidden"):
        read_fixture(path)


@pytest.mark.parametrize("value", [
    "http://evil.example/path",
    "https://user:pass@example.com",
    "https://example.com/?tracking=1",
    "http://example.com",
])
def test_http_measurement_rejects_unsafe_origins(value):
    with pytest.raises(ValueError):
        _validate_origin(value)


def test_http_measurement_allows_loopback_origin():
    assert _validate_origin("http://127.0.0.1:8787/") == "http://127.0.0.1:8787"
    assert _validate_origin("https://example.com:443/") == "https://example.com:443"


def test_http_measurement_sends_utf8_and_summarizes_without_query_text(monkeypatch):
    class Response:
        status = 200

        def __enter__(self):
            return self

        def __exit__(self, *_):
            return False

        def read(self, _limit):
            return json.dumps({
                "package_status": "ready",
                "coverage_status": "complete",
                "items": [{"status": "resolved", "candidates": []}],
            }).encode("utf-8")

    captured = []

    def fake_urlopen(request, timeout):
        captured.append((request, timeout))
        return Response()

    monkeypatch.setattr(report_query_coverage, "urlopen", fake_urlopen)
    summary, rows = report_query_coverage.measure_http(
        "http://127.0.0.1:8787",
        [{"id": "one", "query": "Biometría", "expected_action": "resolve"}],
        origin="http://localhost:5173",
    )
    assert summary["strict_resolve"] == {"total": 1, "resolved": 1, "not_resolved": 0}
    assert rows[0]["actual_status"] == "resolved"
    request, timeout = captured[0]
    assert timeout == 15
    assert json.loads(request.data.decode("utf-8")) == {"text": "Biometría"}
    assert request.headers["Origin"] == "http://localhost:5173"
