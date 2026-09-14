"""Build auditable Puebla provider identities from DENUE website candidates.

This is intentionally an identity-only import.  A DENUE establishment with a
public website is useful for the administrative review queue, but it does not
prove that the business is still operating or that it offers a particular
clinical study.  The generated fixture is therefore suitable for the generic
mapping renderer's ``--identities-only`` mode only.
"""

from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import defaultdict
from pathlib import Path
from typing import Any, Mapping
from urllib.parse import urlparse

try:
    from .artifact_io import MAX_FIXTURE_BYTES, read_json_file
except ImportError:  # pragma: no cover
    from artifact_io import MAX_FIXTURE_BYTES, read_json_file


FIXTURE_VERSION = "generic-provider-identity-candidates-puebla-v1"

# These source keys already have a reviewed identity fixture or a dedicated
# first-party collector.  Keeping them out avoids duplicate brands/locations
# while the candidate fixture is regenerated.
EXCLUDED_SOURCE_KEYS = {
    "generic_chopo_com_mx",
    "generic_familylabs_com_mx",
    "generic_laboratorioasesores_com",
    "generic_laboratorioasesores_com_mx",
    "generic_ael_com_mx",
    "generic_exacta_com",
    "generic_exakta_com",
    "generic_exakta_mx",
    "generic_fahorro_com_mx",
    "generic_labortoriosgaya_com",
    "generic_labopat_mx",
    "generic_labopap_mx",
    "generic_lafer_mx",
    "generic_labxonaca_com",
    "generic_semindigital_com",
    "generic_verkenlab_com",
    "generic_clinicadediagnostico_com",
    "generic_riex_com_mx",
    # Dedicated first-party location/catalog collectors own these identities.
    "generic_salud_digna_org",
    "generic_ssdrsimi_com_mx",
    "generic_linfolab_mx",
    "generic_linfolabmexico_com_mx",
    "generic_semin_mx",
}

# A host can contain a legal name and a commercial name.  Prefer a stable
# human-facing name for the review queue; these are still verification_pending.
BRAND_OVERRIDES = {
    "generic_adnexamen_com": ("ADN Examen", "adn_examen", "adn-examen"),
    "generic_cediclaboratorios_com": ("CEDIC Laboratorios", "cedic_laboratorios", "cedic-laboratorios"),
    "generic_dxintegra_com": ("Diagnósticos Integra", "diagnosticos_integra", "diagnosticos-integra"),
    "generic_exacta_mx": ("Laboratorios Exacta", "laboratorios_exacta", "laboratorios-exacta"),
    "generic_fahorro_com": ("Farmacias del Ahorro — laboratorio", "farmacias_del_ahorro", "farmacias-del-ahorro-laboratorio"),
    "generic_gamamedicinanuclear_com": ("Gamma Medicina Nuclear", "gamma_medicina_nuclear", "gamma-medicina-nuclear"),
    "generic_grupomedicofutura_com": ("Grupo Médico Futura", "grupo_medico_futura", "grupo-medico-futura"),
    "generic_labbiquiser_com_mx": ("Laboratorios Biquiser", "laboratorios_biquiser", "laboratorios-biquiser"),
    "generic_laboratorioguadalupe_com": ("Laboratorios Guadalupe", "laboratorios_guadalupe", "laboratorios-guadalupe"),
    "generic_laboratoriosbiogen_sacom_mx": ("Laboratorios Qui-Rom", "laboratorios_quirom", "laboratorios-quirom"),
    "generic_laboratorioscastillo_com_mx": ("Gabinete de Radiología y Ultrasonido Castillo", "laboratorios_castillo", "laboratorios-castillo"),
    "generic_laboratoriosgaya_com": ("Laboratorios Gaya", "laboratorios_gaya", "laboratorios-gaya"),
    "generic_labxonaca_com_mx": ("Laboratorio e Imagen Radiológica Althe", "althe_radiologia", "althe-radiologia"),
    "generic_losangeleslaboratorio_com": ("Laboratorio Clínico Especializado Los Ángeles", "laboratorio_los_angeles", "laboratorio-los-angeles"),
    "generic_microlabld_com_mx": ("Microlab", "microlab", "microlab"),
    "generic_od_grupomedico_com_mx": ("Sveika RX — radiología dental", "sveika_rx", "sveika-rx"),
    "generic_piedadlablaboratoriosclinicos_com": ("Piedad Lab", "piedad_lab", "piedad-lab"),
    "generic_siemso_com_mx": ("SIEMSO", "siemso", "siemso"),
    "generic_smcarmen_com": ("Laboratorios del Carmen", "laboratorios_del_carmen", "laboratorios-del-carmen"),
    "generic_suvexe_com_mx": ("SUVEX Centro Radiológico Dental", "suvex", "suvex"),
    "generic_ultrasonido4dycolorpue_com": ("Ultrasonido 4D y Color Puebla", "ultrasonido_4d_color", "ultrasonido-4d-color"),
    "generic_ultrasonidopuebla_com": ("Ultrasonido Puebla", "ultrasonido_puebla", "ultrasonido-puebla"),
    "generic_unnepuebla_mx": ("Centro Neurológico UNNE", "unne_puebla", "unne-puebla"),
}


