import httpx
import pytest

from pruevia_collectors.providers.linfolab import (
    LINFO_BRANCHES_URL,
    LINFO_ORIGIN,
    LINFO_ROBOTS_URL,
    LinfolabAdapter,
    LinfolabClient,
    parse_branches,
)


PAGE = """
<h2 class="elementor-heading-title">GABRIEL PASTOR</h2>
<span class="elementor-icon-list-text">Lunes a viernes de 06:00 hrs a 17:30 hrs</span>
<a href="https://www.google.com/maps/dir//C.+7+Sur+3701-101,+Gabriel+Pastor,+72420+Puebla,+Pue./@19.03,-98.2,12z/data=!1d-98.2117502!2d19.032662">Ir</a>
<h2>ZAVALETA</h2>
<a href="https://www.google.com/maps?daddr=Antiguo+Camino+Real+a+Cholula+5207,+72150+Puebla,+Pue.">Ir</a>
<h2>CAPU</h2>
<a href="https://www.google.com/maps/dir//linfolab+capu/data=!4m6">Ir</a>
<h2>OTRA CIUDAD</h2>
<a href="https://www.google.com/maps?daddr=Av.+Central+1,+Toluca,+Estado+de+Mexico">Ir</a>
"""


def test_parse_branches_keeps_address_bearing_puebla_cards():
    rows = parse_branches(PAGE)
    assert [row["branch_id"] for row in rows] == ["gabriel-pastor", "zavaleta"]
    assert rows[0]["coordinates"] == {"latitude": 19.032662, "longitude": -98.2117502}
    assert "7 Sur 3701-101" in rows[0]["address"]
    assert rows[1]["coordinates"] is None


def test_client_honors_robots_before_fetching_page():
    calls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(str(request.url))
        if str(request.url) == LINFO_ROBOTS_URL:
            return httpx.Response(200, text="User-agent: *\nDisallow: /sucursales/\n", request=request)
        return httpx.Response(200, text=PAGE, headers={"content-type": "text/html"}, request=request)

    client = LinfolabClient(client=httpx.Client(transport=httpx.MockTransport(handler), follow_redirects=False))
    try:
        with pytest.raises(ValueError, match="disallowed"):
            client.fetch_branches()
    finally:
        client.close()
    assert calls == [LINFO_ROBOTS_URL]


def test_client_and_adapter_capture_public_page_only():
    calls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(str(request.url))
        if str(request.url) == LINFO_ROBOTS_URL:
            return httpx.Response(404, request=request)
        return httpx.Response(200, content=PAGE.encode(), headers={"content-type": "text/html"}, request=request)

    client = LinfolabClient(client=httpx.Client(transport=httpx.MockTransport(handler), follow_redirects=False))
    try:
        records = list(LinfolabAdapter(client).collect())
    finally:
        client.close()
    assert [record.external_record_id for record in records] == ["gabriel-pastor", "zavaleta"]
    assert all(record.source_url == LINFO_BRANCHES_URL for record in records)
    assert calls == [LINFO_ROBOTS_URL, LINFO_BRANCHES_URL]


def test_client_rejects_non_official_urls():
    with pytest.raises(ValueError, match="official HTTPS"):
        LinfolabClient(branches_url="https://example.test/sucursales/")

