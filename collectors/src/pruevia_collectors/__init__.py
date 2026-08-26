"""Reusable ingestion primitives for Pruevia collectors."""

from .models import Observation, RunSummary, SourceRecord, SourceSpec
from .pipeline import Collector, CollectorRunner

__all__ = [
    "Collector",
    "CollectorRunner",
    "Observation",
    "RunSummary",
    "SourceRecord",
    "SourceSpec",
]
