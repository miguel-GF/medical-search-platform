import json

import httpx
import pytest

from pruevia_collectors.providers.dr_simi import (
    DR_SIMI_BRANCHES_JSON_URL,
    DrSimiAdapter,
    DrSimiClient,
    parse_branch,
)


def test_parse_branch_keeps_only_puebla_and_no_catalog_claims():
    row = {
        "sucursal": "PUEBLA 1-1",
        "horario": "7:00 a 19:00",
        "direccion": "10 Oriente No. 4, Colonia Centro, C.P. 72000, Puebla, Puebla.",
        "telefono": "222-242-3077",
        "unidad": "7",
    }
    record = parse_branch(row)
    assert record is not None
    assert record.external_record_id == "7"
    assert record.record_type == "provider_location_discovered"
    assert record.payload["address"]["postal_code"] == "72000"
    assert record.payload["coordinates"] is None
    assert "prices" not in record.payload
    assert parse_branch({**row, "direccion": "Puebla Norte No. 229, Colonia Centro, C.P. 63000, Tepic, Nayarit."}) is None


def test_client_and_adapter_parse_public_array_without_other_endpoints():
    calls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(str(request.url))
        return httpx.Response(
            200,
            content=json.dumps(
                [
                    {"sucursal": "PUEBLA 1-1", "direccion": "10 Oriente No. 4, Centro, C.P. 72000, Puebla, Puebla.", "unidad": "7"},
                    {"sucursal": "TEPIC 1-1", "direccion": "Puebla Norte No. 229, Centro, C.P. 63000, Tepic, Nayarit.", "unidad": "58"},
                ]
            ).encode(),
            headers={"content-type": "application/json", "content-encoding": "identity"},
            request=request,
        )

    http_client = httpx.Client(transport=httpx.MockTransport(handler), follow_redirects=False)
    client = DrSimiClient(client=http_client)
    try:
        records = list(DrSimiAdapter(client).collect())
    finally:
        client.close()
    assert [record.external_record_id for record in records] == ["7"]
    assert calls == [DR_SIMI_BRANCHES_JSON_URL]


def test_client_rejects_query_urls_and_malformed_feed():
    with pytest.raises(ValueError, match="without credentials"):
        DrSimiClient(branches_url=f"{DR_SIMI_BRANCHES_JSON_URL}?token=secret")

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=b"{}", headers={"content-encoding": "identity"}, request=request)

    client = DrSimiClient(client=httpx.Client(transport=httpx.MockTransport(handler)))
    try:
        with pytest.raises(ValueError, match="must be an array"):
            client.fetch_branches()
    finally:
        client.close()
