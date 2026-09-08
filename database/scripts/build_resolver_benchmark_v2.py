"""Build the field-oriented resolver benchmark v2.

v1 focused on the recipe examples and the first clinical aliases.  v2 adds
provider-style imaging, functional, cardiology, gynecology and infectious
disease labels observed in public Mexican search discussions and the live
catalog.  Every resolved case keeps the complete scope of the catalog label;
the abstention cases prove that the resolver does not guess from a broad
intent or an incomplete study name.

This is a reviewed regression corpus, not a synonym publisher.  A query is
only marked resolved when it is a normalization-preserving spelling of the
canonical label.  Broader colloquialisms remain abstentions until separately
reviewed.
"""

from __future__ import annotations

import argparse
import json
import re
import unicodedata
from pathlib import Path

try:  # Package import for tests; direct import for the CLI entrypoint.
    from .artifact_io import MAX_FIXTURE_BYTES, read_json_file
except ImportError:  # pragma: no cover - exercised by direct script invocation
    from artifact_io import MAX_FIXTURE_BYTES, read_json_file


IDS = {
    "dens_forearm_dual": "acae8edf-0d1b-5883-8e47-697834d9b3f1",
    "dens_hip_dual": "b829b973-64ca-5424-b05a-83d93cdea5dd",
    "dens_lumbar": "580717cd-4d8f-52bd-ba36-42112546cdca",
    "dens_hip_forearm": "b6e39b46-ebf0-5095-9e82-dacd11250c54",
    "dens_spine_hip": "5bd35412-4e3c-5a2a-a809-ab0b10fe3ce6",
    "dens_full_body": "d9aa15c4-0d92-5e01-8607-d9d6d60dae7b",
    "audiometry": "d07dc841-962c-59d1-a2ed-9301dde450de",
    "spirometry_check": "5627c136-27fe-57c1-85d0-22ccfd6d5d7f",
    "spirometry_bronchodilator": "dfa3afca-fb22-5c20-8e3c-34168fe1961f",
    "spirometry_simple": "971b189f-eafb-5ac9-bb90-9374dbed5f6e",
    "echo": "c2c10805-c1e4-5f65-a9a5-b62f20675945",
    "holter": "fba52c7e-ecff-5c72-b827-783f33ae69f7",
    "holter_map": "2d17283e-3fe2-5e9e-8df8-7c305121af54",
    "gasometry": "71c7e789-31c8-5da0-8dd5-ef0a7088222c",
    "ecg_pediatric": "ff01230e-0c64-5774-a4c2-1740e9a0580b",
    "covid_pcr": "dd018aa7-8f27-5485-8332-e590ed544249",
    "covid_nasal": "69e729be-be23-5e55-8e25-b971e16ea5d2",
    "covid_antigen": "d2969c40-c066-570c-8907-d8e32541c2e6",
    "covid_igg": "9128e055-04f4-5e4c-9ff4-c274d1f3bc84",
    "covid_profile": "d66b304c-afeb-53c9-9cae-1cdd529db5ad",
    "us_4d": "1afa8fa6-94c8-5f16-a78d-6ced19216a08",
    "us_4d_twins": "7f317fce-9c66-5542-aea0-92e5759f19dc",
    "us_upper_abdomen": "b3ec7d1e-9e20-55ec-9bfc-d72c0836c7dd",
    "us_neck": "856b3bf3-9c10-5a98-81b7-e2ad118c5d3b",
    "us_boyden": "2b90785a-8f47-5eb1-9daf-341b9868b42c",
    "us_renal": "6381074e-a19b-5c59-9027-c6fc6bd9150b",
    "us_testicular": "a40351fd-f38e-5bdd-b827-c794874389b5",
    "us_urinary": "9522aab2-ecf2-5be2-85c0-cde147faabf9",
    "mri_cervical": "2320fe5b-df22-53ac-af3f-664c5ef4e950",
    "mri_lumbar": "c99af777-ed67-57a5-af35-1dcadc817b5a",
    "mri_cranium": "df10e6cc-e7bc-58df-be1c-2e2215c654be",
    "mri_neck": "66313107-633f-52b0-ba8e-fa37b89d996c",
    "mri_breast": "14afdb4a-9681-5b9a-8d4e-04a7b0d95b4e",
    "ct_cervical": "7bca5f0e-f879-5c55-82c6-bdd03543227e",
    "ct_lumbar": "6cf56af2-aa88-5ff9-b627-4507f1476048",
    "ct_cranium": "6d4175a9-e365-5241-8859-c2f97a70c0d7",
    "ct_orbits": "fef75fa2-4ca9-558b-b52e-f38a31c7685f",
    "ct_sinuses": "d585766d-3502-5745-b5d6-7f2e2b1d8a65",
    "ct_upper_simple": "3b8beb63-d709-541e-941f-83a739dba3ea",
    "ct_upper_contrast": "bbc0edbc-d4b7-5987-8aa3-5057fc5a864f",
    "ct_lower_simple": "a43d2047-89f1-50c5-99e1-c0d006fe13f4",
    "ct_lower_contrast": "5418efe4-d4d0-5cdb-bedf-689a04a518c8",
    "xray_abdomen_ap": "b53fc6f3-4d51-5a8a-b919-cec0ddbbc66a",
    "xray_abdomen_decubitus": "22258a25-fb19-549a-a729-ddf198e8d266",
    "xray_abdomen_two": "e8028e0a-a6b0-5100-b70c-b90a667a1847",
    "colposcopy": "c8389561-8169-5e30-bf4d-e91d05371f17",
}

