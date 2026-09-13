"""Collector for the public Dr. Simi clinical-laboratory branch feed.

The site exposes a static, public JSON map for branch information.  This
adapter deliberately consumes only that file: it does not call appointment,
patient, result, promotion, or account endpoints.  Branches are evidence
only; no clinical study or price is inferred from a branch listing.
"""

from __future__ import annotations

import json
import re
import ssl
import unicodedata
from collections.abc import Iterable, Mapping
from html import unescape
from math import isfinite
from typing import Any
from urllib.parse import urlparse

import certifi
import httpx

try:
    import truststore
except ImportError:  # pragma: no cover - dependency is installed in supported environments
    truststore = None  # type: ignore[assignment]

from ..models import Observation, SourceRecord, SourceSpec
from .http import bounded_response_bytes, request_with_same_host_redirects
from .public_transport import PublicAddressTransport


DR_SIMI_ORIGIN = "https://www.ssdrsimi.com.mx"
DR_SIMI_BRANCHES_URL = f"{DR_SIMI_ORIGIN}/sucursales"
DR_SIMI_BRANCHES_JSON_URL = f"{DR_SIMI_ORIGIN}/assets/data/sucursalesMAPA.json"
DR_SIMI_CAMPAIGN_URL = f"{DR_SIMI_ORIGIN}/campana/colposcopia-permanente"
MAX_DR_SIMI_BRANCHES = 100
MAX_DR_SIMI_RESPONSE_BYTES = 512 * 1024
MAX_DR_SIMI_HTML_BYTES = 1 * 1024 * 1024
MAX_DR_SIMI_TEXT_CHARS = 4_000


def _ssl_context() -> ssl.SSLContext:
    if truststore is not None:
        return truststore.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    return ssl.create_default_context(cafile=certifi.where())


def _text(value: object, field: str, *, required: bool = False) -> str:
    result = " ".join(str(value or "").split()).strip()
    if len(result) > MAX_DR_SIMI_TEXT_CHARS:
        raise ValueError(f"{field} exceeds the text limit")
    if required and not result:
        raise ValueError(f"{field} is required")
    return result


def _normalize(value: object) -> str:
    folded = unicodedata.normalize("NFKD", _text(value, "value").casefold())
    plain = "".join(char for char in folded if not unicodedata.combining(char))
    return re.sub(r"[^a-z0-9]+", " ", plain).strip()


def _unit_id(value: object) -> str:
    result = _text(value, "unidad", required=True)
    if len(result) > 32 or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", result):
        raise ValueError("Dr. Simi unit id is invalid")
    return result


def _is_puebla(row: Mapping[str, Any]) -> bool:
    # The public feed has no explicit state field.  Requiring the city/state
    # pair avoids classifying a street named Puebla in another state.
    address = _normalize(row.get("direccion"))
    return bool(re.search(r"(?:^| )puebla puebla(?: |\.|$)", address))


def _address(value: object) -> dict[str, str]:
    text = _text(value, "direccion", required=True)
    parts = [part.strip() for part in text.rstrip(".").split(",") if part.strip()]
    postal_match = re.search(r"\bC\.?P\.?\s*(\d{5})\b", text, flags=re.IGNORECASE)
    result: dict[str, str] = {"text": text}
    if parts:
        result["street"] = parts[0]
    if len(parts) > 1:
        result["neighborhood"] = parts[1]
    if postal_match:
        result["postal_code"] = postal_match.group(1)
    if len(parts) >= 2:
        result["locality"] = "Puebla"
        result["state"] = "Puebla"
    return result


def _strip_html(value: str) -> str:
    return " ".join(re.sub(r"<[^>]+>", " ", unescape(value)).split())


