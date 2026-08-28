import json
from pathlib import Path

import httpx
import pytest

from pruevia_collectors.providers.generic import (
    GenericCrawlConfig,
    GenericPage,
    GenericPageParser,
    GenericProviderAdapter,
    GenericWebClient,
    decode_html,
    parse_price_minor,
)


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

    assert any(record.record_type == "provider_location_discovered" for record in records)
    assert any(record.record_type == "provider_offer_price" and record.payload["prices"] == {"regular": 25000} for record in records)
    assert any(record.payload.get("prices") == {"regular": 7500} for record in records)
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


def test_generic_config_rejects_multiple_hosts():
    with pytest.raises(ValueError, match="same host"):
        GenericProviderAdapter(GenericCrawlConfig(("https://a.example/", "https://b.example/")))
