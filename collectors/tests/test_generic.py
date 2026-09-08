import json
from pathlib import Path
import socket

import httpx
import pytest

from pruevia_collectors.providers.generic import (
    MAX_HARD_SEEDS,
    GenericCrawlConfig,
    GenericPage,
    GenericPageParser,
    GenericProviderAdapter,
    GenericWebClient,
    _offer_record,
    decode_html,
    parse_price_minor,
)
from pruevia_collectors.pipeline import CollectorRunner


HTML = """
<html><head>
<meta property="og:site_name" content="Laboratorio La Esperanza">
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"MedicalClinic","name":"Laboratorio La Esperanza","telephone":"222 123 4567","address":{"streetAddress":"Av. Reforma 10","addressLocality":"Puebla","postalCode":"72000"},"geo":{"latitude":19.0437,"longitude":-98.1982}}
</script>
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"Product","name":"Biometría hemática","url":"/estudios/bh","offers":{"@type":"Offer","price":"250.00","priceCurrency":"MXN"}}
</script>
</head><body>
<h1>Biometría hemática</h1><p>Precio $250.00</p>
<a href="/estudios/ego">Examen general de orina</a>
<a href="https://other.example/afuera">afuera</a>
</body></html>
"""


def test_price_parser_supports_mexican_formats():
    assert parse_price_minor("$250.00") == 25000
    assert parse_price_minor("MXN 1,299.50") == 129950
    assert parse_price_minor("$1,500") == 150000
    assert parse_price_minor("sin costo") is None


def test_html_decoder_falls_back_for_legacy_pages():
    assert decode_html("Ultrasonido pélvico".encode("cp1252"), "utf-8") == "Ultrasonido pélvico"


def test_generic_parser_prefers_jsonld_and_extracts_location_offer():
    result = GenericPageParser().parse(GenericPage("https://lab.example/", HTML, "text/html"))

    assert result["provider_name"] == "Laboratorio La Esperanza"
    assert result["locations"][0]["coordinates"] == {"latitude": 19.0437, "longitude": -98.1982}
    assert result["offers"] == [
        {
            "name": "Biometría hemática",
            "price_minor": 25000,
            "url": "https://lab.example/estudios/bh",
            "method": "jsonld_offer",
        }
    ]
    assert "https://other.example/afuera" in result["links"]


def test_generic_parser_extracts_common_cms_script_studies():
    page = GenericPage(
        "https://lab.example/estudios",
        "<html><body><script>const data=[{\"title\":\"Glucosa\",\"precio\":\"89.00\"}];</script></body></html>",
        "text/html",
    )
    assert GenericPageParser().parse(page)["offers"] == [
        {
            "name": "Glucosa",
            "price_minor": 8900,
            "url": "https://lab.example/estudios",
            "method": "embedded_script_pattern",
        }
    ]


def test_generic_parser_does_not_turn_navigation_numbers_into_prices():
    page = GenericPage(
        "https://lab.example/",
        "<html><body><h2>Categorías</h2><p>15.6 Inch Touch Screen Teller</p>"
        "<h2>Tomografía</h2><p>Conoce nuestros servicios. Tel. 222 123 4567</p>"
        "<p>Más de 1,200 estudios</p></body></html>",
        "text/html",
    )
    assert GenericPageParser().parse(page)["offers"] == [
        {"name": "Tomografía", "price_minor": None, "url": "https://lab.example/", "method": "heading_pattern"}
    ]


def test_generic_parser_requires_explicit_price_context_for_visible_prices():
    page = GenericPage(
        "https://lab.example/",
        "<html><body><h2>Glucosa</h2><p>89.00</p></body></html>",
        "text/html",
    )
    assert GenericPageParser().parse(page)["offers"] == [
        {"name": "Glucosa", "price_minor": None, "url": "https://lab.example/", "method": "heading_pattern"}
    ]


