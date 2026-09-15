import asyncio
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage

import pytest

from pruevia_document_scanner.mail_worker import compose, portal_url, process_one


def job(kind="verification", **overrides):
    value = {
        "id": "00000000-0000-0000-0000-000000000010",
        "application_id": "00000000-0000-0000-0000-000000000011",
        "recipient": "representante@laboratorio.example",
        "kind": kind,
        "verification_code": "a" * 64,
        "expires_at": (datetime.now(timezone.utc) + timedelta(minutes=20)).isoformat(),
    }
    value.update(overrides)
    return value


def test_portal_url_is_https_origin_only():
    assert portal_url("https://app.example.com/") == "https://app.example.com/?provider=1"
    for value in (
        "http://app.example.com",
        "https://user:pass@app.example.com",
        "https://app.example.com/path",
        "https://app.example.com?x=1",
        "https://app.example.com#fragment",
        "https://app.example.com:444",
    ):
        with pytest.raises(ValueError):
            portal_url(value)


def test_verification_email_uses_fragment_and_no_patient_data():
    message = compose(job(), "avisos@example.com", "https://app.example.com")
    assert isinstance(message, EmailMessage)
    body = message.get_content()
    assert "?provider=1#application=00000000-0000-0000-0000-000000000011" in body
    assert "a" * 64 in body
    assert "paciente" not in body.lower()


@pytest.mark.parametrize("code", ["", "not-a-token", "B" * 64])
def test_invalid_verification_is_not_sent(code):
    with pytest.raises(ValueError, match="invalid_verification_code"):
        compose(job(verification_code=code), "avisos@example.com", "https://app.example.com")


def test_expired_verification_is_not_sent():
    expired = (datetime.now(timezone.utc) - timedelta(minutes=1)).isoformat()
    with pytest.raises(ValueError, match="verification_expired"):
        compose(job(expires_at=expired), "avisos@example.com", "https://app.example.com")


def test_process_one_confirms_the_same_lease_and_retries_on_smtp_error():
    class Store:
        def __init__(self):
            self.calls = []

        async def rpc(self, name, body):
            self.calls.append((name, body))
            if body["p_action"] == "lease":
                return job(kind="status", lease_id="00000000-0000-0000-0000-000000000012")
            return {"updated": True}

    async def scenario():
        store = Store()

        def fail(_message, _config):
            raise OSError("smtp unavailable")

        assert await process_one(store, {"SMTP_FROM": "avisos@example.com", "PROVIDER_PORTAL_ORIGIN": "https://app.example.com"}, fail)
        assert store.calls[-1] == (
            "api_server_provider_mail",
            {"p_action": "retry", "p_id": "00000000-0000-0000-0000-000000000010", "p_lease": "00000000-0000-0000-0000-000000000012"},
        )

    asyncio.run(scenario())
