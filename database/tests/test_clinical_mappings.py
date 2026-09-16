import hashlib
import json
from pathlib import Path

import pytest

from database.scripts.render_clinical_mappings import render


def _hash(payload: object) -> str:
    return hashlib.sha256(
        json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"), default=str).encode("utf-8")
    ).hexdigest()


def _artifact(root: Path, *, label: str = "GLUCOSA") -> Path:
    path = root / "chopo_puebla"
    path.mkdir()
    payload = {
        "provider_display_name": label,
        "provider_sku": "sku-1",
        "product_url": "https://www.chopo.com.mx/puebla/glucosa",
        "prices": {"regular": 12345},
    }
    record_hash = _hash(payload)
    raw = {
        "source_key": "chopo_puebla",
        "record_type": "provider_offer_price",
        "external_record_id": "sku-1",
        "source_url": payload["product_url"],
        "record_hash": record_hash,
        "parse_status": "parsed",
        "payload": payload,
    }
    observation = {
        "source_key": "chopo_puebla",
        "record_hash": record_hash,
        "entity_type": "price",
        "attribute_name": "prices",
        "observed_value": payload["prices"],
        "status": "candidate",
    }
    (path / "raw_records.jsonl").write_text(json.dumps(raw, ensure_ascii=False) + "\n", encoding="utf-8")
    (path / "observations.jsonl").write_text(json.dumps(observation, ensure_ascii=False) + "\n", encoding="utf-8")
    (path / "run_manifest.json").write_text(
        json.dumps(
            {
                "source_key": "chopo_puebla",
                "source_name": "Laboratorio Médico del Chopo — Puebla",
                "source_type": "provider_official",
                "status": "succeeded",
                "errors": [],
                "records_received": 1,
                "records_valid": 1,
                "records_rejected": 0,
                "run_id": "00000000-0000-0000-0000-000000000001",
            },
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )
    return path


def _fixture(label: str = "GLUCOSA") -> dict:
    return {
        "version": "test-mappings-v1",
        "mappings": [
            {
                "source_key": "chopo_puebla",
                "provider_key": "chopo",
                "external_record_id": "sku-1",
                "catalog_item_id": "00000000-0000-0000-0000-000000001109",
                "provider_alias": label,
                "method": "manual",
                "reason": "Reviewed exact test mapping",
            }
        ],
    }


def _salud_digna_artifact(root: Path) -> Path:
    path = root / "salud_digna_puebla"
    path.mkdir()
    payload = {
        "provider_display_name": "BIOMETRIA HEMATICA",
        "provider_external_id": "888346",
        "location_external_id": "332",
        "product_url": "https://www.salud-digna.org/puebla-municipio-libre",
        "prices": {"regular": 18479},
    }
    record_hash = _hash(payload)
    raw = {
        "source_key": "salud_digna_puebla",
        "record_type": "provider_offer_price",
        "external_record_id": "332:888346",
        "source_url": payload["product_url"],
        "record_hash": record_hash,
        "parse_status": "parsed",
        "payload": payload,
    }
    observation = {
        "source_key": "salud_digna_puebla",
        "record_hash": record_hash,
        "entity_type": "price",
        "attribute_name": "prices",
        "observed_value": payload["prices"],
        "status": "candidate",
    }
    (path / "raw_records.jsonl").write_text(json.dumps(raw) + "\n", encoding="utf-8")
    (path / "observations.jsonl").write_text(json.dumps(observation) + "\n", encoding="utf-8")
    (path / "run_manifest.json").write_text(
        json.dumps({
            "source_key": "salud_digna_puebla",
            "status": "succeeded",
            "errors": [],
            "records_received": 1,
            "records_valid": 1,
            "records_rejected": 0,
            "run_id": "00000000-0000-0000-0000-000000000002",
        }),
        encoding="utf-8",
    )
    return path


def test_clinical_mapping_renderer_emits_offer_price_and_decision(tmp_path: Path):
    artifact = _artifact(tmp_path)
    sql = render(_fixture(), {"chopo_puebla": artifact})

    assert "00000000-0000-0000-0000-000000001109" in sql
    assert "12345" in sql
    assert "test-mappings-v1" in sql
    assert "'manual'" in sql
    assert sql.startswith("begin;\n") and sql.endswith("commit;\n")


def test_clinical_mapping_renderer_rejects_changed_observed_label(tmp_path: Path):
    artifact = _artifact(tmp_path, label="GLUCOSA ALTERADA")
    with pytest.raises(ValueError, match="mapping label changed"):
        render(_fixture(), {"chopo_puebla": artifact})


def test_salud_digna_offer_scope_resolves_existing_location_by_code(tmp_path: Path):
    artifact = _salud_digna_artifact(tmp_path)
    fixture = {
        "version": "test-mappings-v1",
        "mappings": [{
            "source_key": "salud_digna_puebla",
            "provider_key": "salud_digna",
            "external_record_id": "332:888346",
            "catalog_item_id": "00000000-0000-0000-0000-000000001103",
            "provider_alias": "BIOMETRIA HEMATICA",
            "observed_label": "BIOMETRIA HEMATICA",
            "method": "manual",
            "reason": "Reviewed exact test mapping",
        }],
    }

    sql = render(fixture, {"salud_digna_puebla": artifact})

    assert "scope_type='location'" in sql
    assert "pl.location_code='332'" in sql
    assert "Missing canonical provider location" in sql
    assert "link_target,link_capability" in sql
    assert "clinical:00000000-0000-0000-0000-000000001103" in sql
    assert "status='inactive',is_primary=false" in sql