def test_generic_parser_recovers_adjacent_elementor_prices_for_structured_services():
    page = GenericPage(
        "https://laboratorioasesores.com/servicio/",
        """
        <html><body>
          <script type="application/ld+json">
            {"@type":"MedicalClinic","name":"Asesores"}
          </script>
          <h2>Examen General de Orina</h2><h2>$129.00</h2>
          <h2>Insulina</h2><h2>$399.00</h2>
        </body></html>
        """,
        "text/html",
    )

    assert GenericPageParser().parse(page)["offers"] == [
        {
            "name": "Examen General de Orina",
            "price_minor": 12900,
            "url": "https://laboratorioasesores.com/servicio/",
            "method": "price_pattern",
        },
        {
            "name": "Insulina",
            "price_minor": 39900,
            "url": "https://laboratorioasesores.com/servicio/",
            "method": "price_pattern",
        },
    ]


def test_generic_parser_never_emits_script_links():
    page = GenericPage(
        "https://lab.example/estudios",
        """
        <script type="application/ld+json">
        {"@type":"Service","name":"EGO","url":"javascript:alert(1)"}
        </script>
        """,
        "text/html",
    )
    offers = GenericPageParser().parse(page)["offers"]
    assert offers[0]["url"] == "https://lab.example/estudios"


def test_generic_artifacts_strip_signed_query_material_from_page_and_product_urls():
    page = GenericPage("https://lab.example/estudios?page=2&session=private-value", "", "text/html")
    record = _offer_record(
        "generic_lab",
        page,
        "Laboratorio",
        {"name": "Glucosa", "url": "/estudios/glucosa?sig=private-value", "price_minor": 8900, "method": "jsonld_offer"},
    )
    assert record.source_url == "https://lab.example/estudios"
    assert record.payload["product_url"] == "https://lab.example/estudios/glucosa"
    assert record.payload["evidence_page_url"] == "https://lab.example/estudios"
    assert all("private-value" not in str(value) for value in (record.source_url, record.payload))


def test_generic_source_endpoint_does_not_persist_seed_query_material():
    class StubClient:
        allowed_hosts = {"testserver", "www.testserver"}

    adapter = GenericProviderAdapter(
        GenericCrawlConfig(("https://testserver/catalog?session=private-value",), max_pages=1),
        client=StubClient(),
    )
    assert adapter.source.endpoint_url == "https://testserver/catalog"


def test_generic_parser_drops_nonclinical_product_jsonld():
    page = GenericPage(
        "https://lab.example/",
        '<script type="application/ld+json">{"@type":"Product","name":"Crema hidratante","offers":{"@type":"Offer","price":"250"}}</script>',
        "text/html",
    )

    assert GenericPageParser().parse(page)["offers"] == []


def test_generic_parser_bounds_hostile_tag_and_link_fanout():
    page = GenericPage(
        "https://lab.example/",
        "<body>" + "<a href='/x'>x</a>" * 3_000 + "<h2>Glucosa</h2>" * 700 + "</body>",
        "text/html",
    )
    result = GenericPageParser().parse(page)
    assert len(result["links"]) <= 2_000
    assert len(result["headings"]) <= 500
    assert len(result["evidence_text"]) <= 4_000


def test_generic_parser_handles_deep_jsonld_without_recursion_failure():
    nested: object = {"@type": "MedicalTest", "name": "Glucosa"}
    for _ in range(200):
        nested = [nested]
    page = GenericPage(
        "https://lab.example/",
        '<script type="application/ld+json">' + json.dumps(nested) + "</script>",
        "text/html",
    )
    result = GenericPageParser().parse(page)
    assert isinstance(result["offers"], list)


