from __future__ import annotations

import os
import re
import json
from dataclasses import dataclass
from math import isfinite
from typing import Any, Iterable, Mapping, Sequence
from urllib.parse import quote, urlparse

import httpx

from ..models import Observation, SourceRecord, SourceSpec
from .http import bounded_response_bytes, request_with_same_host_redirects
from .public_transport import PublicAddressTransport


DENUE_BASE_URL = "https://www.inegi.org.mx/app/api/denue/v1/consulta"
MAX_DENUE_CONDITION_CHARS = 256
MAX_DENUE_QUERIES = 100
MAX_DENUE_ROWS = 20_000
MAX_DENUE_TIMEOUT_SECONDS = 120.0
MAX_DENUE_TOKEN_CHARS = 256
MAX_DENUE_EXTERNAL_ID_CHARS = 256


@dataclass(frozen=True)
class DenueQuery:
    condition: str
    latitude: float
    longitude: float
    radius_meters: int = 5000

    def __post_init__(self) -> None:
        if not isinstance(self.condition, str) or not self.condition.strip() or len(self.condition.strip()) > MAX_DENUE_CONDITION_CHARS:
            raise ValueError("DENUE condition cannot be empty")
        if not isinstance(self.latitude, (int, float)) or isinstance(self.latitude, bool) or not isfinite(float(self.latitude)) or not -90 <= self.latitude <= 90:
            raise ValueError("DENUE latitude must be between -90 and 90")
        if not isinstance(self.longitude, (int, float)) or isinstance(self.longitude, bool) or not isfinite(float(self.longitude)) or not -180 <= self.longitude <= 180:
            raise ValueError("DENUE longitude must be between -180 and 180")
        if not isinstance(self.radius_meters, int) or isinstance(self.radius_meters, bool) or not 1 <= self.radius_meters <= 5000:
            raise ValueError("DENUE radius must be between 1 and 5000 meters")


class DenueClient:
    """Small client for the official DENUE v1 Buscar endpoint.

    The API token is read from `DENUE_API_TOKEN` unless provided explicitly.
    It is never included in a `SourceRecord` or collector artifact.
    """

    def __init__(
        self,
        token: str | None = None,
        *,
        base_url: str = DENUE_BASE_URL,
        timeout_seconds: float = 30.0,
        client: httpx.Client | None = None,
    ) -> None:
        self.token = token or os.getenv("DENUE_API_TOKEN")
        if not isinstance(self.token, str) or not self.token or len(self.token) > MAX_DENUE_TOKEN_CHARS or any(ord(char) < 0x20 or ord(char) == 0x7F for char in self.token):
            raise ValueError("DENUE_API_TOKEN is required for live requests")
        parsed_base = urlparse(base_url)
        if (
            parsed_base.scheme != "https"
            or parsed_base.hostname != "www.inegi.org.mx"
            or parsed_base.username
            or parsed_base.password
            or parsed_base.query
            or parsed_base.fragment
            or parsed_base.port not in (None, 443)
            or parsed_base.path.rstrip("/") != "/app/api/denue/v1/consulta"
        ):
            raise ValueError("DENUE base_url must be the official HTTPS endpoint")
        self.base_url = base_url.rstrip("/")
        if not isinstance(timeout_seconds, (int, float)) or isinstance(timeout_seconds, bool) or not isfinite(float(timeout_seconds)) or not 0 < timeout_seconds <= MAX_DENUE_TIMEOUT_SECONDS:
            raise ValueError("timeout_seconds must be between 0 and 120")
        self.timeout_seconds = timeout_seconds
        self._client = client

    def search(self, query: DenueQuery) -> list[Mapping[str, Any]]:
        url = self.build_search_url(query)
        owns_client = self._client is None
        client = self._client or httpx.Client(timeout=self.timeout_seconds, follow_redirects=False, trust_env=False, transport=PublicAddressTransport())
        try:
            try:
                response = request_with_same_host_redirects(
                    client.get,
                    url,
                    allowed_url=self.base_url,
                    max_redirects=5,
                    headers={"Accept": "application/json", "User-Agent": "PrueviaCollector/0.1"},
                )
                response.raise_for_status()
                try:
                    try:
                        decoded = json.loads(bounded_response_bytes(response, max_bytes=2 * 1024 * 1024))
                    except (ValueError, RecursionError) as error:
                        raise ValueError("DENUE response is not valid JSON") from error
                    return _decode_rows(decoded)
                finally:
                    response.close()
            except (httpx.HTTPStatusError, httpx.RequestError) as error:
                # DENUE requires the token in the URL path. Never propagate
                # that URL into the run manifest or CLI error output.
                raise RuntimeError(f"DENUE request failed: {_redact_token(str(error), self.token)}") from error
        finally:
            if owns_client:
                client.close()

    def build_search_url(self, query: DenueQuery) -> str:
        condition = quote(query.condition, safe="")
        point = f"{query.latitude:.8f},{query.longitude:.8f}"
        return f"{self.base_url}/Buscar/{condition}/{point}/{query.radius_meters}/{quote(self.token, safe='')}"


def _redact_token(value: str, token: str | None) -> str:
    message = value
    if token:
        for candidate in {token, quote(token, safe="")}:
            if candidate:
                message = message.replace(candidate, "[REDACTED]")
    return message


class DenueAdapter:
    source = SourceSpec(
        source_key="denue",
        name="INEGI DENUE",
        source_type="government",
        usage_policy_status="approved",
        endpoint_type="api",
        endpoint_url=DENUE_BASE_URL,
    )

    def __init__(self, client: DenueClient, queries: Sequence[DenueQuery]) -> None:
        if len(queries) > MAX_DENUE_QUERIES:
            raise ValueError("too many DENUE queries")
        self.client = client
        self.queries = tuple(queries)

    def collect(self) -> Iterable[SourceRecord]:
        seen: set[str] = set()
        for query in self.queries:
            for row in self.client.search(query):
                record = denue_row_to_record(row, query=query)
                if record.external_record_id and record.external_record_id in seen:
                    continue
                if record.external_record_id:
                    seen.add(record.external_record_id)
                yield record


