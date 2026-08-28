import json
from pathlib import Path

from database.scripts.match_denue_locations import match


def _provider_artifact(root: Path) -> Path:
    artifact = root / "ruiz"
    artifact.mkdir()
    payload = {
        "provider_display_name": "La Paz",
        "provider_external_id": "8",
        "location_url": "https://example.test/ruiz/la-paz",
        "postal_code": "72160",
        "address_line_1": "Av. Juarez 3116",
        "coordinates": {"latitude": 19.0545602, "longitude": -98.2236907},
    }
    row = {
        "source_key": "ruiz_puebla",
        "record_type": "provider_location_discovered",
        "external_record_id": "8",
        "source_url": payload["location_url"],
        "record_hash": "a" * 64,
        "parse_status": "parsed",
        "payload": payload,
    }
    (artifact / "raw_records.jsonl").write_text(json.dumps(row) + "\n", encoding="utf-8")
    (artifact / "run_manifest.json").write_text(
        json.dumps({"status": "succeeded", "errors": [], "run_id": "00000000-0000-0000-0000-000000000888"}),
        encoding="utf-8",
    )
    return artifact


def _candidate_fixture(root: Path) -> Path:
    fixture = root / "candidates.json"
    fixture.write_text(
        json.dumps(
            {
                "source_run_id": "00000000-0000-0000-0000-000000000777",
                "candidates": [
                    {
                        "external_record_id": "denue-1",
                        "record_hash": "b" * 64,
                        "source_record_ids": ["denue-1"],
                        "source_url": "https://example.test/denue-1",
                        "name": "Laboratorio Ruiz La Paz",
                        "legal_name": "Laboratorio Médico Polanco",
                        "postal_code": "72160",
                        "coordinates": {"latitude": 19.05442648, "longitude": -98.22356391},
                        "brand_match": {"brand_key": "ruiz", "status": "matched", "confidence": 0.99},
                    },
                    {
                        "external_record_id": "denue-2",
                        "record_hash": "c" * 64,
                        "source_url": "https://example.test/denue-2",
                        "name": "L.R. La Paz",
                        "legal_name": "Laboratorio Médico Polanco",
                        "postal_code": "72160",
                        "coordinates": {"latitude": 19.05442648, "longitude": -98.22356391},
                        "brand_match": {"brand_key": "ruiz", "status": "review_required", "confidence": 0.55},
                    },
                    {
                        "external_record_id": "denue-3",
                        "record_hash": "d" * 64,
                        "source_url": "https://example.test/denue-3",
                        "name": "Laboratorio Independiente",
                        "legal_name": "Independiente",
                        "postal_code": "72000",
                        "coordinates": {"latitude": 19.0437, "longitude": -98.1982},
                    },
                ],
            }
        ),
        encoding="utf-8",
    )
    return fixture


def test_matching_requires_explicit_brand_and_nearby_location(tmp_path: Path):
    result = match(_candidate_fixture(tmp_path), {"ruiz": _provider_artifact(tmp_path)})

    assert result["summary"] == {
        "denue_candidates": 3,
        "matched": 1,
        "review_required": 1,
        "nearby_review_leads": 1,
        "unmatched": 1,
    }
    assert result["matches"][0]["provider_location"]["external_record_id"] == "8"
    assert result["matches"][0]["comparison"]["distance_meters"] < 25
    assert result["review_queue"][0]["brand_match"]["status"] == "review_required"
    assert result["unmatched"][0]["reason"].startswith("No known provider brand")
