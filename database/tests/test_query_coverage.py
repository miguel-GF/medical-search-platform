import json
from pathlib import Path

import pytest

from database.scripts.report_query_coverage import read_fixture, summarize_results


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
