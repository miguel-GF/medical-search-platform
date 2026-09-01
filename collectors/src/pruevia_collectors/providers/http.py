"""Small HTTP safety primitives shared by provider-specific collectors."""

from __future__ import annotations

from collections.abc import Callable
from urllib.parse import urljoin, urlparse

import httpx


REDIRECT_STATUSES = frozenset({301, 302, 303, 307, 308})
MAX_REDIRECTS = 5


def request_with_same_host_redirects(
    request: Callable[..., httpx.Response],
    url: str,
    *,
    allowed_url: str,
    max_redirects: int = MAX_REDIRECTS,
    **kwargs: object,
) -> httpx.Response:
    """Follow only bounded redirects that stay on the configured origin.

    ``httpx`` otherwise follows a redirect before callers can inspect its final
    URL. Provider URLs can contain credentials/tokens, so every redirect target
    is validated before any request is made to it.
    """

    if not 0 <= max_redirects <= MAX_REDIRECTS:
        raise ValueError("max_redirects must be between 0 and 5")
    expected = urlparse(allowed_url)
    if expected.scheme not in {"http", "https"} or not expected.hostname:
        raise ValueError("allowed_url must be an absolute HTTP(S) URL")
    expected_host = expected.hostname.casefold().rstrip(".")
    expected_port = expected.port or (443 if expected.scheme == "https" else 80)

    current = url
    _validate_target(current, expected.scheme, expected_host, expected_port)
    for redirect_count in range(max_redirects + 1):
        response = request(current, follow_redirects=False, **kwargs)
        if response.status_code not in REDIRECT_STATUSES:
            _validate_target(str(response.url), expected.scheme, expected_host, expected_port)
            return response
        if redirect_count >= max_redirects:
            raise ValueError("provider request exceeded max_redirects")
        location = response.headers.get("location", "").strip()
        if not location:
            raise ValueError("provider redirect has no Location header")
        current = urljoin(current, location)
        _validate_target(current, expected.scheme, expected_host, expected_port)
    raise ValueError("provider request exceeded max_redirects")


def _validate_target(value: str, scheme: str, host: str, port: int) -> None:
    parsed = urlparse(value)
    if parsed.scheme != scheme or parsed.hostname is None:
        raise ValueError("provider redirect changed scheme or host")
    if parsed.hostname.casefold().rstrip(".") != host:
        raise ValueError("provider redirect left the configured host")
    if parsed.username or parsed.password:
        raise ValueError("provider URL cannot contain credentials")
    if (parsed.port or (443 if parsed.scheme == "https" else 80)) != port:
        raise ValueError("provider redirect changed port")
