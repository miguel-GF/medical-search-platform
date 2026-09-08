from __future__ import annotations

import time
import json
import re
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from math import isfinite
from typing import Any, Iterable, Mapping, Sequence
from urllib.parse import quote, urlparse

import httpx

from ..models import Observation, SourceRecord, SourceSpec
from .http import bounded_response_bytes, request_with_same_host_redirects
from .public_transport import PublicAddressTransport


RUIZ_BASE_URL = "https://laboratoriosruiz.com"
RUIZ_GENERAL_HOME_URL = f"{RUIZ_BASE_URL}/general-home"
MAX_RUIZ_ATTEMPTS = 5
MAX_RUIZ_TIMEOUT_SECONDS = 120.0
MAX_RUIZ_DELAY_SECONDS = 60.0
MAX_RUIZ_RECORDS = 10_000
MAX_RUIZ_PER_DEPARTMENT = 1_000
MAX_RUIZ_DEPARTMENTS = 500
MAX_RUIZ_LOCATIONS = 1_000
MAX_RUIZ_SLUG_CHARS = 128


@dataclass(frozen=True)
class RuizDepartment:
    department_id: int
    title: str
    slug: str


class RuizClient:
    def __init__(
        self,
        *,
        base_url: str = RUIZ_BASE_URL,
        timeout_seconds: float = 30.0,
        max_attempts: int = 3,
        retry_backoff_seconds: float = 1.5,
        client: httpx.Client | None = None,
    ) -> None:
        parsed_base = urlparse(base_url.rstrip("/"))
        try:
            port = parsed_base.port
        except ValueError as error:
            raise ValueError("Ruiz base URL must use a valid HTTPS URL") from error
        if (
            parsed_base.scheme != "https"
            or not parsed_base.hostname
            or parsed_base.username
            or parsed_base.password
            or parsed_base.query
            or parsed_base.fragment
            or parsed_base.path not in ("", "/")
            or port not in (None, 443)
        ):
            raise ValueError("Ruiz base URL must be an HTTPS origin without credentials")
        if not isinstance(max_attempts, int) or isinstance(max_attempts, bool) or not 1 <= max_attempts <= MAX_RUIZ_ATTEMPTS:
            raise ValueError("max_attempts must be between 1 and 5")
        if not isinstance(timeout_seconds, (int, float)) or isinstance(timeout_seconds, bool) or not isfinite(float(timeout_seconds)) or not 0 < timeout_seconds <= MAX_RUIZ_TIMEOUT_SECONDS:
            raise ValueError("timeout_seconds must be between 0 and 120")
        if not isinstance(retry_backoff_seconds, (int, float)) or isinstance(retry_backoff_seconds, bool) or not isfinite(float(retry_backoff_seconds)) or not 0 <= retry_backoff_seconds <= MAX_RUIZ_DELAY_SECONDS:
            raise ValueError("retry_backoff_seconds must be between 0 and 60")
        self.base_url = base_url.rstrip("/")
        self.timeout_seconds = timeout_seconds
        self.max_attempts = max_attempts
        self.retry_backoff_seconds = retry_backoff_seconds
        self._owns_client = client is None
        self._client = client or httpx.Client(timeout=timeout_seconds, follow_redirects=False, trust_env=False, transport=PublicAddressTransport())

    def close(self) -> None:
        if self._owns_client:
            self._client.close()

    def fetch_home(self) -> Mapping[str, Any]:
        return self._get_json("/general-home")

    def fetch_departments(self, department_slug: str) -> list[Mapping[str, Any]]:
        if not isinstance(department_slug, str) or len(department_slug) > MAX_RUIZ_SLUG_CHARS or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", department_slug):
            raise ValueError("Ruiz department slug must be a bounded safe path segment")
        payload = self._get_json(f"/departments-studies/{quote(department_slug, safe='')}")
        rows = payload.get("departments", [])
        if not isinstance(rows, list):
            raise ValueError(f"Ruiz department payload is not a list: {department_slug}")
        return [row for row in rows if isinstance(row, Mapping)]

    def _get_json(self, path: str) -> Mapping[str, Any]:
        url = f"{self.base_url}{path}"
        for attempt in range(1, self.max_attempts + 1):
            try:
                response = request_with_same_host_redirects(
                    self._client.get,
                    url,
                    allowed_url=self.base_url,
                    max_redirects=5,
                    headers={"Accept": "application/json", "User-Agent": "PrueviaCollector/0.1"},
                )
                response.raise_for_status()
                try:
                    payload = json.loads(bounded_response_bytes(response, max_bytes=2 * 1024 * 1024))
                    if not isinstance(payload, Mapping):
                        raise ValueError(f"Ruiz response must be an object: {path}")
                    return payload
                finally:
                    response.close()
            except (httpx.HTTPStatusError, httpx.RequestError, RecursionError):
                if attempt == self.max_attempts:
                    raise
                time.sleep(self.retry_backoff_seconds * attempt)
        raise RuntimeError("unreachable")


