"""Connect only to the public address that was actually validated."""

from __future__ import annotations

import ipaddress
import socket

import httpx


def public_address(value: str) -> bool:
    address = ipaddress.ip_address(value)
    if not address.is_global or address.is_multicast:
        return False
    if isinstance(address, ipaddress.IPv6Address):
        # Avoid address translation/tunnelling to IPv4 destinations that may
        # be private even when the containing IPv6 address is labelled global.
        if address.ipv4_mapped:
            return public_address(str(address.ipv4_mapped))
        if address.sixtofour or address.teredo:
            return False
        if address in ipaddress.ip_network('64:ff9b::/96') or address in ipaddress.ip_network('64:ff9b:1::/48'):
            return False
    return True


class PublicAddressTransport(httpx.BaseTransport):
    def __init__(self) -> None:
        # Pool keys are IPs after pinning, so disable keepalive to prevent a
        # connection/certificate for one hostname being reused for another.
        self.transport = httpx.HTTPTransport(
            trust_env=False, retries=0,
            limits=httpx.Limits(max_connections=10, max_keepalive_connections=0),
        )

    def handle_request(self, request: httpx.Request) -> httpx.Response:
        host = request.url.host
        port = request.url.port or (443 if request.url.scheme == 'https' else 80)
        if request.url.scheme not in ('http', 'https') or port not in (80, 443):
            raise ValueError('generic crawler accepts only standard HTTP(S) ports')
        addresses = list(dict.fromkeys(
            result[4][0] for result in socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)
        ))
        if not addresses or not all(public_address(value) for value in addresses):
            raise ValueError('generic crawler refuses non-public resolved addresses')
        # The socket receives a numeric address, never the hostname a second
        # time. Host and TLS certificate verification retain the original name.
        headers = httpx.Headers(request.headers)
        headers['Host'] = request.url.netloc.decode('ascii')
        pinned = httpx.Request(
            request.method, request.url.copy_with(host=addresses[0]),
            headers=headers, stream=request.stream,
            extensions={**request.extensions, 'sni_hostname': host},
        )
        return self.transport.handle_request(pinned)

    def close(self) -> None:
        self.transport.close()