BRAND_OVERRIDES.update(
    {
        "generic_dxintegra_com": ("Diagn" + chr(243) + "sticos Integra", "diagnosticos_integra", "diagnosticos-integra"),
        "generic_fahorro_com": ("Farmacias del Ahorro " + chr(8212) + " laboratorio", "farmacias_del_ahorro", "farmacias-del-ahorro-laboratorio"),
        "generic_grupomedicofutura_com": ("Grupo M" + chr(233) + "dico Futura", "grupo_medico_futura", "grupo-medico-futura"),
        "generic_laboratorioscastillo_com_mx": ("Gabinete de Radiolog" + chr(237) + "a y Ultrasonido Castillo", "laboratorios_castillo", "laboratorios-castillo"),
        "generic_labxonaca_com_mx": ("Laboratorio e Imagen Radiol" + chr(243) + "gica Althe", "althe_radiologia", "althe-radiologia"),
        "generic_losangeleslaboratorio_com": ("Laboratorio Cl" + chr(237) + "nico Especializado Los " + chr(193) + "ngeles", "laboratorio_los_angeles", "laboratorio-los-angeles"),
        "generic_od_grupomedico_com_mx": ("Sveika RX " + chr(8212) + " radiolog" + chr(237) + "a dental", "sveika_rx", "sveika-rx"),
        "generic_suvexe_com_mx": ("SUVEX Centro Radiol" + chr(243) + "gico Dental", "suvex", "suvex"),
        "generic_unnepuebla_mx": ("Centro Neurol" + chr(243) + "gico UNNE", "unne_puebla", "unne-puebla"),
    }
)


def normalize(value: object) -> str:
    decomposed = unicodedata.normalize("NFKD", str(value or "").casefold())
    plain = "".join(char for char in decomposed if not unicodedata.combining(char))
    return re.sub(r"[^a-z0-9]+", " ", plain).strip()


def repair_text(value: object) -> str:
    text = str(value or "").strip()
    for _ in range(2):
        if not any(marker in text for marker in ("Ãƒ", "Ã‚", "Ã¢", "ï¿½")):
            break
        try:
            candidate = text.encode("latin-1").decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError):
            break
        if candidate == text or candidate.count("ï¿½") > text.count("ï¿½"):
            break
        text = candidate
    return text


def host(value: object) -> str:
    raw = repair_text(value)
    if "://" not in raw:
        raw = f"https://{raw}"
    parsed = urlparse(raw)
    value = (parsed.hostname or "").casefold().rstrip(".")
    return value[4:] if value.startswith("www.") else value