class RuizAdapter:
    source = SourceSpec(
        source_key="ruiz_puebla",
        name="Laboratorios Ruiz — Puebla",
        source_type="provider_official",
        usage_policy_status="review_required",
        endpoint_type="api",
        endpoint_url=RUIZ_GENERAL_HOME_URL,
    )

    def __init__(
        self,
        client: RuizClient,
        *,
        max_records: int = 200,
        per_department_limit: int = 20,
        zone_id: int = 4,
    ) -> None:
        if not isinstance(max_records, int) or isinstance(max_records, bool) or not 1 <= max_records <= MAX_RUIZ_RECORDS:
            raise ValueError("max_records must be between 1 and 10000")
        if not isinstance(per_department_limit, int) or isinstance(per_department_limit, bool) or not 1 <= per_department_limit <= MAX_RUIZ_PER_DEPARTMENT:
            raise ValueError("per_department_limit must be between 1 and 1000")
        self.client = client
        self.max_records = max_records
        self.per_department_limit = per_department_limit
        self.zone_id = zone_id

    def collect(self) -> Iterable[SourceRecord]:
        home = self.client.fetch_home()
        positions = home.get("pos", []) if isinstance(home.get("pos"), list) else []
        if len(positions) > MAX_RUIZ_LOCATIONS:
            raise ValueError("Ruiz location catalog exceeds the safety limit")
        for row in positions:
            if _is_active_for_zone(row, self.zone_id):
                yield ruiz_location_to_record(row, base_url=self.client.base_url)
        departments = _decode_departments(home.get("departments"))
        emitted = 0
        for department in departments:
            rows = self.client.fetch_departments(department.slug)
            selected = 0
            for row in rows:
                if emitted >= self.max_records:
                    return
                if not _is_active_for_zone(row, self.zone_id):
                    continue
                yield ruiz_row_to_record(row, department=department, base_url=self.client.base_url)
                emitted += 1
                selected += 1
                if selected >= self.per_department_limit:
                    break


def ruiz_row_to_record(
    row: Mapping[str, Any], *, department: RuizDepartment, base_url: str = RUIZ_BASE_URL
) -> SourceRecord:
    title = str(row.get("title") or "").strip()
    slug = str(row.get("url") or "").strip()
    external_id = _first_value(row, "id", "synonymous", "url")
    if not title or not slug or external_id in (None, ""):
        raise ValueError("Ruiz study requires title, url and stable id")
    product_url = f"{base_url}/estudios/{quote(department.slug, safe='')}/{quote(slug, safe='')}"
    prices = _prices(row)
    payload = {
        "provider_brand": "Laboratorios Ruiz",
        "market": "Puebla",
        "department": department.title,
        "department_slug": department.slug,
        "provider_display_name": title,
        "provider_sku": str(row.get("synonymous") or "").strip() or None,
        "provider_external_id": str(external_id),
        "product_url": product_url,
        "prices": prices,
        "indications": row.get("indications"),
        "delivery_time": row.get("delivery_time"),
        "updated_at": row.get("updated_at"),
        "zone_id": row.get("zone_id"),
    }
    observations = [
        Observation(entity_type="offer", attribute_name="provider_display_name", observed_value=title),
        Observation(entity_type="offer", attribute_name="product_url", observed_value=product_url),
        Observation(entity_type="offer", attribute_name="department", observed_value=department.title),
        Observation(entity_type="offer", attribute_name="provider_external_id", observed_value=str(external_id)),
    ]
    if payload["provider_sku"]:
        observations.append(Observation(entity_type="offer", attribute_name="provider_sku", observed_value=payload["provider_sku"]))
    if prices:
        observations.append(Observation(entity_type="price", attribute_name="prices", observed_value=prices))
    return SourceRecord(
        source_key="ruiz_puebla",
        record_type="provider_offer_price",
        external_record_id=str(external_id),
        source_url=product_url,
        payload=payload,
        observations=tuple(observations),
    )