def test_generic_adapter_is_bounded_to_seed_host_and_emits_evidence(tmp_path: Path):
    calls: list[str] = []

    def handler(request: httpx.Request):
        calls.append(str(request.url))
        if request.url.path == "/":
            return httpx.Response(200, text=HTML, headers={"content-type": "text/html"}, request=request)
        return httpx.Response(200, text="<h2>Examen general de orina</h2><p>Precio $75</p>", headers={"content-type": "text/html"}, request=request)

    transport_client = httpx.Client(transport=httpx.MockTransport(handler), follow_redirects=True)
    web_client = GenericWebClient(
        ["http://testserver/"],
        allow_private_hosts=True,
        respect_robots=False,
        client=transport_client,
    )
    adapter = GenericProviderAdapter(
        GenericCrawlConfig(("http://testserver/",), max_pages=4, max_depth=1, delay_seconds=0),
        client=web_client,
        source_key="generic_testserver",
    )
    try:
        records = list(adapter.collect())
    finally:
        transport_client.close()

    assert adapter.source.source_type == "public_website"
    assert any(record.record_type == "provider_location_discovered" for record in records)
    assert any(record.record_type == "provider_offer_price" and record.payload["prices"] == {"regular": 25000} for record in records)
    assert any(record.payload.get("prices") == {"regular": 7500} for record in records)
    price_record = next(record for record in records if record.record_type == "provider_offer_price")
    assert all(observation.confidence == 0.90 for observation in price_record.observations)
    assert all("other.example" not in url for url in calls)
    assert len(calls) == 2


def test_generic_client_rejects_credentials_and_private_hosts():
    with pytest.raises(ValueError, match="without credentials"):
        GenericWebClient(["https://user:pass@example.com/"])

    client = GenericWebClient(["http://127.0.0.1/"])
    try:
        with pytest.raises(ValueError, match="private"):
            client.fetch("http://127.0.0.1/")
    finally:
        client.close()

    with pytest.raises(ValueError, match="standard HTTP"):
        GenericWebClient(["https://example.com:8443/"])

    with pytest.raises(ValueError, match="between 16384 and 10000000"):
        GenericWebClient(["https://example.com/"], max_response_bytes=100_000_001)


def test_generic_client_allows_only_apex_www_redirect_pair():
    def handler(request: httpx.Request):
        if request.url.host == "testserver":
            return httpx.Response(302, headers={"location": "https://www.testserver/"}, request=request)
        return httpx.Response(200, text="<h1>Laboratorio</h1>", headers={"content-type": "text/html"}, request=request)

    http_client = httpx.Client(transport=httpx.MockTransport(handler), follow_redirects=True)
    client = GenericWebClient(
        ["https://testserver/"],
        allow_private_hosts=True,
        respect_robots=False,
        client=http_client,
    )
    try:
        assert client.fetch("https://testserver/").url == "https://www.testserver/"
        assert "evil.testserver" not in client.allowed_hosts
    finally:
        http_client.close()


def test_generic_client_rejects_external_redirect_before_requesting_target():
    calls: list[str] = []

    def handler(request: httpx.Request):
        calls.append(str(request.url))
        if request.url.host == "testserver":
            return httpx.Response(302, headers={"location": "https://evil.example/"}, request=request)
        return httpx.Response(200, text="<h1>unexpected</h1>", headers={"content-type": "text/html"}, request=request)

    http_client = httpx.Client(transport=httpx.MockTransport(handler), follow_redirects=True)
    client = GenericWebClient(
        ["https://testserver/"],
        allow_private_hosts=True,
        respect_robots=False,
        client=http_client,
    )
    try:
        with pytest.raises(RuntimeError, match="outside the seed host"):
            client.fetch("https://testserver/")
    finally:
        http_client.close()
    assert calls == ["https://testserver/"]


def test_generic_client_streams_and_rejects_oversized_bodies():
    def handler(request: httpx.Request):
        return httpx.Response(
            200,
            content=b"x" * 20_000,
            headers={"content-type": "text/html"},
            request=request,
        )

    http_client = httpx.Client(transport=httpx.MockTransport(handler))
    client = GenericWebClient(
        ["http://testserver/"],
        allow_private_hosts=True,
        respect_robots=False,
        max_response_bytes=16_384,
        client=http_client,
    )
    try:
        with pytest.raises(RuntimeError, match="max_response_bytes"):
            client.fetch("http://testserver/")
    finally:
        http_client.close()