def parse_campaign_branches(html: str) -> list[Mapping[str, Any]]:
    """Extract Puebla branch cards from a public campaign page.

    The page is server-rendered and links back to the public branch detail
    route.  We retain only cards whose address explicitly says Puebla,
    Puebla; other states are intentionally discarded.
    """

    if not isinstance(html, str) or len(html.encode("utf-8")) > MAX_DR_SIMI_HTML_BYTES:
        raise ValueError("Dr. Simi campaign page exceeds the safety limit")
    rows: list[Mapping[str, Any]] = []
    for match in re.finditer(
        r'<a[^>]+href=["\']/sucursales\?unidad=([A-Za-z0-9_-]+)["\'][^>]*>(.*?)</a>',
        html,
        flags=re.IGNORECASE | re.DOTALL,
    ):
        unit_id = _unit_id(match.group(1))
        body = _strip_html(match.group(2))
        title_match = re.search(r"^(PUEBLA[^ ]*(?:[ -][^ ]+)?)\s+", body, flags=re.IGNORECASE)
        address_match = re.search(r"((?:Av\.|Calle|Calz\.|Papagayo).{3,250}?Puebla,\s*Puebla\.\s*C\.?P\.?\s*\d{5})", body, flags=re.IGNORECASE)
        if address_match is None:
            address_match = re.search(r"((?:\d{1,3}\s+(?:Oriente|Poniente|Norte|Sur)).{3,250}?Puebla,\s*Puebla\.\s*C\.?P\.?\s*\d{5})", body, flags=re.IGNORECASE)
        if not title_match or not address_match:
            continue
        phone_match = re.search(r"\b(222[- ]?\d{3}[- ]?\d{4})\b", body)
        rows.append(
            {
                "sucursal": _text(title_match.group(1), "sucursal", required=True),
                "direccion": _text(address_match.group(1), "direccion", required=True),
                "telefono": phone_match.group(1) if phone_match else "",
                "unidad": unit_id,
                "_source_url": DR_SIMI_CAMPAIGN_URL,
            }
        )
    if len(rows) > MAX_DR_SIMI_BRANCHES:
        raise ValueError("Dr. Simi campaign branch count exceeds the safety limit")
    return rows


def parse_branch(row: Mapping[str, Any]) -> SourceRecord | None:
    if not _is_puebla(row):
        return None
    unit_id = _unit_id(row.get("unidad"))
    name = _text(row.get("sucursal"), "sucursal", required=True)
    address = _address(row.get("direccion"))
    hours = _text(row.get("horario"), "horario") or None
    phone = _text(row.get("telefono"), "telefono") or None
    payload = {
        "provider_brand": "Análisis Clínicos del Dr. Simi",
        "market": "Puebla",
        "provider_display_name": name,
        "provider_external_id": unit_id,
        "location_name": name,
        "location_url": DR_SIMI_BRANCHES_URL,
        "address": address,
        "coordinates": None,
        "phone": phone,
        "hours": hours,
        "claim_status": "candidate",
        "evidence_note": "Public branch feed; coordinates and current study catalog require separate verification.",
    }
    observations = (
        Observation(entity_type="provider_location", attribute_name="provider_display_name", observed_value=name, confidence=0.98),
        Observation(entity_type="provider_location", attribute_name="address", observed_value=address, confidence=0.96),
        Observation(entity_type="provider_location", attribute_name="hours", observed_value=hours, confidence=0.90),
        Observation(entity_type="provider_location", attribute_name="phone", observed_value=phone, confidence=0.90),
    )
    return SourceRecord(
        source_key="dr_simi_puebla",
        record_type="provider_location_discovered",
        external_record_id=unit_id,
        source_url=str(row.get("_source_url") or DR_SIMI_BRANCHES_JSON_URL),
        payload=payload,
        observations=observations,
    )


