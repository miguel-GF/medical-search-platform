import hashlib
import json

import pytest

from database.scripts.publish_denue_bulk_linked import ARCHIVE_URL, LICENSE_URL, build_batches


def artifact(tmp_path, *, entity_type="provider_location", state="21", source_type="government"):
    payload = {"id": "123", "nom_estab": "Clínica pequeña", "codigo_act": "621511", "cve_ent": state,
               "_source_archive": {"url": ARCHIVE_URL, "license_url": LICENSE_URL, "sha256": "a" * 64}}
    digest = hashlib.sha256(json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    manifest = {"source_key": "denue_puebla_bulk", "source_name": "DENUE Puebla", "source_type": source_type,
                "usage_policy_status": "review_required", "endpoint_url": ARCHIVE_URL, "endpoint_type": "csv",
                "run_id": "8e9ce94b-f270-46ce-b0eb-138e9c59d296", "status": "succeeded",
                "records_received": 1, "records_valid": 1, "records_rejected": 0, "errors": [],
                "finished_at": "2026-10-09T12:00:00Z"}
    raw = {"source_key": "denue_puebla_bulk", "record_type": "provider_location_discovered", "payload": payload,
           "external_record_id": "123", "record_hash": digest, "parse_status": "parsed"}
    observation = {"source_key": "denue_puebla_bulk", "record_hash": digest, "entity_type": entity_type,
                   "attribute_name": "name", "observed_value": "Clínica pequeña"}
    (tmp_path / "run_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    (tmp_path / "raw_records.jsonl").write_text(json.dumps(raw) + "\n", encoding="utf-8")
    (tmp_path / "observations.jsonl").write_text(json.dumps(observation) + "\n", encoding="utf-8")
    return tmp_path


def test_bulk_load_remains_partial_until_database_counts_are_asserted(tmp_path):
    batches, receipt = build_batches(artifact(tmp_path), max_bytes=2000)
    sql = "".join(batches)
    assert receipt["raw_records"] == receipt["observations"] == 1
    assert "'partial'" in sql
    assert "raise exception 'Incomplete DENUE load'" in sql
    assert sql.index("Incomplete DENUE load") < sql.index("records_published=1,status='succeeded'")
    assert all("confirmed_batch" in b and b.endswith("commit;\n") for b in batches)
    assert "on conflict(id)" in sql
    assert not any(prefix in sql for prefix in ["insert into core.", "insert into catalog.", "insert into supply."])
    assert "Persisted DENUE policy requires separate review" in sql
    assert LICENSE_URL in sql


@pytest.mark.parametrize("kwargs,match", [
    ({"entity_type": "offer"}, "identity observations"),
    ({"state": "20"}, "geography/activity/provenance"),
    ({"source_type": "provider_official"}, "official Puebla"),
])
def test_source_or_clinical_claims_cannot_enter_through_bulk_transport(tmp_path, kwargs, match):
    with pytest.raises(ValueError, match=match):
        build_batches(artifact(tmp_path, **kwargs))
