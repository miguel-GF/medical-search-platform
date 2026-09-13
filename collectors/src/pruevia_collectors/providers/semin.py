"""Bounded collector for the public Laboratorios SEMIN catalog.

SEMIN exposes a public, paginated catalog behind its web site.  This adapter
keeps the response as provider evidence: prices are labelled as unverified,
clinical descriptions are not converted into canonical concepts, and no
appointment or patient endpoint is called.  The client is intentionally
allow-listed to the official SEMIN origin and follows only same-host
redirects.
"""

from __future__ import annotations

import hashlib
import json
import re
import ssl
import time
import unicodedata
from collections.abc import Iterable, Mapping, Sequence
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from math import isfinite
from typing import Any
from urllib import robotparser
from urllib.parse import urlencode, urlparse

import certifi
import httpx

try:
    import truststore
except ImportError:  # pragma: no cover - dependency is installed in supported environments
    truststore = None  # type: ignore[assignment]

from ..models import Observation, SourceRecord, SourceSpec
from .http import bounded_response_bytes, request_with_same_host_redirects
from .public_transport import PublicAddressTransport


SEMIN_SITE_ORIGIN = "https://semindigital.com"
SEMIN_API_ORIGIN = f"{SEMIN_SITE_ORIGIN}/semin-api"
SEMIN_CATALOG_SEARCH_PATH = "/api/v3/catalog/buscar-catalogo/"
SEMIN_CATALOG_DETAIL_PATH = "/api/v3/catalog/informacion-catalogo/"
SEMIN_BRANCHES_URL = f"{SEMIN_SITE_ORIGIN}/sucursales"
SEMIN_SERVICES_URL = f"{SEMIN_SITE_ORIGIN}/servicios"
SEMIN_ROBOTS_URL = f"{SEMIN_SITE_ORIGIN}/robots.txt"
SEMIN_USER_AGENT = "PrueviaSeminCollector/0.2 (+https://pruevia.local/collector)"

MAX_SEMIN_PAGES = 20
MAX_SEMIN_RESULTS = 500
MAX_SEMIN_PAGE_ROWS = 100
MAX_SEMIN_DETAILS = 500
MAX_SEMIN_BRANCHES = 100
MAX_SEMIN_FIELD_CHARS = 4_000
MAX_SEMIN_ID_CHARS = 64
MAX_SEMIN_QUERY_CHARS = 120
MAX_SEMIN_RESPONSE_BYTES = 4 * 1024 * 1024
MAX_SEMIN_TIMEOUT_SECONDS = 120.0
MAX_SEMIN_DELAY_SECONDS = 60.0
MAX_SEMIN_ATTEMPTS = 5


def _ssl_context() -> ssl.SSLContext:
    if truststore is not None:
        return truststore.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    return ssl.create_default_context(cafile=certifi.where())


def _repair_text(value: object) -> str:
    """Normalize provider text while repairing UTF-8-as-Latin-1 responses."""

    text = " ".join(str(value or "").split())
    if not text:
        return ""
    for _ in range(2):
        if not any(marker in text for marker in ("Ã", "Â", "â", "�")):
            break
        try:
            candidate = text.encode("latin-1").decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError):
            break
        if candidate == text or candidate.count("�") > text.count("�"):
            break
        text = candidate
    return text[:MAX_SEMIN_FIELD_CHARS]


def _normalize(value: object) -> str:
    folded = unicodedata.normalize("NFKD", _repair_text(value).casefold())
    plain = "".join(char for char in folded if not unicodedata.combining(char))
    return re.sub(r"[^a-z0-9]+", " ", plain).strip()


def _first(row: Mapping[str, Any], *keys: str) -> Any:
    for key in keys:
        value = row.get(key)
        if value not in (None, ""):
            return value
    return None


def _text(value: Any) -> str | None:
    text = _repair_text(value)
    return text or None


def _safe_id(value: Any) -> str | None:
    text = _repair_text(value)
    if not text or len(text) > MAX_SEMIN_ID_CHARS or not re.fullmatch(r"[A-Za-z0-9:_-]+", text):
        return None
    return text


