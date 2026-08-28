import hashlib
import json
from pathlib import Path

from database.scripts.classify_denue_candidates import classify, normalize, repair_text


def _artifact(root: Path, rows: list[dict]) -> Path:
    artifact = root / "denue"
    artifact.mkdir()
    raw = []
    for row in rows:
        payload = dict(row)
        digest = hashlib.sha256(
            json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
        ).hexdigest()
        raw.append(
            {
                "source_key": "denue",
                "record_type": "provider_location_discovered",
                "external_record_id": payload["Id"],
                "source_url": f"https://example.test/{payload['Id']}",
                "record_hash": digest,
                "parse_status": "parsed",
                "payload": payload,
            }
        )
    (artifact / "raw_records.jsonl").write_text(
        "\n".join(json.dumps(row, ensure_ascii=False) for row in raw) + "\n", encoding="utf-8"
    )
    (artifact / "run_manifest.json").write_text(
        json.dumps(
            {
                "source_key": "denue",
                "status": "succeeded",
                "errors": [],
                "records_received": len(raw),
                "records_valid": len(raw),
                "records_rejected": 0,
                "run_id": "00000000-0000-0000-0000-000000000123",
                "finished_at": "2026-08-28T00:00:00Z",
            }
        ),
        encoding="utf-8",
    )
    return artifact


def _row(identifier: str, name: str, activity: str, *, legal: str = "Grupo") -> dict:
    return {
        "Id": identifier,
        "Nombre": name,
        "Razon_social": legal,
        "Clase_actividad": activity,
        "Calle": "Reforma",
        "Num_Exterior": "1",
        "Colonia": "Centro",
        "CP": "72000",
        "Latitud": "19.043700",
        "Longitud": "-98.198200",
    }


def test_repair_and_normalize_handle_denue_mojibake():
    assert repair_text("Laboratorio MÃ©dico") == "Laboratorio Médico"
    assert normalize("Laboratorio MÃ©dico") == "laboratorio medico"


def test_classification_filters_and_deduplicates_by_identity_and_coordinates(tmp_path: Path):
    artifact = _artifact(
        tmp_path,
        [
            _row("1", "Salud Digna Puebla", "Laboratorios mÃ©dicos y de diagnÃ³stico del sector privado", legal="Salud Digna"),
            _row("2", "Salud Digna Puebla duplicado", "Laboratorios mÃ©dicos y de diagnÃ³stico del sector privado", legal="Salud Digna"),
            _row("3", "Gabinete de Radiología", "Laboratorios de pruebas"),
            _row("4", "Tienda de equipo", "Comercio al por mayor de mobiliario, equipo e instrumental médico y de laboratorio"),
        ],
    )
    # Rows 1 and 2 have the same legal identity and coordinates, so they form
    # one candidate group without losing either DENUE external ID as evidence.
    result = classify(artifact)

    assert result["summary"]["direct_clinical_records"] == 2
    assert result["summary"]["direct_clinical_candidates"] == 1
    assert result["summary"]["related_clinical_review"] == 1
    assert result["summary"]["non_clinical_excluded"] == 1
    assert result["summary"]["known_brand_matches"] == {"salud_digna": 2}
    assert len(result["candidates"]) == 1
    assert result["candidates"][0]["source_record_ids"] == ["1", "2"]
    assert result["candidates"][0]["brand_match"]["brand_key"] == "salud_digna"