def ruiz_location_to_record(row: Mapping[str, Any], *, base_url: str = RUIZ_BASE_URL) -> SourceRecord:
    name = str(row.get("title") or "").strip()
    external_id = _first_value(row, "id", "url")
    if not name or external_id in (None, ""):
        raise ValueError("Ruiz location requires title and stable id")
    coordinates = _coordinates(row.get("latitude"))
    location_url = f"{base_url}/sucursales/{quote(str(row.get('url') or external_id), safe='')}"
    payload = {
        "provider_brand": "Laboratorios Ruiz",
        "market": "Puebla",
        "provider_display_name": name,
        "provider_external_id": str(external_id),
        "location_url": location_url,
        "address_line_1": row.get("address"),
        "address_line_2": row.get("address2"),
        "locality_text": row.get("address3"),
        "postal_code": row.get("postal_code"),
        "phone": row.get("phone"),
        "coordinates": coordinates,
        "services": row.get("services"),
        "hours": {
            "monday_friday": row.get("schedules_monday_friday"),
            "saturday": row.get("schedules_saturday"),
            "sunday": row.get("schedules_sunday"),
        },
        "updated_at": row.get("updated_at"),
    }
    observations = [
        Observation(entity_type="provider_location", attribute_name="provider_display_name", observed_value=name),
        Observation(entity_type="provider_location", attribute_name="provider_external_id", observed_value=str(external_id)),
        Observation(entity_type="provider_location", attribute_name="address", observed_value=payload["address_line_1"]),
        Observation(entity_type="provider_location", attribute_name="coordinates", observed_value=coordinates),
        Observation(entity_type="provider_location", attribute_name="hours", observed_value=payload["hours"]),
    ]
    return SourceRecord(
        source_key="ruiz_puebla",
        record_type="provider_location_discovered",
        external_record_id=str(external_id),
        source_url=location_url,
        payload=payload,
        observations=tuple(observations),
    )


def _decode_departments(value: Any) -> tuple[RuizDepartment, ...]:
    if not isinstance(value, list):
        raise ValueError("Ruiz home payload has no departments list")
    result: list[RuizDepartment] = []
    if len(value) > MAX_RUIZ_DEPARTMENTS:
        raise ValueError("Ruiz department catalog exceeds the safety limit")
    for row in value:
        if not isinstance(row, Mapping):
            continue
        department_id = row.get("id")
        title = str(row.get("title") or "").strip()
        slug = str(row.get("url") or "").strip()
        if department_id is None or not title or not slug:
            continue
        result.append(RuizDepartment(int(department_id), title, slug))
    return tuple(result)


def _is_active_for_zone(row: Mapping[str, Any], zone_id: int) -> bool:
    active = row.get("active")
    if active not in (1, "1", True, None):
        return False
    row_zone = row.get("zone_id")
    return row_zone in (None, zone_id, str(zone_id))


def _coordinates(value: Any) -> dict[str, float] | None:
    if not isinstance(value, str):
        return None
    parts = [part.strip() for part in value.split(",")]
    if len(parts) != 2:
        return None
    try:
        latitude, longitude = float(parts[0]), float(parts[1])
    except ValueError:
        return None
    if not -90 <= latitude <= 90 or not -180 <= longitude <= 180:
        return None
    return {"latitude": latitude, "longitude": longitude}


def _prices(row: Mapping[str, Any]) -> dict[str, int]:
    names = (
        ("regular", "price_list"),
        ("blue_card", "blue_card"),
        ("gold_card", "gold_card"),
        ("promotion", "price_promotion"),
        ("prepaid", "prepaid_price"),
    )
    result: dict[str, int] = {}
    for price_type, key in names:
        value = row.get(key)
        minor = _to_minor_units(value)
        if minor is not None and minor > 0:
            result[price_type] = minor
    return result


def _to_minor_units(value: Any) -> int | None:
    if value in (None, "", "N/A", "NA"):
        return None
    try:
        amount = Decimal(str(value).replace(",", "")).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    except (InvalidOperation, ValueError):
        return None
    if not amount.is_finite() or amount <= 0 or amount > Decimal(10_000_000):
        return None
    return int(amount * 100)


def _first_value(row: Mapping[str, Any], *keys: str) -> Any:
    for key in keys:
        value = row.get(key)
        if value not in (None, ""):
            return value
    return None
