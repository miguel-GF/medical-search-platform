import csv
import io
import zipfile

import pytest

from pruevia_collectors.providers.denue_bulk import DenueBulkAdapter, IDENTITY_COLUMNS


def archive(tmp_path, rows, *, metadata=True):
    path = tmp_path / "puebla.zip"
    buffer = io.StringIO(newline="")
    writer = csv.DictWriter(buffer, fieldnames=[*IDENTITY_COLUMNS, "telefono", "correoelec", "raz_social"])
    writer.writeheader()
    for override in rows:
        writer.writerow({"id": "123", "nom_estab": "Clínica pequeña", "codigo_act": "621511",
                         "nombre_act": "Laboratorios médicos", "cve_ent": "21", "entidad": "Puebla",
                         "municipio": "Teziutlán", "latitud": "19.81", "longitud": "-97.36",
                         "fecha_alta": "2020-01", **override})
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("diccionario_de_datos/dictionary.csv", "not the establishment data")
        z.writestr("conjunto_de_datos/puebla.csv", buffer.getvalue().encode("cp1252"))
        if metadata:
            z.writestr("metadatos/metadatos_denue.txt",
                       "Publisher: INEGI\nModified: 2026-05-20\nLicense: https://www.inegi.org.mx/inegi/terminos.html\n")
    return path


def test_statewide_identity_evidence_preserves_accents_and_excludes_contacts(tmp_path):
    adapter = DenueBulkAdapter(archive(tmp_path, [{"telefono": "123", "correoelec": "private@example.com"},
                                                {"id": "124", "codigo_act": "622111"},
                                                {"id": "125", "codigo_act": "624411"}]))
    records = list(adapter.collect())
    assert [r.external_record_id for r in records] == ["123", "124"]
    assert records[0].payload["nom_estab"] == "Clínica pequeña"
    assert records[0].payload["municipio"] == "Teziutlán"
    assert not {"telefono", "correoelec", "raz_social"} & records[0].payload.keys()
    assert all(o.entity_type == "provider_location" for r in records for o in r.observations)
    assert adapter.summary["scanned_establishments"] == 3
    assert adapter.summary["healthcare_establishments"] == 2
    assert records[0].payload["_source_archive"]["release_date"] == "2026-05-20"


def test_incomplete_names_and_coordinates_remain_traceable_without_inference(tmp_path):
    adapter = DenueBulkAdapter(archive(tmp_path, [{"nom_estab": "", "latitud": "nan"}]))
    record, = list(adapter.collect())
    assert record.payload["_quality_flags"] == ["missing_business_name", "invalid_coordinates"]
    assert not any(o.attribute_name in {"coordinates", "name"} for o in record.observations)
    assert adapter.summary["quality_flags"] == {"missing_business_name": 1, "invalid_coordinates": 1}


@pytest.mark.parametrize("rows,metadata,match", [
    ([{"cve_ent": "20"}], True, "different state"),
    ([{}, {}], True, "duplicate ID"),
    ([{"id": "bad"}], True, "invalid or duplicate ID"),
    ([{}], False, "metadata"),
    ([{"codigo_act": "624411"}], True, "empty"),
])
def test_invalid_archive_is_rejected(tmp_path, rows, metadata, match):
    adapter = DenueBulkAdapter(archive(tmp_path, rows, metadata=metadata))
    with pytest.raises(ValueError, match=match):
        list(adapter.collect())
