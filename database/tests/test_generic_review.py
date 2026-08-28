import pytest

from database.scripts.build_generic_review import build_report


def _record(source_key: str, external_id: str, label: str, *, record_type: str = "provider_offer_discovered") -> dict:
    return {
        "source_key": source_key,
        "external_record_id": external_id,
        "record_type": record_type,
        "payload": {
            "provider_display_name": label,
            "evidence_method": "heading_pattern",
            "evidence_page_url": "https://example.test/studies",
        },
    }


def _mapping_fixture() -> dict:
    return {"mappings": [{"source_key": "generic_test", "external_record_id": "approved"}]}


def _review_fixture(*decisions: dict) -> dict:
    return {"version": "generic-provider-review-puebla-v1", "decisions": list(decisions)}


def _decision(label: str, classification: str = "reject_noise") -> dict:
    return {
        "source_key": "generic_test",
        "label_key": label,
        "classification": classification,
        "review_status": "pending",
        "publish": False,
        "action": "do_not_publish",
        "reason": "test decision",
    }


def test_review_requires_and_classifies_every_unmapped_offer():
    report = build_report(
        [
            _record("generic_test", "approved", "Approved exact"),
            _record("generic_test", "pending-1", "Laboratorio"),
            _record("generic_test", "pending-2", "Laboratorio"),
            _record("generic_test", "location", "Ignored", record_type="provider_location_discovered"),
        ],
        _mapping_fixture(),
        _review_fixture({**_decision("laboratorio"), "expected_record_count": 2}),
        expected_discovered_offers=3,
    )

    assert report["discovered_offers"] == 3
    assert report["approved_mapping_records"] == 1
    assert report["unmapped_offer_records"] == 2
    assert report["classified_offer_records"] == 2
    assert report["unclassified_offer_records"] == 0
    assert report["decision_counts"] == {"reject_noise": 2}
    assert report["labels"][0]["record_count"] == 2


def test_review_fails_closed_for_an_unclassified_offer():
    with pytest.raises(ValueError, match="unclassified generic offers"):
        build_report(
            [_record("generic_test", "pending-1", "Nueva prueba")],
            {"mappings": []},
            _review_fixture(),
        )


def test_review_rejects_publishable_decisions():
    decision = _decision("laboratorio")
    decision["publish"] = True
    with pytest.raises(ValueError, match="cannot publish"):
        build_report(
            [_record("generic_test", "pending-1", "Laboratorio")],
            {"mappings": []},
            _review_fixture(decision),
        )
