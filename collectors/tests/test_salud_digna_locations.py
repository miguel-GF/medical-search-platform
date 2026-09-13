import httpx
import pytest

from pruevia_collectors.providers.salud_digna import (
    SaludDignaClient,
    SaludDignaLocationInventoryAdapter,
    salud_digna_inventory_row_to_record,
)


def test_inventory_parser_keeps_candidate_identity_without_inventing_coordinates():
    record = salud_digna_inventory_row_to_record(
        {
            "Id": 299,
            "Descripcion": "CENTRO ANALITICO LABORATORIO PUEBLA",
            "Domicilio": "",
            "Lat": "0",
            "Lng": "0",
            "_state_name": "PUEBLA",
            "_state_id": 23,
            "_municipality_name": "PUEBLA",
            "_municipality_id": 2108,
        }
    )
    assert record.source_key == "salud_digna_puebla_locations"
    assert record.payload["location_type"] == "diagnostic_center"
    assert record.payload["coordinates"] is None
    assert record.payload["address_line_1"] is None
    assert record.payload["claim_status"] == "candidate"


def test_inventory_parser_rejects_non_puebla_rows():
    with pytest.raises(ValueError, match="outside Puebla"):
        salud_digna_inventory_row_to_record(
            {"Id": 1, "Descripcion": "OTRA", "_state_name": "OAXACA"}
        )


def test_client_discovers_all_public_puebla_municipalities_without_patient_endpoints():
    calls: list[tuple[str, str]] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append((request.method, request.url.path))
        if request.url.path == "/base/Estados/Listado":
            return httpx.Response(200, json=[{"Id": 23, "Descripcion": "PUEBLA"}], request=request)
        if request.url.path == "/base/Municipios/Listado":
            return httpx.Response(
                200,
                json=[
                    {"Id": 2108, "Descripcion": "PUEBLA"},
                    {"Id": 2113, "Descripcion": "SAN ANDRES CHOLULA"},
                ],
                request=request,
            )
        if request.url.path == "/base/Sucursales/Listado" and request.url.params.get("IdMunicipio") == "2108":
            return httpx.Response(
                200,
                json=[
                    {"Id": 58, "Descripcion": "PUEBLA", "Domicilio": "Centro", "Lat": "19.04", "Lng": "-98.20"},
                    {"Id": 299, "Descripcion": "CENTRO ANALITICO LABORATORIO PUEBLA", "Lat": "0", "Lng": "0"},
                ],
                request=request,
            )
        if request.url.path == "/base/Sucursales/Listado" and request.url.params.get("IdMunicipio") == "2113":
            return httpx.Response(200, json=[{"Id": 357, "Descripcion": "PUEBLA ANGELOPOLIS"}], request=request)
        return httpx.Response(404, request=request)

    client = SaludDignaClient(
        origin="https://example.test",
        services_base_url="https://services.test",
        client=httpx.Client(transport=httpx.MockTransport(handler)),
    )
    try:
        records = list(SaludDignaLocationInventoryAdapter(client).collect())
    finally:
        client._client.close()
    assert [record.external_record_id for record in records] == ["58", "299", "357"]
    assert all(path.startswith("/base/") for _, path in calls)
    assert calls == [
        ("GET", "/base/Estados/Listado"),
        ("GET", "/base/Municipios/Listado"),
        ("GET", "/base/Sucursales/Listado"),
        ("GET", "/base/Sucursales/Listado"),
    ]


def test_client_rejects_conflicting_duplicate_branch_ids():
    class DuplicateClient:
        def fetch_puebla_location_inventory(self):
            return [
                {"Id": 1, "Descripcion": "A", "_state_name": "PUEBLA"},
                {"Id": 1, "Descripcion": "B", "_state_name": "PUEBLA"},
            ]

    # Adapter remains responsible for rejecting duplicate emitted records;
    # the client performs the stronger conflicting-name check upstream.
    with pytest.raises(ValueError, match="duplicate"):
        list(SaludDignaLocationInventoryAdapter(DuplicateClient()).collect())