def _money(value: Any) -> int | None:
    if value in (None, "", "N/A", "NA"):
        return None
    try:
        amount = Decimal(str(value).replace("$", "").replace(",", "").strip())
        amount = amount.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    except (InvalidOperation, ValueError):
        return None
    if not amount.is_finite() or amount <= 0 or amount > Decimal(10_000_000):
        return None
    return int(amount * 100)


def _prices(row: Mapping[str, Any]) -> dict[str, int]:
    result: dict[str, int] = {}
    for output_key, *keys in (
        ("sale", "precioVenta", "precio_venta"),
        ("support", "precioApoyo", "precio_apoyo"),
        ("regular", "precioNormal", "precio_normal"),
    ):
        value = _money(_first(row, *keys))
        if value is not None:
            result[output_key] = value
    return result


def _bounded_int(value: Any, *, minimum: int, maximum: int) -> int | None:
    if isinstance(value, bool):
        return None
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return None
    return parsed if minimum <= parsed <= maximum else None


def _bool_value(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().casefold() in {"true", "1", "yes", "si"}
    return False


def _coordinates(row: Mapping[str, Any]) -> dict[str, float] | None:
    try:
        latitude = float(_first(row, "latitud", "latitude"))
        longitude = float(_first(row, "longitud", "longitude"))
    except (TypeError, ValueError):
        return None
    if not isfinite(latitude) or not isfinite(longitude) or not -90 <= latitude <= 90 or not -180 <= longitude <= 180:
        return None
    return {"latitude": latitude, "longitude": longitude}


def _hours(row: Mapping[str, Any]) -> dict[str, str] | None:
    fields = {
        "open": _text(_first(row, "hora_apertura", "horaApertura")),
        "close": _text(_first(row, "hora_cierre", "horaCierre")),
        "open_saturday": _text(_first(row, "hora_apertura_sab", "horaAperturaSab")),
        "close_saturday": _text(_first(row, "hora_cierre_sab", "horaCierreSab")),
    }
    result = {key: value for key, value in fields.items() if value and len(value) <= 32}
    return result or None


def _bounded_page(value: Any) -> int:
    try:
        page = int(value)
    except (TypeError, ValueError):
        raise ValueError("SEMIN catalog page metadata is invalid") from None
    if not 1 <= page <= MAX_SEMIN_PAGES:
        raise ValueError("SEMIN catalog page count exceeds the safety limit")
    return page


class SeminClient:
    """HTTP client for SEMIN's public catalog endpoints only."""

    def __init__(
        self,
        *,
        api_origin: str = SEMIN_API_ORIGIN,
        timeout_seconds: float = 30.0,
        max_attempts: int = 3,
        retry_backoff_seconds: float = 1.0,
        respect_robots: bool = True,
        client: httpx.Client | None = None,
    ) -> None:
        parsed = urlparse(api_origin.rstrip("/"))
        if (
            parsed.scheme != "https"
            or parsed.hostname != "semindigital.com"
            or parsed.username
            or parsed.password
            or parsed.query
            or parsed.fragment
            or parsed.path.rstrip("/") != "/semin-api"
            or parsed.port not in (None, 443)
        ):
            raise ValueError("SEMIN api_origin must be the official HTTPS /semin-api origin")
        if not isinstance(timeout_seconds, (int, float)) or isinstance(timeout_seconds, bool) or not 0 < timeout_seconds <= MAX_SEMIN_TIMEOUT_SECONDS:
            raise ValueError("timeout_seconds must be between 0 and 120")
        if not isinstance(max_attempts, int) or isinstance(max_attempts, bool) or not 1 <= max_attempts <= MAX_SEMIN_ATTEMPTS:
            raise ValueError("max_attempts must be between 1 and 5")
        if not isinstance(retry_backoff_seconds, (int, float)) or isinstance(retry_backoff_seconds, bool) or not isfinite(float(retry_backoff_seconds)) or not 0 <= retry_backoff_seconds <= MAX_SEMIN_DELAY_SECONDS:
            raise ValueError("retry_backoff_seconds must be between 0 and 60")
        self.api_origin = api_origin.rstrip("/")
        self.timeout_seconds = float(timeout_seconds)
        self.max_attempts = max_attempts
        self.retry_backoff_seconds = float(retry_backoff_seconds)
        self.respect_robots = respect_robots
        self._robots: robotparser.RobotFileParser | None = None
        self._robots_loaded = False
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

    def search_catalog(self, *, sentence: str = "", page: int = 1) -> Mapping[str, Any]:
        if not isinstance(sentence, str) or len(sentence) > MAX_SEMIN_QUERY_CHARS or any(ord(char) < 0x20 for char in sentence):
            raise ValueError("SEMIN search sentence is invalid")
        if not isinstance(page, int) or isinstance(page, bool) or not 1 <= page <= MAX_SEMIN_PAGES:
            raise ValueError("SEMIN catalog page is outside the safety limit")
        value = self._request_json(
            f"{self.api_origin}{SEMIN_CATALOG_SEARCH_PATH}",
            params={"sentence": sentence, "page": str(page)},
        )
        if not isinstance(value, Mapping):
            raise ValueError("SEMIN catalog search response must be an object")
        return value

    def catalog_detail(self, catalog_id: int | str) -> Mapping[str, Any]:
        try:
            numeric_id = int(catalog_id)
        except (TypeError, ValueError):
            raise ValueError("SEMIN catalog id is invalid") from None
        if not 1 <= numeric_id <= 2_000_000_000:
            raise ValueError("SEMIN catalog id is outside the safety limit")
        value = self._request_json(f"{self.api_origin}{SEMIN_CATALOG_DETAIL_PATH}{numeric_id}")
        if not isinstance(value, Mapping):
            raise ValueError("SEMIN catalog detail response must be an object")
        return value

    def _allowed_by_robots(self, url: str) -> bool:
        if not self.respect_robots:
            return True
        if not self._robots_loaded:
            parser = robotparser.RobotFileParser()
            response: httpx.Response | None = None
            try:
                response = request_with_same_host_redirects(
                    self._client.get,
                    SEMIN_ROBOTS_URL,
                    allowed_url=SEMIN_SITE_ORIGIN,
                    max_redirects=5,
                    headers={"Accept": "text/plain", "User-Agent": SEMIN_USER_AGENT, "Accept-Encoding": "identity"},
                )
                if response.status_code in {404, 410}:
                    self._robots = None
                elif response.status_code >= 400:
                    parser.parse(["User-agent: *", "Disallow: /"])
                    self._robots = parser
                else:
                    body = bounded_response_bytes(response, max_bytes=256 * 1024)
                    parser.parse(body.decode("utf-8", "replace").splitlines())
                    self._robots = parser
            except (httpx.HTTPError, ValueError, UnicodeError):
                parser.parse(["User-agent: *", "Disallow: /"])
                self._robots = parser
            finally:
                if response is not None:
                    response.close()
            self._robots_loaded = True
        return self._robots is None or self._robots.can_fetch(SEMIN_USER_AGENT, url)

    def _request_json(self, url: str, *, params: Mapping[str, str] | None = None) -> Any:
        parsed = urlparse(url)
        if parsed.scheme != "https" or parsed.hostname != "semindigital.com" or parsed.port not in (None, 443):
            raise ValueError("SEMIN request left the official host")
        query = urlencode(dict(params or {}), doseq=True)
        target = f"{url}?{query}" if query else url
        if not self._allowed_by_robots(target):
            raise ValueError("SEMIN endpoint is disallowed by robots.txt")
        for attempt in range(1, self.max_attempts + 1):
            response: httpx.Response | None = None
            try:
                response = request_with_same_host_redirects(
                    self._client.get,
                    target,
                    allowed_url=SEMIN_SITE_ORIGIN,
                    max_redirects=5,
                    params=None,
                    headers={"Accept": "application/json", "User-Agent": SEMIN_USER_AGENT, "Accept-Encoding": "identity"},
                )
                response.raise_for_status()
                raw = bounded_response_bytes(response, max_bytes=MAX_SEMIN_RESPONSE_BYTES)
                try:
                    return json.loads(raw)
                except (json.JSONDecodeError, RecursionError) as error:
                    raise ValueError("SEMIN response is not valid JSON") from error
            except httpx.HTTPStatusError as error:
                if error.response.status_code not in {408, 425, 429, 500, 502, 503, 504} or attempt == self.max_attempts:
                    raise
            except httpx.RequestError:
                if attempt == self.max_attempts:
                    raise
            finally:
                if response is not None:
                    response.close()
            if self.retry_backoff_seconds:
                time.sleep(self.retry_backoff_seconds * attempt)
        raise RuntimeError("SEMIN request retries exhausted")


class SeminAdapter:
    source = SourceSpec(
        source_key="semin_catalog_puebla",
        name="Laboratorios SEMIN — Puebla (catálogo público)",
        source_type="provider_official",
        usage_policy_status="review_required",
        endpoint_type="api",
        endpoint_url=f"{SEMIN_API_ORIGIN}{SEMIN_CATALOG_SEARCH_PATH}",
        expected_min_records=1,
        expected_max_records=MAX_SEMIN_RESULTS + MAX_SEMIN_BRANCHES,
        parser_version="0.2.0",
    )

    def __init__(
        self,
        client: SeminClient,
        *,
        sentence: str = "",
        max_pages: int = MAX_SEMIN_PAGES,
        max_results: int = MAX_SEMIN_RESULTS,
        include_details: bool = True,
        max_details: int = MAX_SEMIN_DETAILS,
        page_delay_seconds: float = 0.25,
    ) -> None:
        if not isinstance(max_pages, int) or isinstance(max_pages, bool) or not 1 <= max_pages <= MAX_SEMIN_PAGES:
            raise ValueError("max_pages must be between 1 and 20")
        if not isinstance(max_results, int) or isinstance(max_results, bool) or not 1 <= max_results <= MAX_SEMIN_RESULTS:
            raise ValueError("max_results must be between 1 and 500")
        if not isinstance(max_details, int) or isinstance(max_details, bool) or not 0 <= max_details <= MAX_SEMIN_DETAILS:
            raise ValueError("max_details must be between 0 and 500")
        if not isinstance(page_delay_seconds, (int, float)) or isinstance(page_delay_seconds, bool) or not isfinite(float(page_delay_seconds)) or not 0 <= page_delay_seconds <= MAX_SEMIN_DELAY_SECONDS:
            raise ValueError("page_delay_seconds must be between 0 and 60")
        if not isinstance(sentence, str) or len(sentence) > MAX_SEMIN_QUERY_CHARS or any(ord(char) < 0x20 for char in sentence):
            raise ValueError("sentence is invalid")
        self.client = client
        self.sentence = sentence
        self.max_pages = max_pages
        self.max_results = max_results
        self.include_details = include_details
        self.max_details = max_details
        self.page_delay_seconds = float(page_delay_seconds)
        self.pages_fetched = 0
        self.details_fetched = 0
        self.errors: list[str] = []

    def collect(self) -> Iterable[SourceRecord]:
        first = self.client.search_catalog(sentence=self.sentence, page=1)
        self.pages_fetched = 1
        pages = _bounded_page(first.get("total_pages", 1))
        pages = min(pages, self.max_pages)
        rows_by_id: dict[int, Mapping[str, Any]] = {}
        self._merge_rows(rows_by_id, first.get("results"))
        for page in range(2, pages + 1):
            if self.page_delay_seconds:
                time.sleep(self.page_delay_seconds)
            payload = self.client.search_catalog(sentence=self.sentence, page=page)
            self.pages_fetched += 1
            self._merge_rows(rows_by_id, payload.get("results"))
            if len(rows_by_id) >= self.max_results:
                break
        selected = list(rows_by_id.items())[: self.max_results]
        details: dict[int, Mapping[str, Any]] = {}
        if self.include_details:
            for index, (catalog_id, _) in enumerate(selected):
                if index >= self.max_details:
                    break
                try:
                    detail = self.client.catalog_detail(catalog_id)
                    details[catalog_id] = detail
                    self.details_fetched += 1
                except (httpx.HTTPError, ValueError) as error:
                    self.errors.append(f"detail {catalog_id}: {str(error)[:240]}")
        emitted_branches: set[str] = set()
        for catalog_id, row in selected:
            detail = details.get(catalog_id)
            merged = dict(row)
            if detail is not None:
                merged.update(detail)
            yield _catalog_record(catalog_id, merged, has_detail=detail is not None)
            if detail is None:
                continue
            branches = detail.get("available_sucursales")
            if not isinstance(branches, list):
                continue
            if len(branches) > MAX_SEMIN_BRANCHES:
                self.errors.append(f"detail {catalog_id}: branch count exceeds safety limit")
                continue
            for branch in branches:
                if not isinstance(branch, Mapping):
                    continue
                branch_id = _safe_id(_first(branch, "id", "idSucursal"))
                if branch_id is None:
                    branch_id = "hash-" + hashlib.sha256(_normalize(_first(branch, "nombreSucursal", "nombre")).encode("utf-8")).hexdigest()[:20]
                if branch_id in emitted_branches:
                    continue
                emitted_branches.add(branch_id)
                yield _branch_record(branch_id, branch)

    @staticmethod
    def _merge_rows(rows_by_id: dict[int, Mapping[str, Any]], value: Any) -> None:
        if not isinstance(value, list) or len(value) > MAX_SEMIN_PAGE_ROWS:
            raise ValueError("SEMIN catalog page has an invalid result array")
        for row in value:
            if not isinstance(row, Mapping):
                continue
            try:
                catalog_id = int(_first(row, "id", "idEstudio"))
            except (TypeError, ValueError):
                raise ValueError("SEMIN catalog result has no valid id") from None
            if not 1 <= catalog_id <= 2_000_000_000:
                raise ValueError("SEMIN catalog result id is outside the safety limit")
            previous = rows_by_id.get(catalog_id)
            if previous is not None and json.dumps(previous, sort_keys=True, ensure_ascii=False) != json.dumps(row, sort_keys=True, ensure_ascii=False):
                raise ValueError(f"SEMIN catalog id has conflicting duplicate rows: {catalog_id}")
            rows_by_id[catalog_id] = row


def _catalog_record(catalog_id: int, row: Mapping[str, Any], *, has_detail: bool) -> SourceRecord:
    name = _text(_first(row, "prueba", "nombre", "name"))
    if not name or len(name) < 3:
        raise ValueError(f"SEMIN catalog {catalog_id} has no usable study name")
    prices = _prices(row)
    source_updated = _text(_first(row, "ultimaActualizacion", "ultima_actualizacion"))
    payload = {
        "provider_brand": "Laboratorios SEMIN",
        "market": "Puebla",
        "provider_display_name": name,
        "provider_external_id": str(catalog_id),
        "provider_sku": _text(_first(row, "clave", "sku")),
        "product_url": SEMIN_SERVICES_URL,
        "area": _text(_first(row, "area")),
        "category": _text(_first(row, "categoria", "category")),
        "room": _text(_first(row, "sala", "room")),
        "sample_type": _text(_first(row, "tipoMuestra", "tipo_muestra")),
        "benefit_description": _text(_first(row, "beneficio", "benefit")),
        "pre_exam_instructions": _text(_first(row, "indicacionesPreExamen", "indicaciones_pre_examen")),
        "other_instructions": _text(_first(row, "otrasIndicaciones", "otras_indicaciones")),
        "turnaround": _text(_first(row, "tiempoEntrega", "tiempo_entrega")),
        "duration_minutes": _bounded_int(_first(row, "duracion", "duration_minutes"), minimum=0, maximum=1_440),
        "home_service": _bool_value(_first(row, "domicilio", "home_service")),
        "prices": prices,
        "price_claim_status": "unverified_provider_reference",
        "provider_last_updated_at": source_updated,
        "provider_created_at": _text(_first(row, "creacion", "created_at")),
        "catalog_rank": _bounded_int(_first(row, "ranking", "rank"), minimum=0, maximum=1_000_000),
        "detail_endpoint_captured": has_detail,
        "claim_status": "candidate",
    }
    record_type = "provider_offer_price" if prices else "provider_offer_discovered"
    observations = [
        Observation(entity_type="offer", attribute_name="provider_display_name", observed_value=name, confidence=0.98),
        Observation(entity_type="offer", attribute_name="provider_external_id", observed_value=str(catalog_id), confidence=0.98),
        Observation(entity_type="offer", attribute_name="category", observed_value=payload["category"], confidence=0.95),
        Observation(entity_type="offer", attribute_name="sample_type", observed_value=payload["sample_type"], confidence=0.95),
        Observation(entity_type="offer", attribute_name="pre_exam_instructions", observed_value=payload["pre_exam_instructions"], confidence=0.90),
        Observation(entity_type="offer", attribute_name="turnaround", observed_value=payload["turnaround"], confidence=0.90),
    ]
    if prices:
        observations.append(Observation(entity_type="price", attribute_name="prices", observed_value=prices, confidence=0.85))
    return SourceRecord(
        source_key="semin_catalog_puebla",
        record_type=record_type,
        external_record_id=f"catalog:{catalog_id}",
        source_url=SEMIN_SERVICES_URL,
        payload=payload,
        observations=tuple(observations),
    )


def _branch_record(branch_id: str, row: Mapping[str, Any]) -> SourceRecord:
    name = _text(_first(row, "nombreSucursal", "nombre", "name")) or f"Sucursal SEMIN {branch_id}"
    coordinates = _coordinates(row)
    address = {
        key: value
        for key, value in {
            "street": _text(_first(row, "calle", "street")),
            "exterior_number": _text(_first(row, "num_exterior", "numero_exterior")),
            "interior_number": _text(_first(row, "num_interior", "numero_interior")),
            "neighborhood": _text(_first(row, "colonia", "neighborhood")),
            "postal_code": _text(_first(row, "cp", "codigo_postal")),
            "locality": _text(_first(row, "localidad", "locality")),
            "municipality": _text(_first(row, "municipio", "municipality")),
            "state": _text(_first(row, "estado", "state")),
        }.items()
        if value
    }
    payload = {
        "provider_brand": "Laboratorios SEMIN",
        "market": "Puebla",
        "provider_display_name": name,
        "provider_external_id": branch_id,
        "location_name": name,
        "location_url": SEMIN_BRANCHES_URL,
        "address": address,
        "coordinates": coordinates,
        "phone": _text(_first(row, "telefono", "phone")),
        "hours": _hours(row),
        "parking": _bool_value(_first(row, "estacionamiento", "parking")),
        "claim_status": "candidate",
    }
    observations = [
        Observation(entity_type="provider_location", attribute_name="provider_display_name", observed_value=name, confidence=0.98),
        Observation(entity_type="provider_location", attribute_name="coordinates", observed_value=coordinates, confidence=0.98),
        Observation(entity_type="provider_location", attribute_name="address", observed_value=address, confidence=0.95),
        Observation(entity_type="provider_location", attribute_name="hours", observed_value=payload["hours"], confidence=0.90),
    ]
    return SourceRecord(
        source_key="semin_catalog_puebla",
        record_type="provider_location_discovered",
        external_record_id=f"branch:{branch_id}",
        source_url=SEMIN_BRANCHES_URL,
        payload=payload,
        observations=tuple(observations),
    )


__all__ = [
    "SEMIN_API_ORIGIN",
    "SEMIN_SITE_ORIGIN",
    "SeminAdapter",
    "SeminClient",
]
