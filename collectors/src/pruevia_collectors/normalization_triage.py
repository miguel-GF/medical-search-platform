"""Read-only triage of grouped crawler labels against approved catalog terms.

This module produces suggestions and review-cluster identifiers only. A raw
external ID is not necessarily a stable provider SKU. It never approves an
equivalence, creates a catalog item, or publishes an offer.
"""

from __future__ import annotations

import hashlib
from collections import Counter, defaultdict
from typing import Any, Iterable
from urllib.parse import urlparse

from pruevia_collectors.normalization import (
    CatalogResolver,
    CatalogTerm,
    NormalizationCandidate,
    normalize_text,
)


_TRIAGE_STOPWORDS = {
    "a", "al", "como", "con", "de", "del", "desde", "el", "en", "entre",
    "esta", "este", "estos", "la", "las", "los", "para", "por", "que", "sin",
    "sobre", "sus", "un", "una", "uno", "y",
}
_ATTRIBUTE_VALUES: dict[str, dict[str, str]] = {
    "specimen": {
        "orina": "urine", "urine": "urine", "suero": "serum", "serum": "serum",
        "plasma": "plasma", "sangre": "blood", "blood": "blood",
        "heces": "stool", "fecal": "stool", "stool": "stool",
    },
    "direction": {"superior": "superior", "inferior": "inferior"},
    "laterality": {
        "derecho": "right", "derecha": "right", "right": "right",
        "izquierdo": "left", "izquierda": "left", "left": "left",
        "bilateral": "bilateral",
    },
    "immunoglobulin": {"igg": "igg", "igm": "igm", "iga": "iga", "ige": "ige"},
    "route": {
        "transvaginal": "transvaginal", "transabdominal": "transabdominal",
        "transrectal": "transrectal",
    },
    "panel_scope": {
        "completo": "complete", "completa": "complete", "integral": "complete",
        "basico": "basic", "basica": "basic", "parcial": "partial",
    },
    "projection": {
        "ap": "ap", "pa": "pa", "lateral": "lateral",
        "oblicua": "oblique", "oblicuo": "oblique", "axial": "axial",
    },
    "protocol": {
        "angiotomografia": "angiographic", "angioresonancia": "angiographic",
        "angiorresonancia": "angiographic", "angiografia": "angiographic", "angio": "angiographic",
    },
    "comparison": {"comparativo": "comparative", "comparativos": "comparative"},
    "population": {
        "neonatal": "neonatal", "neonatales": "neonatal", "neonato": "neonatal", "neonatos": "neonatal",
        "lactante": "infant", "lactantes": "infant", "pediatrico": "pediatric", "pediatrica": "pediatric",
        "adulto": "adult", "adultos": "adult",
    },
}
_ANATOMY_VALUES = {
    "mama": "breast", "mamaria": "breast", "breast": "breast",
    "mano": "hand", "manos": "hand", "hand": "hand",
    "pie": "foot", "pies": "foot", "foot": "foot",
    "pierna": "leg", "piernas": "leg", "leg": "leg",
    "codo": "elbow", "elbow": "elbow",
    "rodilla": "knee", "rodillas": "knee", "knee": "knee",
    "antebrazo": "forearm", "forearm": "forearm",
    "brazo": "arm", "brazos": "arm", "arm": "arm",
    "cuello": "neck", "neck": "neck",
    "craneo": "skull", "skull": "skull",
    "cerebro": "brain", "encefalo": "brain", "brain": "brain",
    "columna": "spine", "spine": "spine",
    "cadera": "hip", "hip": "hip",
    "abdomen": "abdomen", "abdominal": "abdomen",
    "pelvis": "pelvis", "pelvica": "pelvis", "pelvico": "pelvis",
    "renal": "kidney", "rinon": "kidney", "rinones": "kidney",
    "kidney": "kidney",
}
_POSTURAL_DE_PIE_SITES = {"abdomen", "abdominal", "torax", "toracico", "toracica"}
_MODALITY_VALUES = {
    "ultrasonido": "ultrasound", "ultrasonografia": "ultrasound", "ecografia": "ultrasound",
    "ultrasound": "ultrasound", "tomografia": "ct", "tomografica": "ct",
    "tomografico": "ct", "angiotomografia": "ct", "tac": "ct", "tc": "ct",
    "ct": "ct", "resonancia": "mri", "angioresonancia": "mri",
    "angiorresonancia": "mri", "magnetica": "mri", "magnetico": "mri",
    "rm": "mri", "mri": "mri",
    "radiografia": "xray", "radiografias": "xray", "rayos": "xray", "rx": "xray",
    "mamografia": "mammography", "mastografia": "mammography",
    "electrocardiograma": "ecg", "ecg": "ecg",
}
_ARTICLE_TOKENS = {"el", "la", "los", "las", "un", "una", "unos", "unas"}
_CORE_GENERIC_TOKENS = (
    _TRIAGE_STOPWORDS
    | set(_ATTRIBUTE_VALUES["specimen"])
    | set(_ATTRIBUTE_VALUES["direction"])
    | set(_ATTRIBUTE_VALUES["laterality"])
    | set(_ATTRIBUTE_VALUES["immunoglobulin"])
    | set(_ATTRIBUTE_VALUES["route"])
    | set(_ATTRIBUTE_VALUES["panel_scope"])
    | set(_ATTRIBUTE_VALUES["projection"])
    | set(_ATTRIBUTE_VALUES["protocol"])
    | set(_ATTRIBUTE_VALUES["comparison"])
    | set(_ATTRIBUTE_VALUES["population"])
    | set(_MODALITY_VALUES)
    | {
        "anticuerpo", "anticuerpos", "anti", "estudio", "examen", "panel",
        "perfil", "prueba", "test", "determinacion", "medicion", "comparativo",
        "comparativos",
    }
)


