import json
from pathlib import Path

import pytest

from database.scripts.render_ingest_artifact import render, render_chunks


def _write_artifact(root: Path, *, duplicate: bool = False) -> Path:
    artifact = root / "salud-digna-puebla" / "run"
    artifact.mkdir(parents=True)
    payload = {
        "provider_display_name": "Glucosa",
        "provider_external_id": "332:17",
        "prices": {"regular": 11999},
    }
    import hashlib

    record_hash = hashlib.sha256(json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    raw = {
        "source_key": "salud_digna_puebla",
        "record_type": "provider_offer_price",
        "external_record_id": "332:17",
        "record_hash": record_hash,
        "observed_at": "2026-08-27T08:00:00Z",
        "parse_status": "parsed",
        "payload": payload,
    }
    rows = [raw, raw] if duplicate else [raw]
    manifest = {
        "source_key": "salud_digna_puebla",
        "source_name": "Salud Digna — Puebla",
        "source_type": "provider_official",
        "usage_policy_status": "review_required",
        "endpoint_type": "api",
        "endpoint_url": "https://api.emarketingsd.org/Citas/Citas2/SubEstudiosPorSucursalPP",
        "parser_version": "0.1.0",
        "run_id": "8e9ce94b-f270-46ce-b0eb-138e9c59d296",
        "status": "succeeded",
        "records_received": len(rows),
        "records_valid": len(rows),
        "records_rejected": 0,
        "finished_at": "2026-08-27T08:00:00Z",
        "errors": [],
    }
    observations = [
        {
            "source_key": "salud_digna_puebla",
            "record_hash": record_hash,
            "entity_type": "price",
            "attribute_name": "prices",
            "observed_value": {"regular": 11999},
            "confidence": 1.0,
            "status": "candidate",
            "observed_at": "2026-08-27T08:00:00Z",
        }
    ]
    (artifact / "run_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    (artifact / "raw_records.jsonl").write_text("\n".join(json.dumps(row) for row in rows) + "\n", encoding="utf-8")
    (artifact / "observations.jsonl").write_text(json.dumps(observations[0]) + "\n", encoding="utf-8")
    return artifact


def test_render_ingest_artifact_is_idempotent_and_evidence_only(tmp_path):
    sql = render(_write_artifact(tmp_path))

    assert "insert into ingest.sources" in sql
    assert "insert into ingest.raw_records" in sql
    assert "insert into ingest.source_observations" in sql
    assert "drop " not in sql.lower()
    assert "delete " not in sql.lower()
    assert sql.count("insert into ingest.raw_records") == 1
    assert sql.endswith("commit;\n")


def test_render_ingest_artifact_rejects_duplicate_hashes(tmp_path):
    with pytest.raises(ValueError, match="duplicate record hashes"):
        render(_write_artifact(tmp_path, duplicate=True))


def test_render_ingest_artifact_chunks_are_transactions(tmp_path):
    chunks = render_chunks(_write_artifact(tmp_path), 1024)

    assert len(chunks) >= 2
    assert all(chunk.startswith("begin;\n") and chunk.endswith("commit;\n") for chunk in chunks)
    assert all(len(chunk.encode("utf-8")) <= 1024 for chunk in chunks)
