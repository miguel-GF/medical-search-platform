from __future__ import annotations

import hashlib
import json
import re
import ssl
import time
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal, InvalidOperation
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

SALUD_DIGNA_ORIGIN = "https://www.salud-digna.org"
SALUD_DIGNA_SERVICES_URL = "https://api.emarketingsd.org"
SALUD_DIGNA_LOCATION_PREFIX = f"{SALUD_DIGNA_ORIGIN}/"
SALUD_DIGNA_CATEGORIES_PATH = "/Citas/Citas2/EstudiosPorSucursal"
SALUD_DIGNA_STUDIES_PATH = "/Citas/Citas2/SubEstudiosPorSucursalPP"
MAX_SALUD_DIGNA_ATTEMPTS = 5
MAX_SALUD_DIGNA_TIMEOUT_SECONDS = 120.0
MAX_SALUD_DIGNA_DELAY_SECONDS = 60.0
MAX_SALUD_DIGNA_LOCATIONS = 100
MAX_SALUD_DIGNA_CATEGORIES = 500
MAX_SALUD_DIGNA_STUDIES = 20_000
MAX_SALUD_DIGNA_SLUG_CHARS = 128
MAX_SALUD_DIGNA_FIELD_CHARS = 4_000


@dataclass(frozen=True)
class SaludDignaLocationPage:
    slug: str
    url: str
    html: str


class SaludDignaClient:
    """Client for the public Salud Digna location and study endpoints."""

    def __init__(
        self,
        *,
        origin: str = SALUD_DIGNA_ORIGIN,
        services_base_url: str = SALUD_DIGNA_SERVICES_URL,
        timeout_seconds: float = 30.0,
        max_attempts: int = 3,
        retry_backoff_seconds: float = 1.5,
        client: httpx.Client | None = None,
    ) -> None:
        for label, value in (("origin", origin), ("services_base_url", services_base_url)):
            parsed = urlparse(value.rstrip("/"))
            try:
                port = parsed.port
            except ValueError as error:
                raise ValueError(f"{label} must use a valid HTTPS URL") from error
            if (
                parsed.scheme != "https"
                or not parsed.hostname
                or parsed.username
                or parsed.password
                or parsed.query
                or parsed.fragment
                or parsed.path not in ("", "/")
                or port not in (None, 443)
            ):
                raise ValueError(f"{label} must be an HTTPS origin without credentials")
        if not isinstance(max_attempts, int) or isinstance(max_attempts, bool) or not 1 <= max_attempts <= MAX_SALUD_DIGNA_ATTEMPTS:
            raise ValueError("max_attempts must be between 1 and 5")
        if not isinstance(timeout_seconds, (int, float)) or isinstance(timeout_seconds, bool) or not isfinite(float(timeout_seconds)) or not 0 < timeout_seconds <= MAX_SALUD_DIGNA_TIMEOUT_SECONDS:
            raise ValueError("timeout_seconds must be between 0 and 120")
        if not isinstance(retry_backoff_seconds, (int, float)) or isinstance(retry_backoff_seconds, bool) or not isfinite(float(retry_backoff_seconds)) or not 0 <= retry_backoff_seconds <= MAX_SALUD_DIGNA_DELAY_SECONDS:
            raise ValueError("retry_backoff_seconds must be between 0 and 60")
        self.origin = origin.rstrip("/")
        self.services_base_url = services_base_url.rstrip("/")
        self.timeout_seconds = timeout_seconds
        self.max_attempts = max_attempts
        self.retry_backoff_seconds = retry_backoff_seconds
        self._owns_client = client is None
        self._client = client or httpx.Client(
            timeout=timeout_seconds,
            follow_redirects=False,
            trust_env=False,
            transport=PublicAddressTransport(),
            verify=_ssl_context(),
        )

    def close(self) -> None:
        if self._owns_client:
            self._client.close()

    def location_url(self, slug: str) -> str:
        clean_slug = slug.strip().strip("/")
        if (
            not clean_slug
            or len(clean_slug) > MAX_SALUD_DIGNA_SLUG_CHARS
            or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", clean_slug)
        ):
            raise ValueError("Salud Digna location slug must be a bounded safe path segment")
        return f"{self.origin}/{clean_slug}"

    def fetch_location(self, slug: str) -> SaludDignaLocationPage:
        url = self.location_url(slug)
        response = self._request("GET", url, headers={"Accept": "text/html"})
        try:
            raw = bounded_response_bytes(response, max_bytes=2 * 1024 * 1024)
            return SaludDignaLocationPage(slug=slug.strip().strip("/"), url=str(response.url), html=raw.decode("utf-8", "replace"))
        finally:
            response.close()

    def fetch_studies(self, *, location_id: str | int) -> list[Mapping[str, Any]]:
        categories_payload = self._request_json(
            "GET",
            f"{self.services_base_url}{SALUD_DIGNA_CATEGORIES_PATH}",
            params={"idSucursal": str(location_id)},
        )
        categories = _decode_rows(
            categories_payload,
            keys=("Estudios", "estudios", "data", "Data", "result", "results", "items"),
            max_rows=MAX_SALUD_DIGNA_CATEGORIES,
        )
        studies: list[Mapping[str, Any]] = []
        for category in categories:
            category_id = _first_value(category, "Id", "id", "IdEstudio", "idEstudio")
            if category_id in (None, ""):
                continue
            category_id_text = str(category_id).strip()[:200]
            payload = self._request_json(
                "GET",
                f"{self.services_base_url}{SALUD_DIGNA_STUDIES_PATH}",
                params={
                    "estudio[Id]": category_id_text,
                    "sucursal[Id]": str(location_id),
                    "filtro": "1",
                    "busqueda": "",
                },
            )
            studies.extend(
                _decode_rows(
                    payload,
                    keys=("Estudios", "estudios", "data", "Data", "result", "results", "items"),
                    max_rows=MAX_SALUD_DIGNA_STUDIES,
                )
            )
            if len(studies) > MAX_SALUD_DIGNA_STUDIES:
                raise ValueError("Salud Digna study catalog exceeds the safety limit")
        return studies

    def _request(self, method: str, url: str, **kwargs: Any) -> httpx.Response:
        headers = {"User-Agent": "PrueviaCollector/0.1", **kwargs.pop("headers", {})}
        for attempt in range(1, self.max_attempts + 1):
            try:
                response = request_with_same_host_redirects(
                    lambda target, **request_kwargs: self._client.request(method, target, **request_kwargs),
                    url,
                    allowed_url=url,
                    max_redirects=5,
                    headers=headers,
                    **kwargs,
                )
                response.raise_for_status()
                return response
            except httpx.HTTPStatusError as error:
                if error.response.status_code not in {429, 500, 502, 503, 504} or attempt == self.max_attempts:
                    raise
                time.sleep(self.retry_backoff_seconds * attempt)
            except httpx.RequestError:
                if attempt == self.max_attempts:
                    raise
                time.sleep(self.retry_backoff_seconds * attempt)
        raise RuntimeError("unreachable")

    def _request_json(self, method: str, url: str, **kwargs: Any) -> Any:
        response = self._request(method, url, headers={"Accept": "application/json"}, **kwargs)
        try:
            return json.loads(bounded_response_bytes(response, max_bytes=2 * 1024 * 1024))
        except (ValueError, RecursionError) as error:
            raise ValueError(f"Salud Digna response is not valid JSON: {url}") from error
        finally:
            response.close()