def build_catalog(rows: Iterable[dict[str, Any]]) -> tuple[CatalogTerm, ...]:
    """Reconstruct names and provider-scoped aliases from the bounded RPC."""

    items: dict[str, dict[str, Any]] = {}
    for row in rows:
        item_id = str(row['item_id'])
        term = str(row['term'])
        item = items.setdefault(item_id, {
            'item_id': item_id,
            'display_name': str(row['display_name']),
            'aliases': set(),
            'provider_aliases': set(),
        })
        if row['term_type'] == 'name' or not row.get('provider_brand_id'):
            item['aliases'].add(term)
        else:
            item['provider_aliases'].add((str(row['provider_brand_id']), term))
    return tuple(
        CatalogTerm(
            item_id=item['item_id'],
            display_name=item['display_name'],
            aliases=tuple(sorted(item['aliases'])),
            provider_aliases=tuple(sorted(item['provider_aliases'])),
        )
        for item in items.values()
    )


def _safe_https_source_url(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    parsed = urlparse(value)
    if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password:
        return None
    return parsed._replace(query='', fragment='').geturl()


def _lexical_evidence(query: str, matched_term: str) -> dict[str, Any]:
    """Expose token overlap as reviewer evidence, never as clinical confidence."""

    query_tokens = {
        token for token in normalize_text(query).split()
        if len(token) >= 3 and token not in _TRIAGE_STOPWORDS
    }
    term_tokens = {
        token for token in normalize_text(matched_term).split()
        if len(token) >= 3 and token not in _TRIAGE_STOPWORDS
    }
    if not query_tokens:
        return {"lexical_coverage": None, "unmatched_input_tokens": []}
    overlap = query_tokens & term_tokens
    return {
        "lexical_coverage": round(len(overlap) / len(query_tokens), 3),
        "unmatched_input_tokens": sorted(query_tokens - term_tokens),
    }


def _clinical_modifier_evidence(query: str, matched_term: str) -> dict[str, list[str]]:
    """Flag explicit attribute conflicts or missing specificity for reviewers."""

    query_tokens = set(normalize_text(query).split())
    term_tokens = set(normalize_text(matched_term).split())
    conflicts: list[str] = []
    missing: list[str] = []

    query_modalities = {_MODALITY_VALUES[token] for token in query_tokens if token in _MODALITY_VALUES}
    term_modalities = {_MODALITY_VALUES[token] for token in term_tokens if token in _MODALITY_VALUES}
    for query_modality in sorted(query_modalities):
        if term_modalities and query_modality not in term_modalities:
            conflicts.append(f"modality:{query_modality}!={'|'.join(sorted(term_modalities))}")
        elif not term_modalities:
            missing.append(f"modality:{query_modality}")

    for dimension, values in _ATTRIBUTE_VALUES.items():
        query_values = {values[token] for token in query_tokens if token in values}
        term_values = {values[token] for token in term_tokens if token in values}
        # ``Biometría hemática completa`` is commonly the provider's full name
        # for the same routine test; do not require a redundant catalog qualifier.
        # An explicit opposing scope (e.g. completa vs. básica) still conflicts.
        if (
            dimension == "panel_scope"
            and query_values == {"complete"}
            and not term_values
            and {"biometria", "hematica"}.issubset(query_tokens)
        ):
            query_values.clear()
        if query_values and term_values and not query_values.intersection(term_values):
            for query_value in sorted(query_values):
                conflicts.append(
                    f"{dimension}:{query_value}!={'|'.join(sorted(term_values))}"
                )
        elif query_values:
            for query_value in sorted(query_values - term_values):
                missing.append(f"{dimension}:{query_value}")

    query_anatomy = _anatomy_values(query)
    term_anatomy = _anatomy_values(matched_term)
    for query_site in sorted(query_anatomy):
        if term_anatomy and query_site not in term_anatomy:
            conflicts.append(f"anatomy:{query_site}!={'|'.join(sorted(term_anatomy))}")
        elif not term_anatomy:
            missing.append(f"anatomy:{query_site}")

    query_trimesters = _pregnancy_trimesters(query)
    term_trimesters = _pregnancy_trimesters(matched_term)
    for query_trimester in sorted(query_trimesters):
        if term_trimesters and query_trimester not in term_trimesters:
            conflicts.append(
                f"trimester:{query_trimester}!={'|'.join(sorted(term_trimesters))}"
            )
        elif not term_trimesters:
            missing.append(f"trimester:{query_trimester}")

    query_contrasts = _contrast_values(query_tokens)
    term_contrasts = _contrast_values(term_tokens)
    if query_contrasts and term_contrasts and not query_contrasts.intersection(term_contrasts):
        conflicts.append(f"contrast:{'|'.join(sorted(query_contrasts))}!={'|'.join(sorted(term_contrasts))}")
    elif query_contrasts:
        missing.extend(f"contrast:{value}" for value in sorted(query_contrasts - term_contrasts))

    return {
        "clinical_modifier_conflicts": conflicts,
        "specificity_not_preserved": missing,
    }


def _pregnancy_trimesters(value: str) -> set[str]:
    """Read explicit trimester numbers only when introduced by a trimester marker."""

    values = {"i": "1", "1": "1", "primero": "1", "ii": "2", "2": "2",
              "segundo": "2", "iii": "3", "3": "3", "tercero": "3",
              "iv": "4", "4": "4", "cuarto": "4"}
    tokens = normalize_text(value).split()
    trimesters: set[str] = set()
    index = 0
    while index < len(tokens):
        if tokens[index] not in {"trim", "trimestre", "trimestres"}:
            index += 1
            continue
        index += 1
        while index < len(tokens):
            token = tokens[index]
            if token in values:
                trimesters.add(values[token])
                index += 1
            elif token == "y":
                index += 1
            else:
                break
    return trimesters


def _contrast_values(tokens: set[str]) -> set[str]:
    values: set[str] = set()
    if "simple" in tokens or ("sin" in tokens and "contraste" in tokens):
        values.add("without")
    # ``sin contraste`` must not also become a positive contrast claim just
    # because it contains the word ``contraste``. Preserve both components only
    # when the label explicitly requests both (e.g. simple y contrastada).
    if tokens.intersection({"contrastada", "contrastado"}) or (
        "contraste" in tokens and ("sin" not in tokens or "con" in tokens)
    ):
        values.add("with")
    return values


def _anatomy_values(value: str) -> set[str]:
    """Find explicit body sites, excluding the radiology phrase ``de pie``."""

    tokens = normalize_text(value).split()
    sites: set[str] = set()
    for index, token in enumerate(tokens):
        if (
            token == "pie"
            and index > 1
            and tokens[index - 1] == "de"
            and tokens[index - 2] in _POSTURAL_DE_PIE_SITES
        ):
            continue
        site = _ANATOMY_VALUES.get(token)
        if site:
            sites.add(site)
    return sites


def _core_lexical_evidence(query: str, matched_term: str) -> dict[str, Any]:
    """Measure shared analyte/site terms after removing generic qualifiers."""

    query_tokens = {
        token for token in normalize_text(query).split()
        if len(token) >= 3 and token not in _CORE_GENERIC_TOKENS
    }
    term_tokens = {
        token for token in normalize_text(matched_term).split()
        if len(token) >= 3 and token not in _CORE_GENERIC_TOKENS
    }
    if not query_tokens:
        return {"core_lexical_coverage": None, "unmatched_core_terms": []}
    overlap = query_tokens & term_tokens
    return {
        "core_lexical_coverage": round(len(overlap) / len(query_tokens), 3),
        "unmatched_core_terms": sorted(query_tokens - term_tokens),
    }


def _article_fold(value: str) -> tuple[str, ...]:
    """Remove only standalone Spanish articles, retaining token order and negation."""

    return tuple(
        token for token in normalize_text(value).split()
        if token not in _ARTICLE_TOKENS
    )


def _article_fold_candidates(
    label: str,
    catalog: tuple[CatalogTerm, ...],
    provider_brand_id: str | None,
) -> list[NormalizationCandidate]:
    """Find unique-string candidates differing only by standalone articles."""

    folded_label = _article_fold(label)
    if not folded_label:
        return []
    matches: dict[str, str] = {}
    for item in catalog:
        terms = [item.display_name, *item.aliases]
        if provider_brand_id:
            terms.extend(
                alias for brand_id, alias in item.provider_aliases
                if brand_id == provider_brand_id
            )
        for term in terms:
            folded_term = _article_fold(term)
            if folded_term == folded_label and normalize_text(term) != normalize_text(label):
                matches.setdefault(item.item_id, term)
    return [
        NormalizationCandidate(
            item_id=item.item_id,
            display_name=item.display_name,
            score=1.0,
            method="article_fold",
            matched_term=matches[item.item_id],
        )
        for item in catalog if item.item_id in matches
    ]


def classify_group(group: dict[str, Any], catalog: tuple[CatalogTerm, ...]) -> dict[str, Any]:
    """Classify without turning fuzzy ranking into a clinical decision."""

    brand = group.get('provider_brand_id')
    label = str(group['normalized_input'])
    resolver = CatalogResolver(max_candidates=5)
    decision = resolver.resolve(label, catalog, provider_brand_id=str(brand) if brand else None)
    # Keep lexical rank separate from clinical adjudication. Candidates with an
    # explicit attribute conflict are retained as rejected evidence, not offered
    # as plausible equivalences.
    candidates_by_id = {candidate.item_id: candidate for candidate in decision.candidates}
    for candidate in _article_fold_candidates(
        label, catalog, str(brand) if brand else None
    ):
        current = candidates_by_id.get(candidate.item_id)
        if current is None or current.score < 1.0 or current.method not in {
            "exact", "alias", "provider_alias"
        }:
            candidates_by_id[candidate.item_id] = candidate

    useful_candidates = []
    rejected_candidates = []
    candidate_details: dict[str, dict[str, Any]] = {}
    for candidate in candidates_by_id.values():
        if candidate.score < 0.55:
            continue
        lexical = _lexical_evidence(label, candidate.matched_term)
        canonical_attributes = _clinical_modifier_evidence(label, candidate.display_name)
        matched_term_attributes = _clinical_modifier_evidence(label, candidate.matched_term)
        clinical_conflicts = sorted(set(
            canonical_attributes['clinical_modifier_conflicts']
            + matched_term_attributes['clinical_modifier_conflicts']
        ))
        core_lexical = _core_lexical_evidence(label, candidate.matched_term)
        detail = {
            'item_id': candidate.item_id,
            'name': candidate.display_name,
            'matched_term': candidate.matched_term,
            'score': candidate.score,
            'method': candidate.method,
            **lexical,
            **core_lexical,
            'clinical_modifier_conflicts': clinical_conflicts,
            'specificity_not_preserved': canonical_attributes['specificity_not_preserved'],
            'matched_term_specificity_not_preserved': matched_term_attributes['specificity_not_preserved'],
        }
        missing_specificity = sorted(set(
            canonical_attributes['specificity_not_preserved']
            + matched_term_attributes['specificity_not_preserved']
        ))
        if clinical_conflicts:
            rejected_candidates.append({
                **detail,
                'rejection_reason': 'explicit_clinical_attribute_conflict',
            })
            continue
        if (
            candidate.method != 'rules'
            and core_lexical['core_lexical_coverage'] == 0
        ):
            rejected_candidates.append({
                **detail,
                'rejection_reason': 'no_shared_core_terms',
            })
            continue
        if missing_specificity:
            rejected_candidates.append({
                **detail,
                'rejection_reason': 'missing_explicit_clinical_specificity',
            })
            continue
        useful_candidates.append(candidate)
        candidate_details[candidate.item_id] = detail
    exact_ids = sorted({candidate.item_id for candidate in useful_candidates if candidate.score == 1.0})
    count = int(group['occurrence_count'])
    source_identifier_count = int(group.get('distinct_sku_count') or 0)
    policy = group.get('source_usage_policy_status')
    provider_official = group.get('source_type') in {'provider_official', 'official_api'}
    # Source classification and HTTPS are separate triage signals. Neither
    # proves that the URL host is owned by the provider or that use is licensed.
    safe_source_url = _safe_https_source_url(group.get('source_url'))
    holds: list[str] = []
    if policy != 'approved':
        holds.append('source_policy_not_approved')
    if not provider_official:
        holds.append('provider_official_source_unverified')
    if not safe_source_url:
        holds.append('https_source_missing')

    if len(exact_ids) > 1:
        outcome = 'exact_collision_review'
    elif len(exact_ids) == 1 and any(
        candidate.item_id in exact_ids and candidate.method == 'article_fold'
        for candidate in useful_candidates
    ):
        outcome = 'deterministic_article_fold_preview'
    elif len(exact_ids) == 1:
        outcome = 'approved_term_reprocess_preview'
    elif useful_candidates:
        outcome = 'catalog_gap_with_suggestions'
    else:
        outcome = 'catalog_gap'

    if outcome == 'exact_collision_review':
        review_action = 'review_exact_collision'
    elif holds:
        review_action = 'review_source_policy'
    elif len(exact_ids) == 1 and outcome == 'deterministic_article_fold_preview':
        review_action = 'preview_deterministic_article_fold'
    elif len(exact_ids) == 1:
        review_action = 'preview_exact_reprocess'
    elif useful_candidates:
        review_action = 'review_clinical_equivalence'
    elif rejected_candidates:
        review_action = 'catalog_gap_after_rejecting_unsafe_candidates'
    else:
        review_action = 'catalog_gap_or_new_concept_review'

    # This is an administrative work cluster, not a draft, clinical identity or
    # publication key. Many raw IDs are one-off source locators rather than SKUs.
    cluster_scope = str(brand or group.get('source_name') or 'unattributed')
    review_cluster_key = hashlib.sha256(f"{cluster_scope}|{label}".encode('utf-8')).hexdigest()[:20]

    return {
        'provider_brand_id': brand,
        'label': label,
        'occurrences': count,
        'outcome': outcome,
        'review_action': review_action,
        'unique_exact_candidate': len(exact_ids) == 1,
        'exact_candidate_methods': sorted({
            candidate.method for candidate in useful_candidates
            if candidate.item_id in exact_ids and candidate.score == 1.0
        }),
        'holds': holds,
        'rejected_candidates': rejected_candidates,
        'review_cluster_key': review_cluster_key,
        'source_identifier_count': source_identifier_count,
        'representative_run_id': group.get('representative_run_id'),
        'source_name': group.get('source_name'),
        'source_url': safe_source_url,
        'representative_source_identifier': group.get('provider_sku'),
        'suggestions': [candidate_details[candidate.item_id] for candidate in useful_candidates],
    }


def triage(groups: Iterable[dict[str, Any]], terms: Iterable[dict[str, Any]]) -> dict[str, Any]:
    catalog = build_catalog(terms)
    entries = [classify_group(group, catalog) for group in groups]
    outcomes = Counter(entry['outcome'] for entry in entries)
    hold_counts: Counter[str] = Counter(
        hold for entry in entries for hold in entry['holds']
    )
    occurrence_counts: defaultdict[str, int] = defaultdict(int)
    for entry in entries:
        occurrence_counts[entry['outcome']] += entry['occurrences']
    return {
        'mode': 'read_only_suggestions',
        'group_count': len(entries),
        'represented_rows': sum(entry['occurrences'] for entry in entries),
        'catalog_item_count': len(catalog),
        'outcomes': dict(sorted(outcomes.items())),
        'represented_rows_by_outcome': dict(sorted(occurrence_counts.items())),
        'holds': dict(sorted(hold_counts.items())),
        'groups': entries,
    }
