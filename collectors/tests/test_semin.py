import json

import httpx
import pytest

from pruevia_collectors.providers.semin import SeminAdapter, SeminClient


def _response(request: httpx.Request, payload: object, status: int = 200) -> httpx.Response:
    return httpx.Response(status, json=payload, headers={"content-type": "application/json"}, request=request)


def test_semin_adapter_captures_catalog_details_and_deduplicates_branches():
    calls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(str(request.url))
        if request.url.path.endswith("buscar-catalogo/"):
            page = request.url.params.get("page")
            if page == "1":
                return _response(
                    request,
                    {"results": [{"id": 100, "prueba": "BiometrÃ­a hemÃ¡tica", "categoria": "Laboratorio", "precioVenta": 250, "tipoMuestra": "Sangre"}], "total_pages": 2},
                )
            return _response(
                request,
                {"results": [{"id": 101, "prueba": "Glucosa", "categoria": "QuÃ­mica", "precioNormal": 99}], "total_pages": 2},
            )
        if request.url.path.endswith("/100"):
            return _response(
                request,
                {"id": 100, "prueba": "BiometrÃ­a hemÃ¡tica", "beneficio": "EvalÃºa cÃ©lulas", "indicacionesPreExamen": "Ayuno", "tiempoEntrega": "1 dÃ­a", "available_sucursales": [{"id": 1, "nombreSucursal": "Centro", "latitud": 19.04, "longitud": -98.2, "calle": "Reforma", "municipio": "Puebla", "estado": "Puebla", "hora_apertura": "07:00:00", "hora_cierre": "18:00:00"}]},
            )
        if request.url.path.endswith("/101"):
            return _response(
                request,
                {"id": 101, "prueba": "Glucosa", "available_sucursales": [{"id": 1, "nombreSucursal": "Centro", "latitud": 19.04, "longitud": -98.2}]},
            )
        raise AssertionError(f"unexpected request: {request.url}")

    transport = httpx.MockTransport(handler)
    http_client = httpx.Client(transport=transport, follow_redirects=False)
    client = SeminClient(client=http_client, respect_robots=False)
    adapter = SeminAdapter(client, page_delay_seconds=0, max_details=2)
    try:
        records = list(adapter.collect())
    finally:
        client.close()

    offers = [record for record in records if record.record_type.startswith("provider_offer")]
    locations = [record for record in records if record.record_type == "provider_location_discovered"]
    assert len(offers) == 2
    assert len(locations) == 1
    assert offers[0].payload["provider_display_name"] == "Biometría hemática"
    assert offers[0].payload["prices"] == {"sale": 25000}
    assert offers[0].payload["benefit_description"] == "Evalúa células"
    assert locations[0].payload["location_name"] == "Centro"
    assert adapter.pages_fetched == 2
    assert adapter.details_fetched == 2
    assert all("token" not in call.casefold() for call in calls)


def test_semin_client_rejects_non_official_origin_and_invalid_ids():
    with pytest.raises(ValueError, match="official HTTPS"):
        SeminClient(api_origin="https://evil.example/semin-api")
    client = SeminClient(client=httpx.Client(transport=httpx.MockTransport(lambda request: _response(request, {}))), respect_robots=False)
    try:
        with pytest.raises(ValueError, match="outside the safety limit"):
            client.catalog_detail("-1")
        with pytest.raises(ValueError, match="invalid"):
            client.catalog_detail("not-an-id")
    finally:
        client.close()


def test_semin_client_fails_closed_when_robots_disallow_api():
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/robots.txt":
            return httpx.Response(200, text="User-agent: *\nDisallow: /semin-api\n", request=request)
        raise AssertionError("disallowed endpoint must not be requested")

    client = SeminClient(client=httpx.Client(transport=httpx.MockTransport(handler)), respect_robots=True)
    try:
        with pytest.raises(ValueError, match="disallowed by robots"):
            client.search_catalog()
    finally:
        client.close()