# One conservative, scope-preserving wording variant per selected service.
# These are published only after the matching migration is reviewed; a broad
# family term is intentionally absent from this map.
FIELD_ALIASES = {
    "dens_forearm_dual": "densitometría dual del antebrazo",
    "dens_hip_dual": "densitometría dual de cadera",
    "dens_lumbar": "densitometría de columna lumbar",
    "dens_hip_forearm": "densitometría ósea de cadera y antebrazo",
    "dens_spine_hip": "densitometría ósea de columna y cadera",
    "dens_full_body": "densitometría ósea de cuerpo completo",
    "spirometry_check": "espirometría para chequeo",
    "spirometry_bronchodilator": "espirometría con prueba broncodilatadora",
    "spirometry_simple": "prueba de espirometría simple",
    "echo": "eco cardiaco transtorácico",
    "holter": "monitoreo holter cardíaco",
    "holter_map": "monitoreo ambulatorio de presión arterial (MAPA)",
    "gasometry": "gasometría de sangre venosa",
    "ecg_pediatric": "electrocardiograma para niños",
    "covid_pcr": "PCR para SARS-CoV-2",
    "covid_nasal": "antígeno nasal de SARS-CoV-2",
    "covid_antigen": "prueba de antígeno para COVID-19",
    "covid_igg": "anticuerpos IgG contra SARS-CoV-2",
    "covid_profile": "perfil de anticuerpos COVID IgG IgM",
    "us_4d": "ultrasonido 4D",
    "us_4d_twins": "ultrasonido 4D para gemelos",
    "us_upper_abdomen": "ultrasonido de abdomen superior",
    "us_neck": "ultrasonido de cuello",
    "us_boyden": "ultrasonido abdominal con prueba de Boyden",
    "us_renal": "ecografía renal",
    "us_testicular": "ecografía testicular",
    "us_urinary": "ultrasonido de vías urinarias",
    "mri_cervical": "RM de columna cervical",
    "mri_lumbar": "resonancia de columna lumbar o lumbosacra",
    "mri_cranium": "RM de cráneo",
    "mri_neck": "RM de cuello",
    "mri_breast": "resonancia mamaria simple",
    "ct_cervical": "TAC de columna cervical simple",
    "ct_lumbar": "TAC de columna lumbar simple",
    "ct_cranium": "TAC de cráneo simple",
    "ct_orbits": "TAC de órbitas simple",
    "ct_sinuses": "TAC de senos paranasales simple",
    "ct_upper_simple": "TAC de abdomen superior simple",
    "ct_upper_contrast": "TAC de abdomen superior con contraste",
    "ct_lower_simple": "TAC de abdomen inferior simple",
    "ct_lower_contrast": "TAC de abdomen inferior con contraste",
    "xray_abdomen_ap": "radiografía abdomen AP de pie",
    "xray_abdomen_decubitus": "radiografía de abdomen de pie y decúbito",
    "xray_abdomen_two": "radiografía abdomen dos proyecciones AP y lateral",
    "colposcopy": "estudio de colposcopia",
}


