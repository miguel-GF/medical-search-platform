"""Reusable ingestion primitives for Pruevia collectors."""

from .models import Observation, RunSummary, SourceRecord, SourceSpec
from .normalization import (
    CatalogResolver,
    CatalogTerm,
    NormalizationCandidate,
    NormalizationDecision,
    normalize_text,
    trigram_similarity,
)
from .pipeline import Collector, CollectorRunner

__all__ = [
    "Collector",
    "CollectorRunner",
    "Observation",
    "RunSummary",
    "SourceRecord",
    "SourceSpec",
    "CatalogResolver",
    "CatalogTerm",
    "NormalizationCandidate",
    "NormalizationDecision",
    "normalize_text",
    "trigram_similarity",
]
