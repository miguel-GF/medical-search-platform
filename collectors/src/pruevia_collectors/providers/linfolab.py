"""Collector for Linfolab's public Puebla branch directory.

The directory is a server-rendered public page.  This adapter records branch
identity, the address published in the branch's Google Maps link, and the
hours shown on the page as provider evidence.  It does not call Maps, infer a
catalog or prices, or treat a DENUE row as proof of a clinical offer.
"""

from __future__ import annotations

import html as html_module
import re
import ssl
import unicodedata
from collections.abc import Iterable, Mapping
from html import unescape
from math import isfinite
from urllib import robotparser
from urllib.parse import parse_qs, unquote_plus, urlparse

import certifi
import httpx

try:
    import truststore
except ImportError:  # pragma: no cover - dependency is installed in supported environments
    truststore = None  # type: ignore[assignment]

from ..models import Observation, SourceRecord, SourceSpec
from .http import bounded_response_bytes, request_with_same_host_redirects
from .public_transport import PublicAddressTransport


LINFO_ORIGIN = "https://linfolabmexico.com.mx"
LINFO_BRANCHES_URL = f"{LINFO_ORIGIN}/sucursales/"
LINFO_ROBOTS_URL = f"{LINFO_ORIGIN}/robots.txt"
LINFO_USER_AGENT = "PrueviaLinfolabCollector/0.1 (+https://pruevia.local/collector)"
MAX_LINFO_BRANCHES = 40
MAX_LINFO_HTML_BYTES = 2 * 1024 * 1024
MAX_LINFO_ROBOTS_BYTES = 256 * 1024
MAX_LINFO_FIELD_CHARS = 4_000
MAX_LINFO_TIMEOUT_SECONDS = 120.0


def _ssl_context() -> ssl.SSLContext:
    if truststore is not None:
        return truststore.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    return ssl.create_default_context(cafile=certifi.where())


def _text(value: object, field: str, *, required: bool = False) -> str:
    result = " ".join(str(value or "").split()).strip()
    if len(result) > MAX_LINFO_FIELD_CHARS:
        raise ValueError(f"{field} exceeds the text limit")
    if required and not result:
        raise ValueError(f"{field} is required")
    return result


def _repair_text(value: object) -> str:
    text = _text(value, "value")
    # A proxy occasionally labels UTF-8 as Latin-1.  Repair only the common
    # mojibake markers and leave legitimate provider text untouched.
    for _ in range(2):
        if not any(marker in text for marker in ("Ã", "Â", "�")):
            break
        try:
            candidate = text.encode("latin-1").decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError):
            break
        if candidate == text or candidate.count("�") > text.count("�"):
            break
        text = candidate
    return text


def _normalize(value: object) -> str:
    folded = unicodedata.normalize("NFKD", _repair_text(value).casefold())
    plain = "".join(char for char in folded if not unicodedata.combining(char))
    return re.sub(r"[^a-z0-9]+", " ", plain).strip()


def _branch_id(name: str) -> str:
    value = re.sub(r"[^a-z0-9]+", "-", _normalize(name)).strip("-")
    if not value or len(value) > 64:
        raise ValueError("Linfolab branch id is invalid")
    return value


def _coordinates(map_url: str) -> dict[str, float] | None:
    # Destination coordinates are encoded as !1d<longitude>!2d<latitude>.
    match = re.search(r"!1d(-?\d+(?:\.\d+)?)!2d(-?\d+(?:\.\d+)?)", map_url)
    if match is None:
        return None
    try:
        longitude, latitude = float(match.group(1)), float(match.group(2))
    except ValueError:
        return None
    if not all(isfinite(item) for item in (latitude, longitude)):
        return None
    if not -90 <= latitude <= 90 or not -180 <= longitude <= 180:
        return None
    return {"latitude": latitude, "longitude": longitude}


def _map_address(map_url: str) -> str | None:
    parsed = urlparse(map_url)
    if parsed.scheme != "https" or (parsed.hostname or "").casefold() not in {"www.google.com", "google.com"}:
        return None
    query = parse_qs(parsed.query, keep_blank_values=False)
    values = query.get("daddr")
    if values:
        return _text(values[0], "map address") or None
    # Gabriel Pastor uses the /dir//<address>/ form instead of daddr.
    match = re.search(r"/maps/dir//([^/@?]+)", parsed.path, flags=re.IGNORECASE)
    if match:
        value = unquote_plus(match.group(1)).replace("+", " ")
        return _text(value, "map address") or None
    return None


def _html_text(value: str) -> str:
    return " ".join(re.sub(r"<[^>]+>", " ", unescape(value)).split())