def test_generic_client_enforces_total_response_wall_clock(monkeypatch: pytest.MonkeyPatch):
    ticks = iter((0.0, 61.0))
    monkeypatch.setattr("pruevia_collectors.providers.generic.time.monotonic", lambda: next(ticks))

    def handler(request: httpx.Request):
        return httpx.Response(200, content=b"ok", headers={"content-type": "text/html"}, request=request)

    http_client = httpx.Client(transport=httpx.MockTransport(handler))
    client = GenericWebClient(
        ["http://testserver/"],
        allow_private_hosts=True,
        respect_robots=False,
        client=http_client,
    )
    try:
        with pytest.raises(RuntimeError, match="max_response_seconds"):
            client.fetch("http://testserver/")
    finally:
        http_client.close()


def test_generic_client_rejects_private_connected_peer(monkeypatch: pytest.MonkeyPatch):
    class PrivatePeer:
        def get_extra_info(self, name: str):
            return ("127.0.0.1", 443) if name == "server_addr" else None

    monkeypatch.setattr(
        "pruevia_collectors.providers.generic.socket.getaddrinfo",
        lambda *_args, **_kwargs: [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("8.8.8.8", 443))],
    )

    def handler(request: httpx.Request):
        return httpx.Response(
            200,
            text="<h1>unexpected</h1>",
            headers={"content-type": "text/html"},
            extensions={"network_stream": PrivatePeer()},
            request=request,
        )

    http_client = httpx.Client(transport=httpx.MockTransport(handler))
    client = GenericWebClient(["https://example.com/"], respect_robots=False, client=http_client)
    try:
        with pytest.raises(RuntimeError, match="non-global connected peer"):
            client.fetch("https://example.com/")
    finally:
        http_client.close()


def test_generic_client_honors_robots_txt():
    def handler(request: httpx.Request):
        if request.url.path == "/robots.txt":
            return httpx.Response(200, text="User-agent: *\nDisallow: /private\n", request=request)
        return httpx.Response(200, text="<h1>Laboratorio</h1>", headers={"content-type": "text/html"}, request=request)

    http_client = httpx.Client(transport=httpx.MockTransport(handler), follow_redirects=True)
    client = GenericWebClient(["http://testserver/"], allow_private_hosts=True, client=http_client)
    try:
        assert client.fetch("http://testserver/").url == "http://testserver/"
        with pytest.raises(ValueError, match="robots"):
            client.fetch("http://testserver/private")
    finally:
        http_client.close()


def test_generic_transport_failure_is_not_reported_as_success(tmp_path: Path):
    def handler(request: httpx.Request):
        return httpx.Response(503, request=request)

    http_client = httpx.Client(transport=httpx.MockTransport(handler), follow_redirects=True)
    web_client = GenericWebClient(
        ["http://testserver/"],
        allow_private_hosts=True,
        respect_robots=False,
        max_attempts=1,
        client=http_client,
    )
    adapter = GenericProviderAdapter(
        GenericCrawlConfig(("http://testserver/",), max_pages=1, max_depth=0, delay_seconds=0),
        client=web_client,
    )
    try:
        summary = CollectorRunner(tmp_path).run(adapter)
    finally:
        http_client.close()
    assert summary.status == "failed"
    assert summary.records_valid == 0
    assert summary.errors


def test_generic_config_rejects_multiple_hosts():
    with pytest.raises(ValueError, match="same host"):
        GenericProviderAdapter(GenericCrawlConfig(("https://a.example/", "https://b.example/")))

    with pytest.raises(ValueError, match="between 1 and 500"):
        GenericCrawlConfig(("https://example/",), max_pages=501)
    with pytest.raises(ValueError, match="between 0 and 5"):
        GenericCrawlConfig(("https://example/",), max_depth=6)
    with pytest.raises(ValueError, match="at most 20"):
        GenericCrawlConfig(tuple(f"https://example/{index}" for index in range(MAX_HARD_SEEDS + 1)))


def test_generic_config_treats_apex_and_www_as_one_site():
    client = GenericWebClient(
        ("https://example/", "https://www.example/"),
        allow_private_hosts=True,
        respect_robots=False,
    )
    adapter = GenericProviderAdapter(
        GenericCrawlConfig(("https://example/", "https://www.example/")),
        client=client,
    )
    client.close()

    assert adapter.source.source_key == "generic_example"
