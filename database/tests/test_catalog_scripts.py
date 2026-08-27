import hashlib
import json
from pathlib import Path

from database.scripts.build_golden_catalog import build
from database.scripts.publish_golden_catalog import chunk_transaction, render


def _hash(payload):
    return hashlib.sha256(json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"), default=str).encode("utf-8")).hexdigest()


def _artifact(root: Path, source_key: str, rows: list[dict]) -> Path:
    path = root / source_key
    path.mkdir()
    raw = []
    observations = []
    for row in rows:
        payload = row["payload"]
        record_hash = _hash(payload)
        raw.append({"source_key": source_key, "record_type": "provider_offer_price", "external_record_id": row["external_record_id"], "source_url": row["source_url"], "record_hash": record_hash, "parse_status": "parsed", "payload": payload})
        observations.append({"source_key": source_key, "record_hash": record_hash, "entity_type": "offer", "attribute_name": "provider_display_name", "observed_value": payload["provider_display_name"], "status": "candidate"})
    (path / "raw_records.jsonl").write_text("\n".join(json.dumps(row, ensure_ascii=False) for row in raw) + "\n", encoding="utf-8")
    (path / "observations.jsonl").write_text("\n".join(json.dumps(row, ensure_ascii=False) for row in observations) + "\n", encoding="utf-8")
    (path / "run_manifest.json").write_text(json.dumps({"source_key": source_key, "status": "succeeded", "errors": [], "records_received": len(raw), "records_valid": len(raw), "records_rejected": 0, "run_id": f"00000000-0000-0000-0000-{len(raw):012d}"}), encoding="utf-8")
    return path


def test_golden_catalog_and_publisher_accept_salud_digna_artifact(tmp_path: Path):
    payload = {"provider_display_name": "Glucosa", "provider_external_id": "17", "provider_sku": "17", "product_url": "https://example.test/glucosa", "prices": {"regular": 11999}}
    ruiz = _artifact(tmp_path, "ruiz_puebla", [{"external_record_id": "17", "source_url": "https://example.test/ruiz/17", "payload": payload}])
    chopo = _artifact(tmp_path, "chopo_puebla", [{"external_record_id": "17", "source_url": "https://example.test/chopo/17", "payload": payload}])
    salud = _artifact(tmp_path, "salud_digna_puebla", [{"external_record_id": "332:17", "source_url": "https://example.test/salud/17", "payload": payload}])

    fixture = build(ruiz / "raw_records.jsonl", chopo / "raw_records.jsonl", salud / "raw_records.jsonl")
    sql = render(fixture, ruiz, chopo, salud)

    assert "Salud Digna" in json.dumps(fixture, ensure_ascii=False)
    assert any(mapping["source_key"] == "salud_digna_puebla" for mapping in fixture["mappings"])
    assert "salud-digna" in sql
    assert "salud_digna_puebla" in sql


def test_golden_catalog_sql_can_be_chunked_for_linked_queries():
    chunks = chunk_transaction("begin;\nselect 1;\nselect 2;\ncommit;\n", max_bytes=1024)

    assert len(chunks) == 1
    assert chunks[0].startswith("begin;\n")
    assert chunks[0].endswith("commit;\n")
