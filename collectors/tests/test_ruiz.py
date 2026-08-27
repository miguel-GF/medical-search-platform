import json
from pathlib import Path

import httpx

from pruevia_collectors.providers.ruiz import (
    RuizAdapter,
    RuizClient,
    RuizDepartment,
    ruiz_location_to_record,
    ruiz_row_to_record,
)


def fixture_data():
    return json.loads((Path(__file__).parent / "fixtures" / "ruiz_sample.json").read_text(encoding="utf-8"))


def test_ruiz_row_maps_prices_and_provenance():
    row = fixture_data()["departments"]["analisis-clinicos"][0]
    record = ruiz_row_to_record(row, department=RuizDepartment(1, "ANÁLISIS CLÍNICOS", "analisis-clinicos"))

    assert record.external_record_id == "6146"
    assert record.source_url.endswith("/estudios/analisis-clinicos/biometria-hematica")
    assert record.payload["prices"] == {"regular": 25000, "blue_card": 20000}
    assert any(observation.attribute_name == "prices" for observation in record.observations)


def test_ruiz_adapter_filters_inactive_and_limits_each_department():
    data = fixture_data()

    data["home"]["pos"] = [
        {"id": 99, "title": "Anzures", "url": "anzures", "active": 1, "zone_id": 4, "latitude": "19.02,-98.20"}
    ]

    class FakeClient:
        base_url = "https://example.test"

        def fetch_home(self):
            return data["home"]

        def fetch_departments(self, slug):
            return data["departments"][slug]

    records = list(RuizAdapter(FakeClient(), max_records=10, per_department_limit=1).collect())

    assert [record.external_record_id for record in records] == ["99", "6146", "701"]


def test_ruiz_location_maps_coordinates_and_address():
    record = ruiz_location_to_record(
        {
            "id": 99,
            "title": "Anzures",
            "url": "anzures",
            "active": 1,
            "zone_id": 4,
            "latitude": "19.0266118,-98.2033348",
            "address": "Blvd Diaz Ordaz 808",
        }
    )

    assert record.record_type == "provider_location_discovered"
    assert record.payload["coordinates"] == {"latitude": 19.0266118, "longitude": -98.2033348}


def test_ruiz_client_requests_json_endpoints():
    calls = []

    def handler(request: httpx.Request):
        calls.append(str(request.url))
        if request.url.path == "/general-home":
            return httpx.Response(200, json={"departments": []}, request=request)
        return httpx.Response(200, json={"departments": []}, request=request)

    client = RuizClient(base_url="https://example.test", client=httpx.Client(transport=httpx.MockTransport(handler)))
    try:
        assert client.fetch_home() == {"departments": []}
        assert client.fetch_departments("analisis-clinicos") == []
    finally:
        client._client.close()

    assert calls == ["https://example.test/general-home", "https://example.test/departments-studies/analisis-clinicos"]


def test_ruiz_client_retries_transient_http_errors():
    calls = 0

    def handler(request: httpx.Request):
        nonlocal calls
        calls += 1
        if calls == 1:
            return httpx.Response(503, request=request)
        return httpx.Response(200, json={"departments": []}, request=request)

    client = RuizClient(
        base_url="https://example.test",
        client=httpx.Client(transport=httpx.MockTransport(handler)),
        max_attempts=2,
        retry_backoff_seconds=0,
    )
    try:
        assert client.fetch_home() == {"departments": []}
    finally:
        client._client.close()

    assert calls == 2
