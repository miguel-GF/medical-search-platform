import json
import sys
from pathlib import Path

import httpx
import pytest

from pruevia_collectors.providers.denue import DenueQuery, denue_row_to_record


def load_sample():
    path = Path(__file__).parent / "fixtures" / "denue_sample.json"
    return json.loads(path.read_text(encoding="utf-8"))[0]


def test_denue_row_becomes_location_record_with_observations():
    query = DenueQuery("laboratorio", 19.0437, -98.1982)
    record = denue_row_to_record(load_sample(), query=query)

    assert record.source_key == "denue"
    assert record.record_type == "provider_location_discovered"
    assert record.external_record_id == "900001"
    assert record.payload["_denue_query"]["radius_meters"] == 5000
    attributes = {observation.attribute_name for observation in record.observations}
    assert {"name", "legal_name", "address", "coordinates"}.issubset(attributes)
    assert "AQUÍ" not in record.source_url


def test_denue_row_accepts_case_and_separator_variants():
    row = {"id_establecimiento": "x-1", "nombre_establecimiento": "Clínica", "latitud": "19", "longitud": "-98"}
    record = denue_row_to_record(row)
    assert record.external_record_id == "x-1"
    assert any(observation.attribute_name == "name" for observation in record.observations)


def test_denue_response_decoder_handles_wrapped_payload():
    from pruevia_collectors.providers.denue import _decode_rows

    rows = _decode_rows({"Data": [load_sample()]})
    assert len(rows) == 1
    assert rows[0]["Id"] == "900001"


def test_denue_client_rejects_invalid_radius():
    try:
        DenueQuery("laboratorio", 19.0, -98.0, radius_meters=5001)
    except ValueError as error:
        assert "5000" in str(error)
    else:
        raise AssertionError("expected invalid radius to fail")


def test_denue_query_rejects_invalid_coordinates_and_controlled_condition():
    with pytest.raises(ValueError, match="latitude"):
        DenueQuery("laboratorio", 91, -98)
    with pytest.raises(ValueError, match="longitude"):
        DenueQuery("laboratorio", 19, float("nan"))
    with pytest.raises(ValueError, match="condition"):
        DenueQuery("x" * 257, 19, -98)


def test_denue_client_rejects_non_official_base_before_token_can_leak():
    from pruevia_collectors.providers.denue import DenueClient

    with pytest.raises(ValueError, match="official HTTPS endpoint"):
        DenueClient(token="secret-token-123", base_url="https://evil.example/denue")


def test_denue_client_redacts_token_from_transport_errors():
    from pruevia_collectors.providers.denue import DenueClient

    token = "secret-token-123"

    class FailingClient:
        def get(self, url, **kwargs):
            request = httpx.Request("GET", url)
            response = httpx.Response(500, request=request)
            response.raise_for_status()

    client = DenueClient(token=token, client=FailingClient())
    try:
        try:
            client.search(DenueQuery("laboratorio", 19.04, -98.20))
        except RuntimeError as error:
            assert token not in str(error)
            assert "[REDACTED]" in str(error)
        else:
            raise AssertionError("expected DENUE request failure")
    finally:
        client._client = None


def test_denue_client_rejects_external_redirect_before_requesting_target():
    from pruevia_collectors.providers.denue import DenueClient

    calls = []

    def handler(request: httpx.Request):
        calls.append(str(request.url))
        return httpx.Response(302, headers={"Location": "https://evil.example/steal"}, request=request)

    client = DenueClient(
        token="secret-token-123",
        client=httpx.Client(transport=httpx.MockTransport(handler)),
    )
    try:
        with pytest.raises(ValueError, match="left the configured host"):
            client.search(DenueQuery("laboratorio", 19.04, -98.20))
    finally:
        client._client.close()
    assert len(calls) == 1


def test_denue_cli_reports_missing_token_without_traceback(monkeypatch, capsys, tmp_path):
    from pruevia_collectors import cli

    monkeypatch.delenv("DENUE_API_TOKEN", raising=False)
    monkeypatch.setattr(
        sys,
        "argv",
        ["pruevia-denue", "--latitude", "19.04", "--longitude", "-98.20", "--artifact-root", str(tmp_path)],
    )
    assert cli.main() == 2
    assert '"status": "blocked"' in capsys.readouterr().out
