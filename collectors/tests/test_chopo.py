from pathlib import Path

import httpx

from pruevia_collectors.providers.chopo import (
    MAX_CHOPO_ATTEMPTS,
    MAX_CHOPO_PAGES,
    MAX_CHOPO_PRODUCTS,
    ChopoAdapter,
    ChopoClient,
    ChopoPage,
    ChopoListingParser,
    ChopoProductPage,
    parse_chopo_page,
    parse_chopo_product,
    parse_price_text,
)
import pytest


def fixture_page() -> ChopoPage:
    path = Path(__file__).parent / "fixtures" / "chopo_puebla_page.html"
    return ChopoPage(1, "https://www.chopo.com.mx/puebla/estudios", path.read_text(encoding="utf-8"))


def test_chopo_parser_extracts_names_skus_urls_and_prices():
    records = parse_chopo_page(fixture_page())

    assert len(records) == 2
    assert records[0].external_record_id == "17002"
    assert records[0].payload["prices"] == {"regular": 28428, "online": 18479}
    assert records[0].source_url == "https://www.chopo.com.mx/puebla/biometria-hematica"
    assert records[1].payload["prices"] == {"regular": 80099}


def test_chopo_price_parser_keeps_minor_units():
    assert parse_price_text("Precio $1,500.00 $975.5") == {"regular": 150000, "online": 97550}
    assert parse_price_text("Sin precio") == {}
    assert parse_price_text("Precio $0.00") == {}
    assert parse_price_text("Precio $0.00 $975.00") == {}


def test_chopo_product_parser_reads_structured_puebla_price():
    page = ChopoProductPage(
        "https://www.chopo.com.mx/puebla/biometria-hematica",
        'magentoStorefrontEvents.context.setProduct({"productId":5240,"name":"BIOMETRÍA HEMÁTICA","sku":"17002","pricing":{"regularPrice":284.28,"specialPrice":184.79}});',
    )

    record = parse_chopo_product(page)

    assert record.external_record_id == "17002"
    assert record.payload["market"] == "Puebla"
    assert record.payload["prices"] == {"regular": 28428, "online": 18479}


def test_chopo_product_parser_rejects_untrusted_host():
    client = ChopoClient(base_url="https://www.chopo.com.mx/puebla/estudios", client=object())
    try:
        try:
            client.fetch_product("https://evil.example/product")
        except ValueError as error:
            assert "official host" in str(error)
        else:
            raise AssertionError("expected untrusted host to fail")
    finally:
        client._client = None


def test_chopo_product_parser_rejects_non_puebla_market_path():
    client = ChopoClient(base_url="https://www.chopo.com.mx/puebla/estudios", client=object())
    try:
        try:
            client.fetch_product("https://www.chopo.com.mx/biometria-hematica")
        except ValueError as error:
            assert "Puebla path" in str(error)
        else:
            raise AssertionError("expected non-Puebla URL to fail")
    finally:
        client._client = None


def test_chopo_parser_does_not_capture_search_autocomplete_items():
    parser = ChopoListingParser(page_url="https://www.chopo.com.mx/puebla/estudios")
    parser.feed('<dd><div class="product-name">AUTOCOMPLETE</div></dd>')
    assert parser.finish() == []


def test_chopo_parser_bounds_hostile_tag_fanout_and_capture_text():
    parser = ChopoListingParser(page_url="https://www.chopo.com.mx/puebla/estudios")
    parser.feed("<a class='catalog-grid-item__name-link' href='/puebla/x'>" + "A" * 20_000 + "</a>")
    for index in range(3_000):
        parser.feed(f"<a class='catalog-grid-item__name-link' href='/puebla/{index}'>x</a>")
    records = parser.finish()
    assert len(records) <= 2_000
    assert all(len(record["name"]) <= 4_000 for record in records)


def test_chopo_client_reuses_client_and_retries_transient_statuses():
    class FakeClient:
        def __init__(self):
            self.calls = []
            self.responses = [
                httpx.Response(503, request=httpx.Request("GET", "https://example.test/puebla/estudios?p=2")),
                httpx.Response(
                    200,
                    text="<html>ok</html>",
                    request=httpx.Request("GET", "https://example.test/puebla/estudios?p=2"),
                ),
            ]

        def get(self, url, **kwargs):
            self.calls.append((url, kwargs))
            return self.responses.pop(0)

    fake = FakeClient()
    client = ChopoClient(
        base_url="https://example.test/puebla/estudios",
        client=fake,
        max_attempts=2,
        retry_backoff_seconds=0,
    )
    page = client.fetch_page(2)

    assert page.page_number == 2
    assert len(fake.calls) == 2
    assert "p=2" in fake.calls[0][0]
    assert all("Mozilla/5.0" in call[1]["headers"]["User-Agent"] for call in fake.calls)


def test_chopo_client_retries_transport_errors():
    class FakeClient:
        def __init__(self):
            self.calls = 0

        def get(self, url, **kwargs):
            self.calls += 1
            if self.calls == 1:
                raise httpx.ConnectError("temporary connection reset")
            return httpx.Response(200, text="<html>ok</html>", request=httpx.Request("GET", url))

    fake = FakeClient()
    client = ChopoClient(client=fake, max_attempts=2, retry_backoff_seconds=0)

    assert client.fetch_page(1).html == "<html>ok</html>"
    assert fake.calls == 2


def test_chopo_client_rejects_external_redirect_before_requesting_target():
    class FakeClient:
        def __init__(self):
            self.calls = []

        def get(self, url, **kwargs):
            self.calls.append(url)
            return httpx.Response(
                302,
                headers={"Location": "https://evil.example/puebla/estudios"},
                request=httpx.Request("GET", url),
            )

    fake = FakeClient()
    client = ChopoClient(base_url="https://www.chopo.com.mx/puebla/estudios", client=fake)
    try:
        try:
            client.fetch_page(1)
        except ValueError as error:
            assert "left the configured host" in str(error)
        else:
            raise AssertionError("expected external redirect to fail")
    finally:
        client._client = None
    assert fake.calls == ["https://www.chopo.com.mx/puebla/estudios"]


def test_chopo_runtime_limits_reject_unbounded_configuration():
    with pytest.raises(ValueError, match="between 1 and 5"):
        ChopoClient(max_attempts=MAX_CHOPO_ATTEMPTS + 1)
    with pytest.raises(ValueError, match="between 1 and 500"):
        ChopoAdapter(ChopoClient(client=object()), max_pages=MAX_CHOPO_PAGES + 1)
    urls = [f"https://www.chopo.com.mx/puebla/{index}" for index in range(MAX_CHOPO_PRODUCTS + 1)]
    with pytest.raises(ValueError, match="too many"):
        from pruevia_collectors.providers.chopo import ChopoProductAdapter

        ChopoProductAdapter(ChopoClient(client=object()), urls)