def parse_branches(page_html: str) -> list[Mapping[str, object]]:
    """Parse address-bearing branch cards from the public directory."""

    if not isinstance(page_html, str) or len(page_html.encode("utf-8")) > MAX_LINFO_HTML_BYTES:
        raise ValueError("Linfolab branch page exceeds the safety limit")
    headings = list(re.finditer(r"<h2\b[^>]*>(.*?)</h2\s*>", page_html, flags=re.IGNORECASE | re.DOTALL))
    rows: list[Mapping[str, object]] = []
    seen: set[str] = set()
    ignored = {"sucursales", "nosotros", "blog", "promociones", "preguntas frecuentes", "empresariales"}
    for index, heading in enumerate(headings):
        name = _html_text(heading.group(1))
        normalized_name = _normalize(name)
        if not normalized_name or normalized_name in ignored or normalized_name.startswith("ubica la sucursal"):
            continue
        end = headings[index + 1].start() if index + 1 < len(headings) else len(page_html)
        section = page_html[heading.end() : end]
        links = re.findall(r"href\s*=\s*[\"']([^\"']*google\.com/maps[^\"']*)[\"']", section, flags=re.IGNORECASE)
        if not links:
            continue
        map_url = html_module.unescape(links[0])
        address = _map_address(map_url)
        if not address:
            # Cards such as CAPU and Xonaca currently link only to a named
            # Maps place; keep them out until the official page exposes an
            # auditable address.
            continue
        normalized_address = _normalize(address)
        if "puebla" not in normalized_address and "pue" not in normalized_address:
            continue
        branch_id = _branch_id(name)
        if branch_id in seen:
            continue
        hours = [
            _html_text(value)
            for value in re.findall(
                r"<span[^>]*class=[\"'][^\"']*elementor-icon-list-text[^\"']*[\"'][^>]*>(.*?)</span>",
                section,
                flags=re.IGNORECASE | re.DOTALL,
            )
        ]
        hours = [value for value in hours if value]
        rows.append(
            {
                "branch_id": branch_id,
                "name": _text(name, "branch name", required=True),
                "address": _text(address, "branch address", required=True),
                "map_url": map_url[:MAX_LINFO_FIELD_CHARS],
                "coordinates": _coordinates(map_url),
                "hours": hours[:14],
            }
        )
        seen.add(branch_id)
    if len(rows) > MAX_LINFO_BRANCHES:
        raise ValueError("Linfolab branch count exceeds the safety limit")
    return rows


def branch_to_record(row: Mapping[str, object]) -> SourceRecord:
    branch_id = _text(row.get("branch_id"), "branch_id", required=True)
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", branch_id):
        raise ValueError("Linfolab branch id is invalid")
    name = _text(row.get("name"), "name", required=True)
    address_text = _text(row.get("address"), "address", required=True)
    coordinates = row.get("coordinates")
    if coordinates is not None:
        if not isinstance(coordinates, Mapping):
            raise ValueError("Linfolab coordinates must be an object or null")
        try:
            latitude, longitude = float(coordinates["latitude"]), float(coordinates["longitude"])
        except (KeyError, TypeError, ValueError) as error:
            raise ValueError("Linfolab coordinates are invalid") from error
        if not all(isfinite(item) for item in (latitude, longitude)) or not -90 <= latitude <= 90 or not -180 <= longitude <= 180:
            raise ValueError("Linfolab coordinates are outside bounds")
        coordinates = {"latitude": latitude, "longitude": longitude}
    payload = {
        "provider_brand": "Linfolab",
        "market": "Puebla",
        "provider_display_name": name,
        "provider_external_id": branch_id,
        "location_name": name,
        "location_url": LINFO_BRANCHES_URL,
        "address": {"text": address_text},
        "coordinates": coordinates,
        "hours": row.get("hours") or None,
        "claim_status": "candidate",
        "evidence_note": "Official public branch directory; clinical studies, prices and availability require separate verification.",
    }
    observations = (
        Observation(entity_type="provider_location", attribute_name="provider_display_name", observed_value=name, confidence=0.98),
        Observation(entity_type="provider_location", attribute_name="address", observed_value=payload["address"], confidence=0.95),
        Observation(entity_type="provider_location", attribute_name="coordinates", observed_value=coordinates, confidence=0.90 if coordinates else 0.0),
        Observation(entity_type="provider_location", attribute_name="hours", observed_value=payload["hours"], confidence=0.90),
    )
    return SourceRecord(
        source_key="linfolab_puebla",
        record_type="provider_location_discovered",
        external_record_id=branch_id,
        source_url=LINFO_BRANCHES_URL,
        payload=payload,
        observations=observations,
    )


