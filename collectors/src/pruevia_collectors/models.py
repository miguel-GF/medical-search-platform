from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Mapping


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def isoformat(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


@dataclass(frozen=True)
class SourceSpec:
    """Metadata used to identify and govern a source endpoint."""

    source_key: str
    name: str
    source_type: str
    usage_policy_status: str = "review_required"
    expected_min_records: int | None = None
    expected_max_records: int | None = None
    max_negative_deviation_pct: float = 50.0
    endpoint_type: str = "other"
    endpoint_url: str | None = None
    parser_version: str = "0.1.0"


@dataclass(frozen=True)
class Observation:
    """A candidate business fact derived from one raw source record."""

    entity_type: str
    attribute_name: str | None
    observed_value: Any
    entity_id: str | None = None
    confidence: float = 1.0
    status: str = "candidate"

    def __post_init__(self) -> None:
        if not self.entity_type.strip():
            raise ValueError("observation entity_type cannot be empty")
        if not 0 <= self.confidence <= 1:
            raise ValueError("observation confidence must be between 0 and 1")


@dataclass(frozen=True)
class SourceRecord:
    """A parsed source record that is safe to serialize as RAW evidence."""

    source_key: str
    record_type: str
    payload: Mapping[str, Any]
    external_record_id: str | None = None
    source_url: str | None = None
    observations: tuple[Observation, ...] = field(default_factory=tuple)
    observed_at: datetime = field(default_factory=utc_now)

    def __post_init__(self) -> None:
        if not self.source_key.strip():
            raise ValueError("source_key cannot be empty")
        if not self.record_type.strip():
            raise ValueError("record_type cannot be empty")
        if not isinstance(self.payload, Mapping):
            raise TypeError("payload must be a mapping")


@dataclass(frozen=True)
class RunSummary:
    source_key: str
    run_id: str
    status: str
    records_received: int
    records_valid: int
    records_rejected: int
    records_published: int
    previous_success_count: int | None
    deviation_percentage: float | None
    artifact_directory: str
    errors: tuple[str, ...] = field(default_factory=tuple)
