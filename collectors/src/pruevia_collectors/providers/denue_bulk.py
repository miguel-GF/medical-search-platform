"""Read the official Puebla DENUE archive without an API token.

The SCIAN activity selects establishments to investigate. It does not establish
that a clinic performs a particular study, nor does it consolidate businesses.
"""

from __future__ import annotations

import csv
import hashlib
import io
import math
import re
import zipfile
from collections import Counter
from pathlib import Path

from ..models import Observation, SourceRecord, SourceSpec


ARCHIVE_URL = "https://www.inegi.org.mx/contenidos/masiva/denue/denue_21_csv.zip"
LICENSE_URL = "https://www.inegi.org.mx/inegi/terminos.html"
MAX_ARCHIVE_BYTES = 100 * 1024 * 1024
MAX_CSV_BYTES = 350 * 1024 * 1024
MAX_CSV_ROWS = 1_000_000
MAX_HEALTHCARE_ROWS = 50_000
REQUIRED_COLUMNS = {
    "id", "nom_estab", "codigo_act", "nombre_act", "cve_ent", "municipio",
    "latitud", "longitud", "fecha_alta",
}
# Preserve business identification/location fields only, excluding email,
# telephone and the legal representative's name.
IDENTITY_COLUMNS = (
    "id", "clee", "nom_estab", "codigo_act", "nombre_act", "per_ocu",
    "tipo_vial", "nom_vial", "numero_ext", "letra_ext", "numero_int",
    "letra_int", "tipo_asent", "nomb_asent", "cod_postal", "cve_ent",
    "entidad", "cve_mun", "municipio", "cve_loc", "localidad", "www",
    "latitud", "longitud", "fecha_alta",
)


