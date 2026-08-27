from pathlib import Path

import httpx
import pytest
from pruevia_collectors.providers.salud_digna import (
    SaludDignaAdapter,
    SaludDignaClient,
    SaludDignaLocationPage,
    parse_salud_digna_location,
    salud_digna_study_to_record,
)

FIXTURE = Path(__file__).parent / "fixtures" / "salud_digna_location.html"


def location_record():
    page = SaludDignaLocationPage(
        "puebla-municipio-libre",
        "https://example.test/puebla-municipio-libre",
        FIXTURE.read_text(encoding="utf-8"),
    )
    return parse_salud_digna_location(page)


def test_salud_digna_location_extracts_provenance_and_coordinates():
    record = location_record()

    assert record.record_type == "provider_location_discovered"
    assert record.external_record_id == "332"
    assert record.payload["coordinates"] == {"latitude": 19.00012285276625, "longitude": -98.22797800253191}
    assert record.payload["phone"] == "222 232 4709"
    assert record.source_url.endswith("/puebla-municipio-libre")


def test_salud_digna_study_maps_promotion_from_discount():
    record = salud_digna_study_to_record(
        {"Id": 17, "Descripcion": "Glucosa", "Precio": 119.99, "Descuento": 35, "Categoria": "Laboratorio"},
        location=location_record(),
        client=SaludDignaClient(origin="https://example.test", services_base_url="https://services.test"),
    )

    assert record.external_record_id == "332:17"
    assert record.payload["prices"] == {"regular": 11999, "promotion": 7799}
    assert any(observation.entity_type == "price" for observation in record.observations)


def test_salud_digna_parser_rejects_missing_next_data():
    with pytest.raises(ValueError, match="__NEXT_DATA__"):
        parse_salud_digna_location(SaludDignaLocationPage("bad", "https://example.test/bad", "<html />"))


def test_salud_digna_client_requests_page_and_studies():
    calls: list[tuple[str, str, dict]] = []

    def handler(request: httpx.Request):
        calls.append((request.method, str(request.url), dict(request.headers)))
        if request.url.path == "/puebla-municipio-libre":
            return httpx.Response(200, text=FIXTURE.read_text(encoding="utf-8"), request=request)
        return httpx.Response(200, json={"data": [{"Id": 17, "Descripcion": "Glucosa", "Precio": "119.99"}]}, request=request)

    client = SaludDignaClient(
        origin="https://example.test",
        services_base_url="https://services.test",
        client=httpx.Client(transport=httpx.MockTransport(handler)),
    )
    try:
        page = client.fetch_location("puebla-municipio-libre")
        studies = client.fetch_studies(location_id=332)
    finally:
        client._client.close()

    assert page.slug == "puebla-municipio-libre"
    assert studies[0]["Descripcion"] == "Glucosa"
    assert calls[0][1] == "https://example.test/puebla-municipio-libre"
    assert calls[1][1] == "https://services.test/Citas2/EstudiosPorSucursal?idSucursal=332"
    assert calls[0][2]["user-agent"] == "PrueviaCollector/0.1"


def test_salud_digna_adapter_emits_location_and_catalog_records():
    class FakeClient:
        def fetch_location(self, slug):
            return SaludDignaLocationPage(slug, f"https://example.test/{slug}", FIXTURE.read_text(encoding="utf-8"))

        def fetch_studies(self, *, location_id):
            assert location_id == "332"
            return [{"Id": 17, "Descripcion": "Glucosa", "Precio": "119.99"}]

        def location_url(self, slug):
            return f"https://example.test/{slug}"

    records = list(SaludDignaAdapter(FakeClient(), ("puebla-municipio-libre",)).collect())

    assert [record.record_type for record in records] == ["provider_location_discovered", "provider_offer_price"]
    assert records[1].payload["prices"] == {"regular": 11999}


def test_salud_digna_adapter_rejects_empty_catalog():
    class EmptyClient:
        def fetch_location(self, slug):
            return SaludDignaLocationPage(slug, f"https://example.test/{slug}", FIXTURE.read_text(encoding="utf-8"))

        def fetch_studies(self, *, location_id):
            return []

    with pytest.raises(ValueError, match="no studies"):
        list(SaludDignaAdapter(EmptyClient(), ("puebla-municipio-libre",)).collect())