class LinfolabClient:
    def __init__(
        self,
        *,
        branches_url: str = LINFO_BRANCHES_URL,
        timeout_seconds: float = 30.0,
        respect_robots: bool = True,
        client: httpx.Client | None = None,
    ) -> None:
        for field, url in (("branches_url", branches_url), ("robots_url", LINFO_ROBOTS_URL)):
            parsed = urlparse(url)
            if (
                parsed.scheme != "https"
                or (parsed.hostname or "").casefold() != urlparse(LINFO_ORIGIN).hostname.casefold()
                or parsed.username
                or parsed.password
                or parsed.port not in (None, 443)
                or parsed.query
                or parsed.fragment
                or (field == "branches_url" and parsed.path.rstrip("/") != "/sucursales")
            ):
                raise ValueError(f"Linfolab {field} must be an official HTTPS URL without credentials or query parameters")
        if not 0 < timeout_seconds <= MAX_LINFO_TIMEOUT_SECONDS or not isfinite(float(timeout_seconds)):
            raise ValueError("timeout_seconds must be between 0 and 120")
        self.branches_url = branches_url
        self.timeout_seconds = float(timeout_seconds)
        self.respect_robots = respect_robots
        self._robots: robotparser.RobotFileParser | None = None
        self._robots_loaded = False
        self._owns_client = client is None
        self._client = client or httpx.Client(
            timeout=self.timeout_seconds,
            follow_redirects=False,
            trust_env=False,
            transport=PublicAddressTransport(),
            verify=_ssl_context(),
        )

    def close(self) -> None:
        if self._owns_client:
            self._client.close()

    def _allowed_by_robots(self, url: str) -> bool:
        if not self.respect_robots:
            return True
        if not self._robots_loaded:
            parser = robotparser.RobotFileParser()
            response: httpx.Response | None = None
            try:
                response = request_with_same_host_redirects(
                    self._client.get,
                    LINFO_ROBOTS_URL,
                    allowed_url=LINFO_ORIGIN,
                    max_redirects=3,
                    headers={"Accept": "text/plain", "User-Agent": LINFO_USER_AGENT, "Accept-Encoding": "identity"},
                )
                if response.status_code in {404, 410}:
                    self._robots = None
                elif response.status_code >= 400:
                    parser.parse(["User-agent: *", "Disallow: /"])
                    self._robots = parser
                else:
                    body = bounded_response_bytes(response, max_bytes=MAX_LINFO_ROBOTS_BYTES)
                    parser.parse(body.decode("utf-8", "replace").splitlines())
                    self._robots = parser
            except (httpx.HTTPError, ValueError, UnicodeError):
                parser.parse(["User-agent: *", "Disallow: /"])
                self._robots = parser
            finally:
                if response is not None:
                    response.close()
            self._robots_loaded = True
        return self._robots is None or self._robots.can_fetch(LINFO_USER_AGENT, url)

    def fetch_branches(self) -> list[Mapping[str, object]]:
        if not self._allowed_by_robots(self.branches_url):
            raise ValueError("Linfolab branch endpoint is disallowed by robots.txt")
        response = request_with_same_host_redirects(
            self._client.get,
            self.branches_url,
            allowed_url=LINFO_ORIGIN,
            max_redirects=3,
            headers={"Accept": "text/html,application/xhtml+xml", "User-Agent": LINFO_USER_AGENT, "Accept-Encoding": "identity"},
        )
        try:
            response.raise_for_status()
            return parse_branches(bounded_response_bytes(response, max_bytes=MAX_LINFO_HTML_BYTES).decode("utf-8", "replace"))
        finally:
            response.close()


class LinfolabAdapter:
    source = SourceSpec(
        source_key="linfolab_puebla",
        name="Linfolab — sucursales públicas de Puebla",
        source_type="provider_official",
        usage_policy_status="review_required",
        expected_min_records=1,
        expected_max_records=MAX_LINFO_BRANCHES,
        endpoint_type="html",
        endpoint_url=LINFO_BRANCHES_URL,
        parser_version="0.1.0",
    )

    def __init__(self, client: LinfolabClient) -> None:
        self.client = client

    def collect(self) -> Iterable[SourceRecord]:
        seen: set[str] = set()
        for row in self.client.fetch_branches():
            record = branch_to_record(row)
            if record.external_record_id in seen:
                raise ValueError(f"duplicate Linfolab branch: {record.external_record_id}")
            seen.add(str(record.external_record_id))
            yield record


__all__ = ["LINFO_BRANCHES_URL", "LINFO_ORIGIN", "LinfolabAdapter", "LinfolabClient", "branch_to_record", "parse_branches"]
