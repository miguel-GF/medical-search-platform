import hashlib
import json
from pathlib import Path

import pytest

from database.scripts.render_generic_provider_mappings import render


def _hash(payload: object) -> str:
    return hashlib.sha256(
        json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"), default=str).encode("utf-8")
    ).hexdigest()


def _artifact(root: Path, source_key: str = "generic_familylabs_com_mx") -> Path:
    path = root / source_key
    path.mkdir()
    payload = {
        "provider_display_name": "Ultrasonido Abdomen Completo",
        "provider_external_id": "offer-1",
        "provider_sku": None,
        "product_url": "https://familylabs.com.mx/",
        "prices": {},
    }
    record_hash = _hash(payload)
    raw = {
        "source_key": source_key,
        "record_type": "provider_offer_discovered",
        "external_record_id": "offer-1",
        "source_url": payload["product_url"],
        "record_hash": record_hash,
        "parse_status": "parsed",
        "payload": payload,
    }
    observation = {
        "source_key": source_key,
        "record_hash": record_hash,
        "entity_type": "offer",
        "attribute_name": "provider_display_name",
        "observed_value": payload["provider_display_name"],
        "status": "candidate",
    }
    (path / "raw_records.jsonl").write_text(json.dumps(raw, ensure_ascii=False) + "\n", encoding="utf-8")
    (path / "observations.jsonl").write_text(json.dumps(observation, ensure_ascii=False) + "\n", encoding="utf-8")
    (path / "run_manifest.json").write_text(
        json.dumps(
            {
                "source_key": source_key,
                "source_name": "Generic Family Labs",
                "source_type": "public_website",
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


def _fixture() -> dict:
    return {
        "version": "test-generic-mappings-v1",
        "providers": [
            {
                "source_key": "generic_familylabs_com_mx",
                "provider_key": "familylabs",
                "brand_name": "Family Labs",
                "slug": "family-labs",
                "website_url": "https://familylabs.com.mx/",
                "denue_record_ids": ["1"],
            }
        ],
        "mappings": [
            {
                "source_key": "generic_familylabs_com_mx",
                "provider_key": "familylabs",
                "external_record_id": "offer-1",
                "catalog_item_id": "a1f81444-4b20-5d82-bdf6-b48c27245fa0",
                "provider_alias": "Ultrasonido Abdomen Completo",
                "observed_label": "Ultrasonido Abdomen Completo",
                "method": "manual",
                "reason": "Reviewed exact label",
            }
        ],
    }


def _denue() -> dict:
    return {
        "source_run_id": "00000000-0000-0000-0000-000000000002",
        "candidates": [
            {
                "external_record_id": "1",
                "record_hash": "a" * 64,
                "name": "FAMILY LABS",
                "website_url": "WWW.FAMILYLABS.COM.MX",
                "classification": "direct_clinical",
                "postal_code": "72000",
                "phone": "2220000000",
                "address": {"street": "CALLE 1", "exterior_number": "2", "neighborhood": "CENTRO", "state": "Puebla"},
                "coordinates": {"latitude": 19.0437, "longitude": -98.1982},
            }
        ],
    }


def test_renderer_emits_identity_locations_and_reviewed_offer(tmp_path: Path):
    sql = render(_fixture(), {"generic_familylabs_com_mx": _artifact(tmp_path)}, _denue())

    assert "verification_pending" in sql
    assert "denue:1" in sql
    assert "gis.ST_MakePoint(-98.1982, 19.0437)" in sql
    assert "Ultrasonido Abdomen Completo" in sql
    assert "'requires_quote'" not in sql  # rendered as a column, not a literal
    assert '"denue_record_id":"1"' in sql
    assert "''denue_record_id''" not in sql
    assert sql.startswith("begin;\n") and sql.endswith("commit;\n")


def test_renderer_rejects_non_exact_provider_label(tmp_path: Path):
    fixture = _fixture()
    fixture["mappings"][0]["provider_alias"] = "Ultrasonido"
    with pytest.raises(ValueError, match="provider_alias differs"):
        render(fixture, {"generic_familylabs_com_mx": _artifact(tmp_path)}, _denue())


def test_renderer_rejects_denue_domain_mismatch(tmp_path: Path):
    denue = _denue()
    denue["candidates"][0]["website_url"] = "WWW.OTHER-LAB.COM"
    with pytest.raises(ValueError, match="website does not match"):
        render(_fixture(), {"generic_familylabs_com_mx": _artifact(tmp_path)}, denue)
