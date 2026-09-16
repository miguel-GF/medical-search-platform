import hashlib
import json
from pathlib import Path

from database.scripts.render_official_provider_locations import render


def _fixture() -> dict:
    return {
        "version": "official-provider-locations-v1",
        "provider": {
            "provider_key": "salud_digna",
            "name": "Salud Digna",
            "slug": "salud-digna",
            "website_url": "https://www.salud-digna.org",
        },
        "locations": [
            {
                "external_id": "332",
                "slug": "puebla-municipio-libre",
                "name": "Puebla Municipio Libre",
                "address_line_1": "Blvd. Municipio Libre #547, Puebla",
                "postal_code": "72474",
                "phone": "222 232 4709",
                "coordinates": {"latitude": 19.0, "longitude": -98.2},
                "location_code": "332",
                "url": "https://www.salud-digna.org/puebla-municipio-libre",
            }
        ],
    }


def _artifact(tmp_path: Path) -> Path:
    artifact = tmp_path / "artifact"
    artifact.mkdir()
    payload = {
        "provider_display_name": "Puebla Municipio Libre",
        "location_url": "https://www.salud-digna.org/puebla-municipio-libre",
        "coordinates": {"latitude": 19.0, "longitude": -98.2},
    }
    digest = hashlib.sha256(
        json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    row = {
        "source_key": "salud_digna_puebla",
        "record_type": "provider_location_discovered",
        "external_record_id": "332",
        "source_url": payload["location_url"],
        "record_hash": digest,
        "parse_status": "parsed",
        "payload": payload,
    }
    (artifact / "raw_records.jsonl").write_text(json.dumps(row) + "\n", encoding="utf-8")
    (artifact / "observations.jsonl").write_text("\n", encoding="utf-8")
    (artifact / "run_manifest.json").write_text(
        json.dumps(
            {
                "source_key": "salud_digna_puebla",
                "source_name": "Salud Digna",
                "source_type": "provider_official",
                "status": "succeeded",
                "errors": [],
                "records_received": 1,
                "records_valid": 1,
                "records_rejected": 0,
                "run_id": "00000000-0000-0000-0000-000000000001",
            }
        ),
        encoding="utf-8",
    )
    return artifact


def test_official_location_renderer_is_location_only(tmp_path: Path):
    sql = render(_fixture(), _artifact(tmp_path))
    assert "core.provider_locations" in sql
    assert "core.provider_market_locations" in sql
    assert "supply.offers" not in sql
    assert "price_versions" not in sql
    assert "official_provider_locations" not in sql


def test_official_location_renderer_accepts_an_explicit_source_key(tmp_path: Path):
    fixture = _fixture()
    fixture["source_key"] = "dr_simi_puebla"
    fixture["source_system"] = "dr_simi_official"
    artifact = _artifact(tmp_path)
    manifest = json.loads((artifact / "run_manifest.json").read_text(encoding="utf-8"))
    manifest["source_key"] = "dr_simi_puebla"
    (artifact / "run_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    raw = json.loads((artifact / "raw_records.jsonl").read_text(encoding="utf-8"))
    raw["source_key"] = "dr_simi_puebla"
    (artifact / "raw_records.jsonl").write_text(json.dumps(raw) + "\n", encoding="utf-8")
    sql = render(fixture, artifact)
    assert "dr_simi_official" in sql


def test_official_location_renderer_accepts_location_source_key_alias(tmp_path: Path):
    artifact = _artifact(tmp_path)
    manifest_path = artifact / "run_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["source_key"] = "salud_digna_puebla_locations"
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    raw_path = artifact / "raw_records.jsonl"
    raw = json.loads(raw_path.read_text(encoding="utf-8"))
    raw["source_key"] = "salud_digna_puebla_locations"
    raw_path.write_text(json.dumps(raw) + "\n", encoding="utf-8")
    observations_path = artifact / "observations.jsonl"
    observation = {
        "source_key": "salud_digna_puebla_locations",
        "record_hash": raw["record_hash"],
        "entity_type": "provider_location",
        "attribute_name": "location",
        "observed_value": raw["payload"],
        "status": "candidate",
    }
    observations_path.write_text(json.dumps(observation) + "\n", encoding="utf-8")

    sql = render(_fixture(), artifact)

    assert "core.provider_locations" in sql
