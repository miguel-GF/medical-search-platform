"""Deterministic catalog-name normalization for collected provider records.

This module deliberately keeps fuzzy matches as candidates. A provider label that
looks similar to a catalog item is not enough evidence to assert clinical
equivalence, so only exact canonical names and approved aliases can be resolved
automatically in V1.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field
from typing import Iterable


NORMALIZER_VERSION = "normalizer-v1"
_NON_ASCII_ALNUM = re.compile(r"[^a-z0-9]+")
_WHITESPACE = re.compile(r"\s+")
_STOPWORDS = {
    "a", "al", "como", "con", "de", "del", "desde", "el", "en", "entre",
    "esta", "este", "estos", "la", "las", "los", "para", "por", "que", "sin",
    "sobre", "sus", "un", "una", "uno", "y",
}


def normalize_text(value: str | None) -> str:
    """Return the same accent/punctuation-insensitive form used by ``core.normalized_text``."""

    if not value:
        return ""
    decomposed = unicodedata.normalize("NFKD", value.casefold())
    without_marks = "".join(char for char in decomposed if not unicodedata.combining(char))
    return _WHITESPACE.sub(" ", _NON_ASCII_ALNUM.sub(" ", without_marks)).strip()


@dataclass(frozen=True)
class CatalogTerm:
    """Canonical catalog item plus global and provider-specific names."""

    item_id: str
    display_name: str
    aliases: tuple[str, ...] = field(default_factory=tuple)
    provider_aliases: tuple[tuple[str, str], ...] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        if not self.item_id.strip():
            raise ValueError("catalog term item_id cannot be empty")
        if not self.display_name.strip():
            raise ValueError("catalog term display_name cannot be empty")


@dataclass(frozen=True)
class NormalizationCandidate:
    item_id: str
    display_name: str
    score: float
    method: str
    matched_term: str


@dataclass(frozen=True)
class NormalizationDecision:
    raw_text: str
    normalized_input: str
    status: str
    selected_item_id: str | None
    candidates: tuple[NormalizationCandidate, ...]
    engine_version: str = NORMALIZER_VERSION


class CatalogResolver:
    """Resolve provider labels without silently asserting fuzzy equivalence."""

    def __init__(self, *, candidate_threshold: float = 0.25, max_candidates: int = 5) -> None:
        if not 0 <= candidate_threshold <= 1:
            raise ValueError("candidate_threshold must be between 0 and 1")
        if max_candidates < 1:
            raise ValueError("max_candidates must be positive")
        self.candidate_threshold = candidate_threshold
        self.max_candidates = max_candidates

    def resolve(
        self,
        raw_text: str,
        terms: Iterable[CatalogTerm],
        *,
        provider_brand_id: str | None = None,
    ) -> NormalizationDecision:
        normalized_input = normalize_text(raw_text)
        if not normalized_input:
            return NormalizationDecision(raw_text, normalized_input, "no_match", None, ())

        candidates: dict[str, NormalizationCandidate] = {}
        for term in terms:
            self._consider(candidates, term, normalized_input, term.display_name, "exact")
            for alias in term.aliases:
                self._consider(candidates, term, normalized_input, alias, "alias")
            if provider_brand_id:
                for alias_brand_id, alias in term.provider_aliases:
                    if alias_brand_id == provider_brand_id:
                        self._consider(candidates, term, normalized_input, alias, "provider_alias")

        ranked = sorted(candidates.values(), key=lambda item: (-item.score, item.item_id))
        ranked = tuple(ranked[: self.max_candidates])
        if not ranked or ranked[0].score < self.candidate_threshold:
            return NormalizationDecision(raw_text, normalized_input, "no_match", None, ranked)

        top = ranked[0]
        if top.method in {"exact", "alias", "provider_alias"}:
            return NormalizationDecision(raw_text, normalized_input, "resolved", top.item_id, ranked)
        return NormalizationDecision(raw_text, normalized_input, "ambiguous", None, ranked)

    def _consider(
        self,
        candidates: dict[str, NormalizationCandidate],
        term: CatalogTerm,
        normalized_input: str,
        matched_term: str,
        exact_method: str,
    ) -> None:
        normalized_term = normalize_text(matched_term)
        if not normalized_term:
            return
        if normalized_term == normalized_input:
            candidate = NormalizationCandidate(term.item_id, term.display_name, 1.0, exact_method, matched_term)
        else:
            # Trigram similarity alone can be inflated by a shared short
            # fragment.  Require at least one meaningful query token to be
            # represented in the candidate term before exposing fuzzy output.
            # Exact/approved aliases remain governed by the whole-string rule
            # above, so extra query words cannot be silently discarded.
            if exact_method in {"exact", "alias", "provider_alias"} and not _has_meaningful_token_overlap(normalized_input, normalized_term):
                return
            score = trigram_similarity(normalized_input, normalized_term)
            candidate = NormalizationCandidate(term.item_id, term.display_name, round(score, 6), "trigram", matched_term)
        current = candidates.get(term.item_id)
        if current is None or (candidate.score, _method_rank(candidate.method)) > (
            current.score,
            _method_rank(current.method),
        ):
            candidates[term.item_id] = candidate


def _method_rank(method: str) -> int:
    return {"exact": 4, "provider_alias": 3, "alias": 2, "trigram": 1}.get(method, 0)


def trigram_similarity(left: str, right: str) -> float:
    """Compute a small, dependency-free Jaccard similarity over character trigrams."""

    left_grams = _trigrams(normalize_text(left))
    right_grams = _trigrams(normalize_text(right))
    if not left_grams or not right_grams:
        return 0.0
    return len(left_grams & right_grams) / len(left_grams | right_grams)


def _trigrams(value: str) -> set[str]:
    if not value:
        return set()
    if len(value) < 3:
        return {value}
    return {value[index : index + 3] for index in range(len(value) - 2)}


def _has_meaningful_token_overlap(left: str, right: str) -> bool:
    left_tokens = {token for token in left.split() if len(token) >= 3 and token not in _STOPWORDS}
    right_tokens = {token for token in right.split() if len(token) >= 3 and token not in _STOPWORDS}
    if not left_tokens or not right_tokens:
        return True
    return any(
        left_token == right_token
        or left_token.startswith(right_token)
        or right_token.startswith(left_token)
        for left_token in left_tokens
        for right_token in right_tokens
    )
