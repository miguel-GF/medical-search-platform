import hashlib
import json
from pathlib import Path

from database.scripts.render_generic_review_queue import render_queue


def _artifact(tmp_path: Path) -> Path:
    artifact = tmp_path / "artifact"
    artifact.mkdir()
    payload = {
        "provider_display_name": "Resonancia",
        "product_url": "https://example.test/servicios",
        "prices": {},
    }
    digest = hashlib.sha256(json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    row = {
        "source_key": "semin_catalog_puebla",
        "record_type": "provider_offer_discovered",
        "external_record_id": "catalog:1",
        "source_url": "https://example.test/servicios",
        "record_hash": digest,
        "parse_status": "parsed",
        "payload": payload,
    }
    (artifact / "raw_records.jsonl").write_text(json.dumps(row) + "\n", encoding="utf-8")
    (artifact / "observations.jsonl").write_text("\n", encoding="utf-8")
    (artifact / "run_manifest.json").write_text(
        json.dumps(
            {
                "source_key": "semin_catalog_puebla",
                "source_name": "SEMIN",
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


def test_review_queue_is_no_match_only_and_supports_new_source_override(tmp_path: Path):
    sql, counts = render_queue(
        {"semin_catalog_puebla": _artifact(tmp_path)},
        {"providers": [], "mappings": []},
        include_unclassified_sources={"semin_catalog_puebla"},
        brand_overrides={"semin_catalog_puebla": "laboratorios_semin"},
    )
    assert counts == {"artifacts": 1, "queued": 1, "skipped_approved": 0, "skipped_noise": 0}
    assert "'no_match'" in sql
    assert "insert into ingest.normalization_candidates" not in sql
    assert "supply.offers" not in sql
