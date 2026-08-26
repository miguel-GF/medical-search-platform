from __future__ import annotations

import os
import re
from dataclasses import dataclass
from typing import Any, Iterable, Mapping, Sequence
from urllib.parse import quote

import httpx

from ..models import Observation, SourceRecord, SourceSpec


DENUE_BASE_URL = "https://www.inegi.org.mx/app/api/denue/v1/consulta"


@dataclass(frozen=True)
class DenueQuery:
    condition: str
    latitude: float
    longitude: float
    radius_meters: int = 5000

    def __post_init__(self) -> None:
        if not self.condition.strip():
            raise ValueError("DENUE condition cannot be empty")
        if not 1 <= self.radius_meters <= 5000:
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
        if not self.token:
            raise ValueError("DENUE_API_TOKEN is required for live requests")
        self.base_url = base_url.rstrip("/")
        self.timeout_seconds = timeout_seconds
        self._client = client

    def search(self, query: DenueQuery) -> list[Mapping[str, Any]]:
        url = self.build_search_url(query)
        owns_client = self._client is None
        client = self._client or httpx.Client(timeout=self.timeout_seconds, follow_redirects=True)
        try:
            response = client.get(url, headers={"Accept": "application/json", "User-Agent": "PrueviaCollector/0.1"})
            response.raise_for_status()
            return _decode_rows(response.json())
        finally:
            if owns_client:
                client.close()

    def build_search_url(self, query: DenueQuery) -> str:
        condition = quote(query.condition, safe="")
        point = f"{query.latitude:.8f},{query.longitude:.8f}"
        return f"{self.base_url}/Buscar/{condition}/{point}/{query.radius_meters}/{quote(self.token, safe='')}"


class DenueAdapter:
    source = SourceSpec(
        source_key="denue",
        name="INEGI DENUE",
        source_type="government",
        usage_policy_status="approved",
    )

    def __init__(self, client: DenueClient, queries: Sequence[DenueQuery]) -> None:
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
    external_id = str(external_id)
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
        return [row for row in value if isinstance(row, Mapping)]
    if isinstance(value, Mapping):
        for key in ("data", "Data", "resultados", "Resultados", "establecimientos"):
            rows = value.get(key)
            if isinstance(rows, list):
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
        return {"latitude": float(latitude), "longitude": float(longitude)}
    except (TypeError, ValueError):
        return None
