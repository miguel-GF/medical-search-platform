import hashlib
import json
from pathlib import Path

import pytest

from database.scripts.loinc_review import build_report, load_queue


FIXTURE = Path(__file__).parents[1] / "fixtures" / "loinc_review_queue_v1.json"


def _write_index(tmp_path: Path) -> Path:
    index = tmp_path / "loinc_lab_active.jsonl"
    index.write_text(
        json.dumps(
            {
                "LOINC_NUM": "2345-7",
                "LONG_COMMON_NAME": "Glucose [Mass/volume] in Serum or Plasma",
                "SHORTNAME": "Glucose M mass/vol Ser/Plas",
                "CONSUMER_NAME": "Glucose",
                "COMPONENT": "Glucose",
                "PROPERTY": "Mass concentration",
                "TIME_ASPCT": "Point in time",
                "SYSTEM": "Ser/Plas",
                "SCALE_TYP": "Quantitative",
                "METHOD_TYP": "",
                "CLASS": "LAB",
                "STATUS": "ACTIVE",
                "ORDER_OBS": "Both",
            }
        )
        + "\n",
        encoding="utf-8",
    )
    manifest = index.with_suffix(index.suffix + ".manifest.json")
    manifest.write_text(
        json.dumps(
            {
                "loinc_version": "2.83",
                "index_sha256": hashlib.sha256(index.read_bytes()).hexdigest(),
            }
        ),
        encoding="utf-8",
    )
    return index


def test_review_queue_fixture_has_seven_canonical_items():
    queue = load_queue(FIXTURE)

    assert queue["queue_version"] == "loinc-review-queue-v1"
    assert len(queue["items"]) == 7
    assert queue["items"][0]["canonical_name"] == "Biometría hemática"


def test_build_report_is_version_bound_and_never_publishable(tmp_path: Path):
    index = _write_index(tmp_path)
    queue = {
        "queue_version": "test-queue",
        "items": [
            {
                "item_id": "00000000-0000-0000-0000-000000001109",
                "canonical_name": "Glucosa",
                "queries": ["glucose serum"],
            }
        ],
    }

    report = build_report(queue, index, limit=3)

    assert report["loinc_version"] == "2.83"
    assert report["publication_allowed"] is False
    assert report["items"][0]["review_status"] == "pending"
    candidate = report["items"][0]["queries"][0]["candidates"][0]
    assert candidate["loinc_code"] == "2345-7"
    assert candidate["requires_manual_review"] is True


def test_review_queue_rejects_duplicate_queries(tmp_path: Path):
    queue = {
        "queue_version": "test-queue",
        "items": [
            {
                "item_id": "00000000-0000-0000-0000-000000001109",
                "canonical_name": "Glucosa",
                "queries": ["glucose", " GLUCOSE "],
            }
        ],
    }
    path = tmp_path / "invalid_loinc_queue.json"
    path.write_text(json.dumps(queue), encoding="utf-8")
    with pytest.raises(ValueError, match="duplicate query"):
        load_queue(path)


def test_report_rejects_modified_index(tmp_path: Path):
    index = _write_index(tmp_path)
    index.write_text(index.read_text(encoding="utf-8") + "\n", encoding="utf-8")
    queue = {
        "queue_version": "test-queue",
        "items": [
            {
                "item_id": "00000000-0000-0000-0000-000000001109",
                "canonical_name": "Glucosa",
                "queries": ["glucose"],
            }
        ],
    }

    with pytest.raises(ValueError, match="SHA-256"):
        build_report(queue, index)
