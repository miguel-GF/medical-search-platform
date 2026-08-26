from pathlib import Path

import httpx

from pruevia_collectors.providers.chopo import ChopoClient, ChopoPage, ChopoListingParser, parse_chopo_page, parse_price_text


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


def test_chopo_parser_does_not_capture_search_autocomplete_items():
    parser = ChopoListingParser(page_url="https://www.chopo.com.mx/puebla/estudios")
    parser.feed('<dd><div class="product-name">AUTOCOMPLETE</div></dd>')
    assert parser.finish() == []


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
    assert all(call[1]["headers"]["User-Agent"] == "PrueviaCollector/0.1" for call in fake.calls)


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