def denue_row_to_record(row: Mapping[str, Any], *, query: DenueQuery | None = None) -> SourceRecord:
    external_id = _first_value(row, "Id", "ID", "id", "id_establecimiento", "CLEE", "clee")
    if external_id is None:
        raise ValueError("DENUE row has no stable Id/CLEE")
    external_id = str(external_id).strip()
    if not external_id or len(external_id) > MAX_DENUE_EXTERNAL_ID_CHARS:
        raise ValueError("DENUE row has an invalid stable Id/CLEE")
    payload = dict(row)
    if query:
        payload["_denue_query"] = {
            "condition": query.condition,
            "latitude": query.latitude,
            "longitude": query.longitude,
            "radius_meters": query.radius_meters,
        }

    observations: list[Observation] = []
    field_map = {
        "name": ("Nombre", "nombre", "Nombre_del_establecimiento", "nombre_establecimiento"),
        "legal_name": ("Razon_social", "Razón_social", "razon_social", "RazonSocial"),
        "activity_code": ("Clase_actividad", "clase_actividad", "codigo_clase"),
        "phone": ("Telefono", "Teléfono", "telefono", "phone"),
        "email": ("Correo_e", "Correo", "correo", "email"),
        "website_url": ("www", "Sitio_en_Internet", "sitio_internet", "website"),
        "postal_code": ("CP", "Codigo_postal", "Código_postal", "codigo_postal"),
        "latitude": ("Latitud", "latitud", "latitude"),
        "longitude": ("Longitud", "longitud", "longitude"),
    }
    for attribute, keys in field_map.items():
        value = _first_value(row, *keys)
        if value not in (None, ""):
            observations.append(
                Observation(
                    entity_type="provider_location",
                    attribute_name=attribute,
                    observed_value=value,
                )
            )

    address = _address_from_row(row)
    if address:
        observations.append(
            Observation(entity_type="provider_location", attribute_name="address", observed_value=address)
        )
    coordinates = _coordinates_from_row(row)
    if coordinates:
        observations.append(
            Observation(entity_type="provider_location", attribute_name="coordinates", observed_value=coordinates)
        )

    source_url = f"{DENUE_BASE_URL}/Ficha/{quote(external_id, safe='')}"
    return SourceRecord(
        source_key="denue",
        record_type="provider_location_discovered",
        external_record_id=external_id,
        source_url=source_url,
        payload=payload,
        observations=tuple(observations),
    )


def _decode_rows(value: Any) -> list[Mapping[str, Any]]:
    if isinstance(value, list):
        if len(value) > MAX_DENUE_ROWS:
            raise ValueError("DENUE response contains too many rows")
        return [row for row in value if isinstance(row, Mapping)]
    if isinstance(value, Mapping):
        for key in ("data", "Data", "resultados", "Resultados", "establecimientos"):
            rows = value.get(key)
            if isinstance(rows, list):
                if len(rows) > MAX_DENUE_ROWS:
                    raise ValueError("DENUE response contains too many rows")
                return [row for row in rows if isinstance(row, Mapping)]
        if _first_value(value, "Id", "ID", "id", "CLEE") is not None:
            return [value]
    raise ValueError("DENUE response did not contain an array of establishments")


def _normalized_key(value: object) -> str:
    return re.sub(r"[^a-z0-9]", "", str(value).lower())


def _first_value(row: Mapping[str, Any], *keys: str) -> Any:
    # Prefer the explicit key order. DENUE may return both `Id` and `CLEE`;
    # callers must be able to choose the API establishment ID first.
    for wanted_key in keys:
        normalized_wanted = _normalized_key(wanted_key)
        for key, value in row.items():
            if _normalized_key(key) == normalized_wanted and value not in (None, ""):
                return value
    return None


def _address_from_row(row: Mapping[str, Any]) -> dict[str, Any] | None:
    values = {
        "street": _first_value(row, "Calle", "calle", "vialidad"),
        "exterior_number": _first_value(row, "Num_Exterior", "Numero_exterior", "numero_exterior"),
        "interior_number": _first_value(row, "Num_Interior", "Numero_interior", "numero_interior"),
        "neighborhood": _first_value(row, "Colonia", "colonia", "asentamiento"),
        "postal_code": _first_value(row, "CP", "Codigo_postal", "codigo_postal"),
        "locality": _first_value(row, "Localidad", "localidad"),
        "municipality": _first_value(row, "Municipio", "municipio"),
        "state": _first_value(row, "Entidad", "entidad", "estado"),
    }
    cleaned = {key: value for key, value in values.items() if value not in (None, "")}
    return cleaned or None


def _coordinates_from_row(row: Mapping[str, Any]) -> dict[str, float] | None:
    latitude = _first_value(row, "Latitud", "latitud", "latitude")
    longitude = _first_value(row, "Longitud", "longitud", "longitude")
    try:
        if latitude in (None, "") or longitude in (None, ""):
            return None
        parsed_latitude = float(latitude)
        parsed_longitude = float(longitude)
        if not isfinite(parsed_latitude) or not isfinite(parsed_longitude) or not -90 <= parsed_latitude <= 90 or not -180 <= parsed_longitude <= 180:
            return None
        return {"latitude": parsed_latitude, "longitude": parsed_longitude}
    except (TypeError, ValueError):
        return None