def normalize(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value)
    without_marks = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    return re.sub(r"[^a-z0-9]+", " ", without_marks.lower()).strip()


def _variants(canonical: str, alias: str | None = None) -> list[str]:
    """Three normalization forms plus an optional reviewed semantic alias."""
    lower = canonical.lower()
    punctuation = canonical.replace(" ", "-").replace("(", "[").replace(")", "]")
    if alias:
        punctuation = alias
    if punctuation.lower() == lower:
        punctuation = lower + "."
    return [
        lower,
        canonical.upper(),
        f"  {lower}  ",
        punctuation,
    ]


def _resolved(group: str, item_key: str, canonical: str, rationale: str) -> list[dict]:
    return [
        {
            "id": f"field_{group}_{index:02d}",
            "query": query,
            "class": "safe_variant",
            "expected_status": "resolved",
            "expected_item_id": IDS[item_key],
            "allowed_match_methods": ["exact", "alias"],
            "rationale": rationale,
        }
        for index, query in enumerate(_variants(canonical, FIELD_ALIASES.get(group)), 1)
    ]


def _abstain(prefix: str, queries: list[str], rationale: str, statuses: list[str] | None = None) -> list[dict]:
    allowed = statuses or ["ambiguous", "no_match"]
    return [
        {
            "id": f"{prefix}_{index:02d}",
            "query": query,
            "class": "must_abstain",
            "expected_status": "abstain",
            "allowed_statuses": allowed,
            "rationale": rationale,
        }
        for index, query in enumerate(queries, 1)
    ]