class DenueBulkAdapter:
    source = SourceSpec(
        source_key="denue_puebla_bulk",
        name="INEGI DENUE Puebla — descarga estatal",
        source_type="government",
        usage_policy_status="approved",
        endpoint_type="csv",
        endpoint_url=ARCHIVE_URL,
        parser_version="denue-puebla-bulk-v1",
        expected_min_records=1,
        expected_max_records=MAX_HEALTHCARE_ROWS,
    )

    def __init__(self, archive: Path) -> None:
        self.archive = archive
        self.summary: dict = {}

    def collect(self):
        if not self.archive.is_file() or self.archive.stat().st_size > MAX_ARCHIVE_BYTES:
            raise ValueError("DENUE archive missing or exceeds its size limit")
        digest = hashlib.sha256()
        with self.archive.open("rb") as source:
            for block in iter(lambda: source.read(1024 * 1024), b""):
                digest.update(block)
        seen: set[str] = set()
        classes: Counter[str] = Counter()
        municipalities: Counter[str] = Counter()
        quality: Counter[str] = Counter()
        scanned = 0
        with zipfile.ZipFile(self.archive) as archive:
            members = [m for m in archive.infolist() if
                       m.filename.startswith("conjunto_de_datos/") and
                       m.filename.lower().endswith(".csv") and not m.is_dir()]
            if len(members) != 1 or members[0].file_size > MAX_CSV_BYTES:
                raise ValueError("DENUE archive must contain one bounded data CSV")
            metadata_members = [m for m in archive.infolist() if
                                m.filename == "metadatos/metadatos_denue.txt"]
            if len(metadata_members) != 1 or metadata_members[0].file_size > 64 * 1024:
                raise ValueError("DENUE release metadata is missing or too large")
            metadata = archive.read(metadata_members[0]).decode("utf-8-sig")
            release_match = re.search(r"^Modified:\s*(\d{4}-\d{2}-\d{2})", metadata, re.M)
            if not release_match or "INEGI" not in metadata or "terminos.html" not in metadata:
                raise ValueError("DENUE release/date/license metadata is invalid")
            release = release_match[1]
            with archive.open(members[0]) as stream:
                # The published CSV uses Windows-1252; metadata uses UTF-8.
                rows = csv.DictReader(io.TextIOWrapper(stream, encoding="cp1252", newline=""))
                if not REQUIRED_COLUMNS.issubset(rows.fieldnames or []):
                    raise ValueError("DENUE CSV schema has changed")
                for row in rows:
                    scanned += 1
                    if scanned > MAX_CSV_ROWS:
                        raise ValueError("DENUE CSV exceeds its row limit")
                    if row["cve_ent"] != "21":
                        raise ValueError("Puebla archive contains a different state")
                    if not row["codigo_act"].startswith(("621", "622")):
                        continue
                    external_id = row["id"].strip()
                    if not re.fullmatch(r"[0-9]{1,16}", external_id) or external_id in seen:
                        raise ValueError("DENUE establishment has an invalid or duplicate ID")
                    seen.add(external_id)
                    if len(seen) > MAX_HEALTHCARE_ROWS:
                        raise ValueError("DENUE healthcare subset exceeds its row limit")
                    payload = {key: row.get(key, "").strip() for key in IDENTITY_COLUMNS}
                    payload["_source_archive"] = {
                        "url": ARCHIVE_URL, "sha256": digest.hexdigest(),
                        "release_date": release, "license_url": LICENSE_URL,
                        "attribution": "Fuente: INEGI, DENUE " + release,
                        "transformation": "Puebla; SCIAN 621/622; campos de identidad y ubicación",
                    }
                    flags = []
                    if not payload["nom_estab"]:
                        flags.append("missing_business_name")
                    try:
                        latitude, longitude = float(row["latitud"]), float(row["longitud"])
                        if not (math.isfinite(latitude) and math.isfinite(longitude)
                                and 17.7 <= latitude <= 21.0 and -99.1 <= longitude <= -96.6):
                            raise ValueError("coordinates outside Puebla bounds")
                        coordinates = {"latitude": latitude, "longitude": longitude}
                    except (ValueError, TypeError):
                        flags.append("invalid_coordinates")
                        coordinates = None
                    payload["_quality_flags"] = flags
                    observations = [
                        Observation("provider_location", "denue_id", external_id),
                        Observation("provider_location", "activity_code", payload["codigo_act"]),
                        Observation("provider_location", "address", {
                            "street": " ".join(filter(None, [payload["tipo_vial"], payload["nom_vial"]])),
                            "exterior_number": payload["numero_ext"] + payload["letra_ext"],
                            "interior_number": payload["numero_int"] + payload["letra_int"],
                            "neighborhood": payload["nomb_asent"], "postal_code": payload["cod_postal"],
                            "locality": payload["localidad"], "municipality": payload["municipio"],
                            "state": payload["entidad"],
                        }),
                    ]
                    if payload["nom_estab"]:
                        observations.append(Observation("provider_location", "name", payload["nom_estab"]))
                    if coordinates:
                        observations.append(Observation("provider_location", "coordinates", coordinates))
                    if payload["www"]:
                        observations.append(Observation("provider_location", "website_url", payload["www"]))
                    classes[payload["codigo_act"]] += 1
                    municipalities[payload["municipio"]] += 1
                    quality.update(flags)
                    yield SourceRecord(
                        source_key=self.source.source_key, record_type="provider_location_discovered",
                        external_record_id=external_id, source_url=ARCHIVE_URL,
                        payload=payload, observations=tuple(observations),
                    )
        self.summary = {
            "archive_url": ARCHIVE_URL, "archive_sha256": digest.hexdigest(),
            "release_date": release, "scanned_establishments": scanned,
            "healthcare_establishments": len(seen), "activity_counts": dict(sorted(classes.items())),
            "municipality_counts": dict(sorted(municipalities.items())),
            "quality_flags": dict(quality), "license_url": LICENSE_URL,
        }
        if not seen:
            raise ValueError("DENUE healthcare subset is empty")