def source_key_for_host(hostname: str) -> str:
    generated = "generic_" + re.sub(r"[^a-z0-9]+", "_", hostname).strip("_")
    # The historical generic manifest shortened this one long source key.
    if generated == "generic_ultrasonido_medico_de_alta_especialidad_doctores_dress_zeron_negocio_site":
        return "generic_ultrasonido_medico_de_alta_especialidad_doctores_dress_zeron_negocio_sit"
    return generated


def slug_for_source(source_key: str) -> str:
    return source_key.removeprefix("generic_").replace("_", "-")


def _rows(fixture: Mapping[str, Any]) -> list[Mapping[str, Any]]:
    candidates = fixture.get("candidates")
    if not isinstance(candidates, list):
        raise ValueError("DENUE fixture must contain a candidates array")
    return [row for row in candidates if isinstance(row, Mapping)]


def build_fixture(fixture: Mapping[str, Any]) -> dict[str, Any]:
    grouped: dict[str, list[Mapping[str, Any]]] = defaultdict(list)
    for row in _rows(fixture):
        if str(row.get("classification") or "") != "direct_clinical":
            continue
        website = repair_text(row.get("website_url"))
        if not website:
            continue
        source_key = source_key_for_host(host(website))
        if source_key in EXCLUDED_SOURCE_KEYS:
            continue
        # The renderer requires a real website URL and bounded coordinates.
        coordinates = row.get("coordinates")
        if not isinstance(coordinates, Mapping):
            continue
        try:
            latitude, longitude = float(coordinates["latitude"]), float(coordinates["longitude"])
        except (KeyError, TypeError, ValueError):
            continue
        if not (-90 <= latitude <= 90 and -180 <= longitude <= 180):
            continue
        grouped[source_key].append(row)

    providers: list[dict[str, Any]] = []
    used_keys: set[str] = set()
    used_slugs: set[str] = set()
    for source_key, rows in sorted(grouped.items()):
        override = BRAND_OVERRIDES.get(source_key)
        first = rows[0]
        website_host = host(first.get("website_url"))
        if override:
            brand_name, provider_key, slug = override
        else:
            brand_name = repair_text(first.get("legal_name") or first.get("name") or website_host)
            provider_key = source_key.removeprefix("generic_")
            slug = slug_for_source(source_key)
        if provider_key in used_keys or slug in used_slugs:
            raise ValueError(f"duplicate generated provider identity: {source_key}")
        denue_ids = sorted({str(row.get("external_record_id") or "").strip() for row in rows if str(row.get("external_record_id") or "").strip()})
        if not denue_ids:
            continue
        providers.append(
            {
                "source_key": source_key,
                "provider_key": provider_key,
                "brand_name": brand_name,
                "slug": slug,
                "website_url": f"https://{website_host}/",
                "denue_record_ids": denue_ids,
                "identity_note": (
                    "DENUE direct-clinical candidate with a matching public website domain; "
                    "identity, branch activity and services remain verification_pending."
                ),
            }
        )
        used_keys.add(provider_key)
        used_slugs.add(slug)
    return {
        "version": FIXTURE_VERSION,
        "policy": (
            "Identity-only candidate evidence. DENUE and a website domain do not prove "
            "current operation, ownership, catalog, price or availability."
        ),
        "source_run_id": fixture.get("source_run_id"),
        "providers": providers,
        "mappings": [],
        "summary": {
            "providers": len(providers),
            "denue_locations": sum(len(row["denue_record_ids"]) for row in providers),
            "excluded_existing_or_dedicated_sources": len(EXCLUDED_SOURCE_KEYS),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Build Puebla website identity candidates")
    parser.add_argument("--denue-fixture", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        fixture = read_json_file(args.denue_fixture, max_bytes=MAX_FIXTURE_BYTES)
        if not isinstance(fixture, Mapping):
            raise ValueError("DENUE fixture must be an object")
        output = build_fixture(fixture)
    except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        print(json.dumps({"status": "blocked", "error": str(error)}, ensure_ascii=False, indent=2))
        return 2
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": "succeeded", **output["summary"]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
