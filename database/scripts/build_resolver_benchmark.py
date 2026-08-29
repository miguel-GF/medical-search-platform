"""Build the reviewed resolver benchmark corpus.

The corpus intentionally contains three kinds of input:

* safe lexical variants that may resolve to one canonical item;
* broad, incomplete or composition-dependent terms that must abstain;
* unrelated/adversarial input that must not produce a medical match.

It is a regression corpus, not a synonym publisher.  Adding a query here
does not grant it clinical equivalence; the expected policy is reviewed
separately from the resolver implementation.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


IDS = {
    "emg_lower": "00000000-0000-0000-0000-000000001101",
    "emg_upper": "00000000-0000-0000-0000-000000001102",
    "bh": "00000000-0000-0000-0000-000000001103",
    "ego": "00000000-0000-0000-0000-000000001104",
    "qs_basic": "00000000-0000-0000-0000-000000001105",
    "qs_extended": "00000000-0000-0000-0000-000000001106",
    "thyroid_basic": "00000000-0000-0000-0000-000000001107",
    "thyroid_extended": "00000000-0000-0000-0000-000000001108",
    "glucose": "00000000-0000-0000-0000-000000001109",
    "creatinine": "00000000-0000-0000-0000-000000001110",
    "tsh": "00000000-0000-0000-0000-000000001111",
    "t4_free": "00000000-0000-0000-0000-000000001112",
    "t3": "00000000-0000-0000-0000-000000001113",
    "ultrasound_abdomen": "a1f81444-4b20-5d82-bdf6-b48c27245fa0",
    "ultrasound_obstetric": "82d84811-2542-5f8d-8c2c-01186700c4cb",
    "mammography": "b4994aa8-b7c4-52f3-8f46-c74356d62d4a",
    "mammography_bilateral": "5e21aef5-5328-5ffc-af37-aef84fb1d6a7",
    "mammography_unilateral": "81aa9f9f-737b-537d-9c18-2b023e3e1139",
    "ecg_rest": "c9d9a832-8146-5831-94f5-ec653dea2126",
    "ecg_exercise": "b6f15c15-29b4-5dd4-b2a2-944e9d0e1b20",
    "ct_abdomen_simple": "2ae7ac0c-4e14-5aec-96bb-af81d5099e8a",
    "ct_abdomen_contrast": "ed7e83db-f394-5171-ae4d-ca347b648028",
    "mri_abdomen": "ceff2afb-eada-5095-9e74-ab7ebbfa21e6",
    "mri_abdomen_contrast": "de354e6e-412d-565f-a5f7-8e6fe27a7680",
    "xray_abdomen_one": "b79cede5-4e29-5b58-816e-b1a0a074b433",
}


def _resolved(group: str, item_key: str, queries: list[str], rationale: str) -> list[dict]:
    return [
        {
            "id": f"{group}_{index:02d}",
            "query": query,
            "class": "safe_variant",
            "expected_status": "resolved",
            "expected_item_id": IDS[item_key],
            "allowed_match_methods": ["exact", "alias"],
            "rationale": rationale,
        }
        for index, query in enumerate(queries, 1)
    ]


def _abstain(group: str, queries: list[str], rationale: str, statuses: list[str] | None = None) -> list[dict]:
    allowed = statuses or ["ambiguous", "no_match"]
    return [
        {
            "id": f"{group}_{index:02d}",
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

    cases += _resolved(
        "bh",
        "bh",
        [
            "Biometría hemática",
            "BIOMETRIA HEMATICA",
            "biometria-hematica",
            "biometría_hemática",
            " B H ",
            "BH",
            "Hemograma",
            "biometria hematica completa",
            "hemograma completo",
            "CBC",
            "Complete blood count",
            "conteo sanguineo completo",
            "biometria hematica automatizada",
        ],
        "Case/diacritic/punctuation variants and reviewed CBC synonyms.",
    )
    cases += _resolved(
        "ego",
        "ego",
        [
            "Examen general de orina",
            "EXAMEN GENERAL DE ORINA",
            "examen-general-de-orina",
            "examen general de orina ",
            "EGO",
            "EGO completo",
            "Uroanálisis",
            "Uroanalisis",
            "Urianálisis",
            "Análisis general de orina",
            "Análisis completo de orina",
            "Examen de orina",
            "Examen de orina completo",
            "Urinalysis",
            "Orina general",
        ],
        "Case/diacritic variants and reviewed complete-urinalysis synonyms.",
    )
    cases += _resolved(
        "glucose",
        "glucose",
        [
            "Glucosa",
            "GLUCOSA",
            "glucósa",
            "glucosa sérica",
            "glucosa en suero",
            "glucosa plasmática",
            "glucosa en plasma",
            "Glucose",
            " glucosa ",
            "glucosa-serica",
        ],
        "Reviewed glucose concept; specimen-specific synonyms stay within serum/plasma scope.",
    )
    cases += _resolved(
        "creatinine",
        "creatinine",
        [
            "Creatinina",
            "CREATININA",
            "creatinína",
            "creatinina sérica",
            "creatinina en suero",
            "creatinina plasmática",
            "creatinina en plasma",
            "Creatinine",
            " creatinina ",
            "creatinina-serica",
        ],
        "Reviewed creatinine concept; specimen-specific synonyms stay within serum/plasma scope.",
    )
    cases += _resolved(
        "tsh",
        "tsh",
        [
            "TSH",
            "tsh",
            "T.S.H.",
            "Hormona estimulante de tiroides",
            "hormona estimulante de tiroides",
            "Tirotropina",
            "Thyrotropin",
            "Thyroid stimulating hormone",
            "TSH sérica",
            " tsh ",
        ],
        "Reviewed thyrotropin concept and standard Spanish/English synonyms.",
    )
    cases += _resolved(
        "t4",
        "t4_free",
        [
            "T4 libre",
            "T4 LIBRE",
            "t4-libre",
            "Tiroxina libre",
            "T4L",
            "FT4",
            "Thyroxine free",
            "T4 libre sérica",
            "T4 libre en suero",
            " t4 libre ",
        ],
        "Reviewed free-thyroxine concept; free qualifier is required.",
    )
    cases += _resolved(
        "t3",
        "t3",
        [
            "T3",
            "t3",
            "T.3.",
            "Triyodotironina",
            "Triiodotironina",
            "T3 total",
            "Triyodotironina total",
            "Triiodothyronine",
            "T3 sérica",
            " t3 ",
        ],
        "Reviewed total-like T3 concept; free T3 is intentionally not included.",
    )
    cases += _resolved(
        "emg_lower",
        "emg_lower",
        [
            "Electromiografía de extremidades inferiores",
            "electromiografia de extremidades inferiores",
            "EMG de miembros inferiores",
            "EMG miembros inferiores",
            "Electromiografía de piernas",
            "EMG de piernas",
            "electromiografia-de-extremidades-inferiores",
            " EMG de miembros inferiores ",
        ],
        "EMG variants retain lower-extremity anatomy; generic EMG is excluded.",
    )
    cases += _resolved(
        "emg_upper",
        "emg_upper",
        [
            "Electromiografía de extremidades superiores",
            "electromiografia de extremidades superiores",
            "EMG de miembros superiores",
            "EMG miembros superiores",
            "Electromiografía de brazos",
            "EMG de brazos",
            "electromiografia-de-extremidades-superiores",
            " EMG de miembros superiores ",
        ],
        "EMG variants retain upper-extremity anatomy; generic EMG is excluded.",
    )

    cases += _resolved(
        "ultrasound_abdomen",
        "ultrasound_abdomen",
        [
            "Ultrasonido abdomen completo",
            "ULTRASONIDO ABDOMEN COMPLETO",
            "ultrasonido-abdomen-completo",
            "Ultrasonido abdomen completo ",
            "Ecografía abdomen completo",
            "Ecografía abdominal completa",
            "ultrasonido abdominal completo",
            "ecografia abdomen completo",
        ],
        "Reviewed provider concept; modality and complete-abdomen scope are preserved.",
    )
    cases += _resolved(
        "ultrasound_obstetric",
        "ultrasound_obstetric",
        [
            "Ultrasonido obstétrico",
            "ULTRASONIDO OBSTETRICO",
            "ultrasonido-obstetrico",
            "Ecografía obstétrica",
            "ecografia obstetrica",
            "ultrasonografía obstétrica",
        ],
        "Reviewed provider concept; obstetric scope is preserved.",
    )
    cases += _resolved(
        "mammography_base",
        "mammography",
        ["Mastografía", "MASTOGRAFIA", "mastografia", "mastografía ", "mastografia general"],
        "Generic mammography is distinct from the explicit bilateral/unilateral variants.",
    )
    cases += _resolved(
        "mammography_bilateral",
        "mammography_bilateral",
        [
            "Mastografía bilateral",
            "MASTOGRAFIA BILATERAL",
            "mamografía bilateral",
            "Mamografía de ambas mamas",
            "mastografia de ambas mamas",
            "mastografia-bilateral",
        ],
        "Laterality is retained; bilateral cannot collapse into generic mammography.",
    )
    cases += _resolved(
        "mammography_unilateral",
        "mammography_unilateral",
        [
            "Mastografía unilateral",
            "MASTOGRAFIA UNILATERAL",
            "mamografía unilateral",
            "Mamografía de una mama",
            "mastografía de una mama",
            "mastografia-unilateral",
        ],
        "Laterality is retained; unilateral cannot collapse into generic mammography.",
    )
    cases += _resolved(
        "ecg_rest",
        "ecg_rest",
        [
            "Electrocardiograma en reposo",
            "ELECTROCARDIOGRAMA EN REPOSO",
            "Electrocardiograma de reposo",
            "ECG en reposo",
            "EKG en reposo",
        ],
        "Resting ECG variants retain the modality context.",
    )
    cases += _resolved(
        "ecg_exercise",
        "ecg_exercise",
        [
            "Electrocardiograma en esfuerzo",
            "ELECTROCARDIOGRAMA EN ESFUERZO",
            "electrocardiograma de esfuerzo",
        ],
        "Exercise ECG is distinct from resting and pediatric ECG.",
    )
    cases += _resolved(
        "ct_abdomen_simple",
        "ct_abdomen_simple",
        [
            "Tomografía abdomen completo simple",
            "TOMOGRAFIA ABDOMEN COMPLETO SIMPLE",
            "tomografía de abdomen completo simple",
            "TAC abdomen completo simple",
        ],
        "Simple CT and complete-abdomen scope are retained.",
    )
    cases += _resolved(
        "ct_abdomen_contrast",
        "ct_abdomen_contrast",
        [
            "Tomografía abdomen completo contraste",
            "TOMOGRAFIA ABDOMEN COMPLETO CONTRASTE",
            "tomografía de abdomen completo con contraste",
            "TAC abdomen completo con contraste",
        ],
        "Contrast-enhanced CT and complete-abdomen scope are retained.",
    )
    cases += _resolved(
        "mri_abdomen",
        "mri_abdomen",
        [
            "Resonancia magnética abdomen completo",
            "RESONANCIA MAGNETICA ABDOMEN COMPLETO",
            "resonancia de abdomen completo",
        ],
        "MRI body region is retained; contrast variant is not collapsed.",
    )
    cases += _resolved(
        "mri_abdomen_contrast",
        "mri_abdomen_contrast",
        [
            "Resonancia magnética abdomen completo con contraste gadolinio",
            "RESONANCIA MAGNETICA ABDOMEN COMPLETO CON CONTRASTE GADOLINIO",
        ],
        "MRI contrast and body region are retained.",
    )
    cases += _abstain(
        "mri_incomplete_scope",
        ["resonancia de abdomen con contraste gadolinio"],
        "Contrast is known but the body scope is incomplete; do not choose a complete/superior/inferior variant.",
        statuses=["ambiguous", "no_match"],
    )
    cases += _resolved(
        "xray_abdomen",
        "xray_abdomen_one",
        ["Rayos X abdomen una posición"],
        "Radiography body region and one-position scope are retained.",
    )

    cases += _abstain(
        "panels",
        [
            "QS",
            "Q S",
            "QS completa",
            "Q S completa",
            "Q.S. completa",
            "química sanguínea",
            "quimica sanguinea completa",
            "panel de química sanguínea",
            "perfil tiroideo",
            "perfil toroideo",
            "perfil tiroides",
            "perfil de tiroides",
            "perfil tiroideo completo",
            "perfil tiroideo en suero",
            "panel tiroideo",
            "pruebas de tiroides",
            "estudios tiroideos",
            "T3 T4 TSH perfil",
        ],
        "Panel composition or scope is provider-specific; the resolver must ask/abstain.",
    )
    cases += _abstain(
        "underspecified",
        [
            "electromiografía",
            "EMG",
            "electrodiagnóstico",
            "glucemia",
            "glucosa en sangre",
            "glucosa capilar",
            "creatinina en sangre",
            "T4",
            "T3 libre",
            "TSH ultrasensible",
            "ecografía",
            "ultrasonido abdomen",
            "resonancia magnética",
            "RM",
            "MRI",
            "tomografía",
            "TAC",
            "rayos X",
            "radiografía",
            "mamografía",
        ],
        "Missing anatomy, specimen, laterality, modality or contrast must not be guessed.",
    )
    cases += _abstain(
        "negative",
        [
            "hola",
            "buenos días necesito un estudio",
            "precio de zapatos",
            "código postal 72000",
            "pizza",
            "consulta dermatológica",
            "medicina general",
            "electromiografía de gatos",
            "glucosa de unicornio",
            "DROP TABLE catalog.items",
            "<script>alert('xss')</script>",
            "'; select pg_sleep(10); --",
            "../../etc/passwd",
            "",
        ],
        "Unrelated, malformed or adversarial input must never resolve to a service.",
        statuses=["no_match"],
    )

    if not 100 <= len(cases) <= 200:
        raise ValueError(f"benchmark must contain 100-200 cases, got {len(cases)}")
    ids = [case["id"] for case in cases]
    if len(ids) != len(set(ids)):
        raise ValueError("benchmark case IDs must be unique")

    return {
        "version": "resolver-benchmark-v1",
        "locale": "es-MX",
        "case_count": len(cases),
        "policy": "Resolved cases require one reviewed canonical item; panels, underspecified terms and unrelated input must abstain.",
        "sources": [
            "User-provided recipe examples: B H, Q S completa, EGO, perfil toroideo.",
            "Resolver Gate B OCR/alias migrations and clinical resolver tests.",
            "Official provider catalog artifacts for Puebla: Ruiz, Chopo, Salud Digna and generic discovery.",
            "LOINC 2.83 reviewed mappings for BH/EGO/glucose/creatinine/TSH/T4/T3.",
        ],
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