class DrSimiClient:
    """Bounded client for the official static branch JSON feed."""

    def __init__(
        self,
        *,
        branches_url: str = DR_SIMI_BRANCHES_JSON_URL,
        campaign_url: str = DR_SIMI_CAMPAIGN_URL,
        timeout_seconds: float = 30.0,
        client: httpx.Client | None = None,
    ) -> None:
        for field, url in (("branches_url", branches_url), ("campaign_url", campaign_url)):
            parsed = urlparse(url)
            if (
                parsed.scheme != "https"
                or parsed.hostname is None
                or parsed.username
                or parsed.password
                or parsed.port not in (None, 443)
                or parsed.query
                or parsed.fragment
            ):
                raise ValueError(f"Dr. Simi {field} must be an HTTPS URL without credentials or query parameters")
        if urlparse(branches_url).hostname.casefold() != urlparse(campaign_url).hostname.casefold():
            raise ValueError("Dr. Simi branch sources must share the official host")
        if not 0 < timeout_seconds <= 120 or not isfinite(float(timeout_seconds)):
            raise ValueError("timeout_seconds must be between 0 and 120")
        self.branches_url = branches_url
        self.campaign_url = campaign_url
        self.timeout_seconds = float(timeout_seconds)
        self._owns_client = client is None
        self._client = client or httpx.Client(
            timeout=self.timeout_seconds,
            follow_redirects=False,
            trust_env=False,
            transport=PublicAddressTransport(),
            verify=_ssl_context(),
        )

    def close(self) -> None:
        if self._owns_client:
            self._client.close()

    def _get(self, url: str, accept: str, max_bytes: int) -> bytes:
        response = request_with_same_host_redirects(
            lambda target, **kwargs: self._client.get(target, **kwargs),
            url,
            allowed_url=url,
            headers={
                "Accept": accept,
                "Accept-Encoding": "identity",
                "User-Agent": "PrueviaDrSimiCollector/0.1",
            },
            max_redirects=3,
        )
        try:
            response.raise_for_status()
            return bounded_response_bytes(response, max_bytes=max_bytes)
        finally:
            response.close()

    def fetch_branches(self) -> list[Mapping[str, Any]]:
        try:
            value = json.loads(self._get(self.branches_url, "application/json", MAX_DR_SIMI_RESPONSE_BYTES).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as error:
            raise ValueError("Dr. Simi branch feed is not valid bounded JSON") from error
        if not isinstance(value, list) or len(value) > MAX_DR_SIMI_BRANCHES:
            raise ValueError("Dr. Simi branch feed must be an array of at most 100 rows")
        rows = [row for row in value if isinstance(row, Mapping)]
        try:
            campaign_rows = parse_campaign_branches(self._get(self.campaign_url, "text/html", MAX_DR_SIMI_HTML_BYTES).decode("utf-8", "replace"))
        except (UnicodeDecodeError, ValueError):
            campaign_rows = []
        seen = {_unit_id(row.get("unidad")) for row in rows if isinstance(row, Mapping) and row.get("unidad") not in (None, "")}
        for row in campaign_rows:
            if _unit_id(row.get("unidad")) not in seen:
                rows.append(row)
                seen.add(_unit_id(row.get("unidad")))
        return rows


class DrSimiAdapter:
    source = SourceSpec(
        source_key="dr_simi_puebla",
        name="Análisis Clínicos del Dr. Simi — Puebla",
        source_type="provider_official",
        usage_policy_status="review_required",
        expected_min_records=1,
        expected_max_records=MAX_DR_SIMI_BRANCHES,
        endpoint_type="json",
        endpoint_url=DR_SIMI_BRANCHES_JSON_URL,
        parser_version="0.1.0",
    )

    def __init__(self, client: DrSimiClient) -> None:
        self.client = client

    def collect(self) -> Iterable[SourceRecord]:
        rows = self.client.fetch_branches()
        seen: set[str] = set()
        for row in rows:
            record = parse_branch(row)
            if record is None:
                continue
            if record.external_record_id in seen:
                raise ValueError(f"duplicate Dr. Simi unit: {record.external_record_id}")
            seen.add(str(record.external_record_id))
            yield record


__all__ = [
    "DR_SIMI_CAMPAIGN_URL",
    "DR_SIMI_BRANCHES_JSON_URL",
    "DR_SIMI_BRANCHES_URL",
    "DrSimiAdapter",
    "DrSimiClient",
    "parse_campaign_branches",
    "parse_branch",
]
