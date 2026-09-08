import socket

import httpx
import pytest

from pruevia_collectors.providers.public_transport import PublicAddressTransport, public_address


@pytest.mark.parametrize('address', ['127.0.0.1', '10.0.0.1', '169.254.169.254', '100.64.0.1', '224.0.0.1', '::1', '::ffff:127.0.0.1', '64:ff9b::a00:1', '2002:7f00:1::'])
def test_non_public_and_translation_addresses_are_rejected(address):
    assert not public_address(address)


def test_dns_result_is_pinned_without_losing_tls_hostname(monkeypatch):
    lookups = []

    def resolve(host, port, **_kwargs):
        lookups.append(host)
        address = '8.8.8.8' if len(lookups) == 1 else '127.0.0.1'
        return [(socket.AF_INET, socket.SOCK_STREAM, 6, '', (address, port))]

    monkeypatch.setattr(socket, 'getaddrinfo', resolve)
    transport = PublicAddressTransport()
    calls = []

    def send(request):
        calls.append(request)
        return httpx.Response(200, content=b'ok')

    monkeypatch.setattr(transport.transport, 'handle_request', send)
    with httpx.Client(transport=transport, trust_env=False) as client:
        response = client.get('https://provider.test/study')
        assert str(response.url) == 'https://provider.test/study'
        assert calls[0].url.host == '8.8.8.8'
        assert calls[0].headers['host'] == 'provider.test'
        assert calls[0].extensions['sni_hostname'] == 'provider.test'
        assert lookups == ['provider.test']
        with pytest.raises(ValueError, match='non-public'):
            client.get('https://provider.test/second')
        assert len(calls) == 1