def _ssl_context() -> ssl.SSLContext:
    """Use the OS trust store, with certifi as a portable fallback."""
    if truststore is not None:
        return truststore.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    # Keep a verified fallback for environments where truststore is absent.
    return ssl.create_default_context(cafile=certifi.where())


class SaludDignaAdapter:
    source = SourceSpec(
        source_key="salud_digna_puebla",
        name="Salud Digna — Puebla",
        source_type="provider_official",
        usage_policy_status="review_required",
        endpoint_type="api",
        endpoint_url=SALUD_DIGNA_SERVICES_URL + SALUD_DIGNA_STUDIES_PATH,
        parser_version="0.1.0",
    )

    def __init__(
        self,
        client: SaludDignaClient,
        location_slugs: Sequence[str] = ("puebla-municipio-libre",),
        *,
        include_catalog: bool = True,
        page_delay_seconds: float = 0.5,
    ) -> None:
        slugs = tuple(slug.strip().strip("/") for slug in location_slugs if slug.strip().strip("/"))
        if not slugs:
            raise ValueError("at least one Salud Digna location slug is required")
        if len(slugs) > MAX_SALUD_DIGNA_LOCATIONS:
            raise ValueError("too many Salud Digna locations")
        if not isinstance(page_delay_seconds, (int, float)) or isinstance(page_delay_seconds, bool) or not isfinite(float(page_delay_seconds)) or not 0 <= page_delay_seconds <= MAX_SALUD_DIGNA_DELAY_SECONDS:
            raise ValueError("page_delay_seconds must be between 0 and 60")
        self.client = client
        self.location_slugs = slugs
        self.include_catalog = include_catalog
        self.page_delay_seconds = page_delay_seconds

    def collect(self) -> Iterable[SourceRecord]:
        for index, slug in enumerate(self.location_slugs):
            if index and self.page_delay_seconds:
                time.sleep(self.page_delay_seconds)
            page = self.client.fetch_location(slug)
            location = parse_salud_digna_location(page)
            yield location
            if not self.include_catalog:
                continue
            location_id = location.external_record_id
            if not location_id:
                raise ValueError(f"Salud Digna location has no stable IdSucursal: {slug}")
            studies = self.client.fetch_studies(location_id=location_id)
            if not studies:
                raise ValueError(f"Salud Digna returned no studies for location: {slug}")
            seen_payload_hashes: set[str] = set()
            seen_external_ids: dict[str, tuple[str, tuple[tuple[str, int], ...]]] = {}
            for row in studies:
                record = salud_digna_study_to_record(row, location=location, client=self.client)
                # The provider endpoint currently repeats two study rows across
                # categories. Suppress only byte-equivalent payloads so the
                # runner's record-hash invariant remains intact; records with
                # the same external id but different prices are retained.
                payload_hash = hashlib.sha256(
                    json.dumps(record.payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
                ).hexdigest()
                if payload_hash in seen_payload_hashes:
                    continue
                seen_payload_hashes.add(payload_hash)
                external_id = record.external_record_id
                identity = (
                    str(record.payload["provider_display_name"]),
                    tuple(sorted((str(key), int(value)) for key, value in (record.payload.get("prices") or {}).items())),
                )
                previous_identity = seen_external_ids.get(external_id)
                if previous_identity is not None:
                    if previous_identity != identity:
                        raise ValueError(f"conflicting duplicate Salud Digna study id: {external_id}")
                    continue
                seen_external_ids[external_id] = identity
                yield record


def parse_salud_digna_location(page: SaludDignaLocationPage) -> SourceRecord:
    data = _next_data(page.html)
    page_props = _mapping(data.get("props", {})).get("pageProps", {})
    info = _mapping(_mapping(page_props).get("informacionSucursal", {}))
    location_id = _first_value(info, "IdSucursal", "idSucursal", "Id", "id")
    name = _text(_first_value(info, "Nombre", "nombre"))
    address = _text(_first_value(info, "Direccion", "direccion", "address"))
    if location_id in (None, "") or not name:
        raise ValueError(f"Salud Digna location requires IdSucursal and Nombre: {page.slug}")
    coordinates = _coordinates(info.get("Lat"), info.get("Long"))
    location_url = page.url or f"{SALUD_DIGNA_LOCATION_PREFIX}{page.slug}"
    payload = {
        "provider_brand": "Salud Digna",
        "market": "Puebla",
        "provider_display_name": name,
        "provider_external_id": str(location_id),
        "location_slug": page.slug,
        "location_url": location_url,
        "address_line_1": address or None,
        "phone": _text(_first_value(info, "Telefono", "telefono", "phone")) or None,
        "coordinates": coordinates,
        "hours": _hours(_first_value(info, "Horarios", "HorariosClinica", "horarios")),
        "city": _text(_first_value(info, "Ciudad", "ciudad")) or None,
        "state": _text(_first_value(info, "Estado", "estado")) or None,
    }
    observations = [
        Observation(entity_type="provider_location", attribute_name="provider_display_name", observed_value=name),
        Observation(entity_type="provider_location", attribute_name="provider_external_id", observed_value=str(location_id)),
        Observation(entity_type="provider_location", attribute_name="address", observed_value=payload["address_line_1"]),
        Observation(entity_type="provider_location", attribute_name="coordinates", observed_value=coordinates),
        Observation(entity_type="provider_location", attribute_name="hours", observed_value=payload["hours"]),
    ]
    return SourceRecord(
        source_key="salud_digna_puebla",
        record_type="provider_location_discovered",
        external_record_id=str(location_id),
        source_url=location_url,
        payload=payload,
        observations=tuple(observations),
    )


def salud_digna_study_to_record(
    row: Mapping[str, Any], *, location: SourceRecord, client: SaludDignaClient
) -> SourceRecord:
    name = _text(_first_value(row, "Descripcion", "descripcion", "Nombre", "nombre", "Estudio", "estudio"))
    external_id = _first_value(row, "Id", "id", "IdEstudio", "idEstudio", "Clave", "clave", "Codigo", "codigo", "SKU", "sku")
    if not name or external_id in (None, ""):
        raise ValueError("Salud Digna study requires a name and stable id")
    location_id = location.external_record_id or ""
    location_slug = str(location.payload.get("location_slug") or "")
    product_url = client.location_url(location_slug)
    prices = _prices(row)
    payload = {
        "provider_brand": "Salud Digna",
        "market": "Puebla",
        "provider_display_name": name,
        "provider_external_id": str(external_id),
        "provider_sku": _text(_first_value(row, "Clave", "clave", "Codigo", "codigo", "SKU", "sku")) or None,
        "location_external_id": location_id,
        "location_slug": location_slug,
        "product_url": product_url,
        "category": _text(_first_value(row, "Categoria", "categoria", "Tipo", "tipo")) or None,
        "prices": prices,
        "raw_study": dict(row),
    }
    observations = [
        Observation(entity_type="offer", attribute_name="provider_display_name", observed_value=name),
        Observation(entity_type="offer", attribute_name="provider_external_id", observed_value=str(external_id)),
        Observation(entity_type="offer", attribute_name="product_url", observed_value=product_url),
        Observation(entity_type="offer", attribute_name="location_external_id", observed_value=location_id),
    ]
    if prices:
        observations.append(Observation(entity_type="price", attribute_name="prices", observed_value=prices))
    return SourceRecord(
        source_key="salud_digna_puebla",
        record_type="provider_offer_price",
        external_record_id=f"{location_id}:{external_id}",
        source_url=product_url,
        payload=payload,
        observations=tuple(observations),
    )


def _next_data(html: str) -> Mapping[str, Any]:
    match = re.search(r'<script[^>]+id=["\']__NEXT_DATA__["\'][^>]*>(.*?)</script>', html, flags=re.IGNORECASE | re.DOTALL)
    if not match:
        raise ValueError("Salud Digna page has no __NEXT_DATA__ payload")
    try:
        value = json.loads(match.group(1))
    except (json.JSONDecodeError, RecursionError) as error:
        raise ValueError("Salud Digna __NEXT_DATA__ is invalid JSON") from error
    if not isinstance(value, Mapping):
        raise TypeError("Salud Digna __NEXT_DATA__ must be an object")
    return value


def _decode_rows(payload: Any, *, keys: Sequence[str], max_rows: int = MAX_SALUD_DIGNA_STUDIES) -> list[Mapping[str, Any]]:
    if isinstance(payload, list):
        if len(payload) > max_rows:
            raise ValueError("Salud Digna response contains too many rows")
        return [row for row in payload if isinstance(row, Mapping)]
    if isinstance(payload, Mapping):
        for key in keys:
            value = payload.get(key)
            if isinstance(value, list):
                if len(value) > max_rows:
                    raise ValueError("Salud Digna response contains too many rows")
                return [row for row in value if isinstance(row, Mapping)]
        if any(key in payload for key in ("Id", "id", "Descripcion", "descripcion", "Nombre", "nombre")):
            return [payload]
    raise ValueError("Salud Digna study response has no array of rows")


def _mapping(value: Any) -> Mapping[str, Any]:
    return value if isinstance(value, Mapping) else {}


def _first_value(row: Mapping[str, Any], *keys: str) -> Any:
    for key in keys:
        value = row.get(key)
        if value not in (None, ""):
            return value
    return None


def _text(value: Any) -> str:
    return " ".join(str(value or "").split())[:MAX_SALUD_DIGNA_FIELD_CHARS]


def _coordinates(latitude: Any, longitude: Any) -> dict[str, float] | None:
    try:
        lat = float(str(latitude).strip())
        lng = float(str(longitude).strip())
    except (TypeError, ValueError):
        return None
    if not isfinite(lat) or not isfinite(lng) or not -90 <= lat <= 90 or not -180 <= lng <= 180:
        return None
    return {"latitude": lat, "longitude": lng}


def _hours(value: Any) -> dict[str, str] | None:
    raw = _text(value)
    if not raw:
        return None
    parts = [part.strip() for part in raw.split("|")]
    return {"raw": raw, "segments": parts}


def _prices(row: Mapping[str, Any]) -> dict[str, int]:
    result: dict[str, int] = {}
    regular = _money(_first_value(row, "Precio", "precio", "PrecioRegular", "precioRegular", "price"))
    if regular is not None and regular > 0:
        result["regular"] = regular
    promotion = _money(_first_value(row, "PrecioPromocion", "precioPromocion", "PrecioOferta", "precioOferta"))
    if promotion is not None and promotion > 0 and promotion != regular:
        result["promotion"] = promotion
    discount = _number(_first_value(row, "Descuento", "descuento", "Discount", "discount"))
    if promotion is None and regular is not None and discount is not None and 0 < discount < 100:
        result["promotion"] = int((Decimal(regular) * (Decimal(1) - discount / Decimal(100))).quantize(Decimal(1), rounding=ROUND_HALF_UP))
    return result


def _money(value: Any) -> int | None:
    if value in (None, "", "N/A", "NA"):
        return None
    try:
        amount = Decimal(str(value).replace("$", "").replace(",", "").strip()).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    except (InvalidOperation, ValueError):
        return None
    if not amount.is_finite() or amount <= 0 or amount > Decimal(10000000):
        return None
    return int(amount * 100)


def _number(value: Any) -> Decimal | None:
    if value in (None, "", "N/A", "NA"):
        return None
    try:
        number = Decimal(str(value).replace("%", "").strip())
    except (InvalidOperation, ValueError):
        return None
    return number if number.is_finite() else None