def build() -> dict:
    cases: list[dict] = []
    studies = [
        ("dens_forearm_dual", "dens_forearm_dual", "DENSITOMETRÍA ANTEBRAZO DUAL", "Dual forearm bone-density scope is preserved."),
        ("dens_hip_dual", "dens_hip_dual", "DENSITOMETRÍA CADERA DUAL", "Dual hip scope is preserved."),
        ("dens_lumbar", "dens_lumbar", "DENSITOMETRÍA COLUMNA LUMBAR", "Lumbar spine scope is preserved."),
        ("dens_hip_forearm", "dens_hip_forearm", "DENSITOMETRÍA ÓSEA CADERA Y ANTEBRAZO (1)", "Hip and forearm multi-site scope is preserved."),
        ("dens_spine_hip", "dens_spine_hip", "DENSITOMETRÍA ÓSEA COLUMNA Y CADERA (1)", "Spine and hip multi-site scope is preserved."),
        ("dens_full_body", "dens_full_body", "DENSITOMETRÍA ÓSEA CUERPO COMPLETO (1)", "Whole-body density scope is preserved."),
        ("audiometry", "audiometry", "AUDIOMETRIA (1)", "Functional hearing study label is tested without inferring a hearing diagnosis."),
        ("spirometry_check", "spirometry_check", "ESPIROMETRIA CHEQUEO", "Check-up spirometry remains distinct from diagnostic variants."),
        ("spirometry_bronchodilator", "spirometry_bronchodilator", "ESPIROMETRIA CON BRONCODILATADOR (1)", "Bronchodilator protocol is preserved."),
        ("spirometry_simple", "spirometry_simple", "ESPIROMETRIA SIMPLE (1)", "Simple spirometry remains distinct from bronchodilator testing."),
        ("echo", "echo", "ECOCARDIOGRAMA TRANSTORACICO", "Transthoracic echocardiogram scope is preserved."),
        ("holter", "holter", "HOLTER CARDIACO", "Cardiac Holter is distinct from ambulatory blood-pressure monitoring."),
        ("holter_map", "holter_map", "HOLTER MAPA TA", "MAPA blood-pressure scope is preserved."),
        ("gasometry", "gasometry", "GASOMETRIA VENOSA", "Venous specimen is preserved."),
        ("ecg_pediatric", "ecg_pediatric", "ELECTROCARDIOGRAMA PEDIATRICO", "Pediatric ECG is distinct from resting and exercise ECG."),
        ("covid_pcr", "covid_pcr", "PRUEBA COVID-19 POR PCR", "PCR method is preserved."),
        ("covid_nasal", "covid_nasal", "PRUEBA RÁPIDA ANTÍGENO NASAL SARS-COV-2 (COVID)", "Nasal rapid-antigen scope is preserved."),
        ("covid_antigen", "covid_antigen", "PRUEBA RÁPIDA ANTÍGENO SARS-COV-2 (COVID-19)", "Rapid-antigen method is preserved."),
        ("covid_igg", "covid_igg", "SARS-COV-2 (COVID-19) ANTICUERPOS IgG", "IgG antibody target is preserved."),
        ("covid_profile", "covid_profile", "PERFIL ANTICUERPOS COVID (IGG IGM S)", "The antibody panel is not collapsed into a single antibody test."),
        ("us_4d", "us_4d", "ULTRASONIDO 4A DIMENSION", "Four-dimensional ultrasound label is tested."),
        ("us_4d_twins", "us_4d_twins", "ULTRASONIDO 4A DIMENSION GEMELAR", "Twin-pregnancy scope is preserved."),
        ("us_upper_abdomen", "us_upper_abdomen", "ULTRASONIDO ABDOMINAL SUPERIOR", "Upper-abdomen scope is preserved."),
        ("us_neck", "us_neck", "ULTRASONIDO CUELLO (1)", "Neck ultrasound scope is preserved."),
        ("us_boyden", "us_boyden", "ULTRASONIDO DE ABDOMEN CON PRUEBA DE BOYDEN", "The Boyden maneuver is not discarded."),
        ("us_renal", "us_renal", "ULTRASONIDO RENAL", "Renal anatomy is preserved."),
        ("us_testicular", "us_testicular", "ULTRASONIDO TESTICULAR", "Testicular anatomy is preserved."),
        ("us_urinary", "us_urinary", "ULTRASONIDO VIAS URINARIAS", "Urinary-tract scope is preserved."),
        ("mri_cervical", "mri_cervical", "RESONANCIA MAGNÉTICA COLUMNA CERVICAL", "MRI modality and cervical spine scope are preserved."),
        ("mri_lumbar", "mri_lumbar", "RESONANCIA MAGNÉTICA COLUMNA LUMBAR O LUMBOSACRA", "MRI lumbar/lumbosacral scope is preserved."),
        ("mri_cranium", "mri_cranium", "RESONANCIA MAGNÉTICA CRANEO", "MRI cranial scope is preserved."),
        ("mri_neck", "mri_neck", "RESONANCIA MAGNÉTICA CUELLO", "MRI neck scope is preserved."),
        ("mri_breast", "mri_breast", "RESONANCIA MAGNÉTICA MAMA SIMPLE", "Simple breast MRI is distinct from contrast imaging."),
        ("ct_cervical", "ct_cervical", "TOMOGRAFÍA COLUMNA CERVICAL SIMPLE", "Simple cervical CT scope is preserved."),
        ("ct_lumbar", "ct_lumbar", "TOMOGRAFÍA COLUMNA LUMBAR SIMPLE", "Simple lumbar CT scope is preserved."),
        ("ct_cranium", "ct_cranium", "TOMOGRAFÍA CRANEO SIMPLE", "Simple cranial CT scope is preserved."),
        ("ct_orbits", "ct_orbits", "TOMOGRAFÍA ORBITAS SIMPLE", "Simple orbit CT scope is preserved."),
        ("ct_sinuses", "ct_sinuses", "TOMOGRAFÍA SENOS PARANASALES SIMPLE", "Simple paranasal-sinus CT scope is preserved."),
        ("ct_upper_simple", "ct_upper_simple", "TOMOGRAFÍA ABDOMEN SUPERIOR SIMPLE", "Simple upper-abdomen CT is distinct from contrast CT."),
        ("ct_upper_contrast", "ct_upper_contrast", "TOMOGRAFÍA ABDOMEN SUPERIOR CON CONTRASTE", "Contrast upper-abdomen CT is preserved."),
        ("ct_lower_simple", "ct_lower_simple", "TOMOGRAFÍA ABDOMEN INFERIOR SIMPLE", "Simple lower-abdomen CT is preserved."),
        ("ct_lower_contrast", "ct_lower_contrast", "TOMOGRAFÍA ABDOMEN INFERIOR CON CONTRASTE", "Contrast lower-abdomen CT is preserved."),
        ("xray_abdomen_ap", "xray_abdomen_ap", "RAYOS X ABDOMEN AP DE PIE-1", "Standing AP radiography scope is preserved."),
        ("xray_abdomen_decubitus", "xray_abdomen_decubitus", "RAYOS X ABDOMEN DE PIE Y DECUBITO-2", "Standing/decubitus positions are preserved."),
        ("xray_abdomen_two", "xray_abdomen_two", "RAYOS X ABDOMEN DOS PROYECCIONES AP Y LAT", "Two-view AP/lateral scope is preserved."),
        ("colposcopy", "colposcopy", "COLPOSCOPIA", "Colposcopy is tested as a procedure label, without interpreting results."),
    ]
    for group, key, canonical, rationale in studies:
        cases.extend(_resolved(group, key, canonical, rationale))

    cases.extend(_abstain(
        "underspecified",
        [
            "densitometría",
            "densitometría ósea",
            "audiometría para saber si oigo bien",
            "espirometría",
            "prueba pulmonar",
            "holter",
            "electro del corazón de mi hijo",
            "resonancia de columna",
        ],
        "The input omits a catalog scope or asks for interpretation; the resolver must not guess a service variant.",
    ))
    cases.extend(_abstain(
        "panels",
        [
            "pruebas de covid",
            "anticuerpos covid",
            "estudios de osteoporosis",
            "tomografía con contraste",
        ],
        "Broad families or panels have multiple catalog variants and must remain ambiguous.",
    ))
    cases.extend(_abstain(
        "negative",
        [
            "dónde hacen estudios cerca de mí",
            "precio de audiometría",
            "interpretar mi electrocardiograma",
            "resultado positivo de covid qué significa",
        ],
        "Location, price and result-interpretation intents are not canonical services.",
        statuses=["no_match", "ambiguous"],
    ))

    if len(cases) != 200:
        raise ValueError(f"benchmark v2 must contain exactly 200 cases, got {len(cases)}")
    ids = [case["id"] for case in cases]
    if len(ids) != len(set(ids)):
        raise ValueError("benchmark v2 case IDs must be unique")
    queries = [case["query"] for case in cases]
    if len(queries) != len(set(queries)):
        raise ValueError("benchmark v2 query strings must be unique")

    v1_path = Path(__file__).parents[1] / "fixtures" / "resolver_benchmark_v1.json"
    v1 = read_json_file(v1_path, max_bytes=MAX_FIXTURE_BYTES)
    v1_normalized = {normalize(case["query"]) for case in v1["cases"] if normalize(case["query"])}
    overlap = sorted({normalize(query) for query in queries} & v1_normalized)
    if overlap:
        raise ValueError(f"benchmark v2 repeats normalized v1 queries: {overlap}")

    return {
        "version": "resolver-benchmark-v2",
        "locale": "es-MX",
        "case_count": len(cases),
        "policy": "Field variants resolve only when normalization preserves the complete reviewed catalog label; broad intents and incomplete scopes abstain.",
        "sources": [
            "Public, anonymized discovery phrases from Reddit threads listed in docs/REAL_QUERY_RESEARCH_V1.md.",
            "Observed provider catalog labels in collectors/artifacts/live/catalog_golden_live.json and the linked Supabase catalog.",
            "Resolver v6 exact-dominance, token guard and structured imaging constraints.",
        ],
        "privacy": "No usernames, post bodies, diagnoses, ages, addresses or other personal data are stored; only short service/intent phrases are retained.",
        "cases": cases,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    payload = build()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(payload['cases'])} cases to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
