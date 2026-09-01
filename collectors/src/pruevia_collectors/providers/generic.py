"""Bounded, provider-agnostic web discovery for smaller laboratories.

The generic collector is deliberately conservative.  It stays on the supplied
host(s), follows a small bounded number of HTML links, prefers schema.org
JSON-LD, and only emits candidate evidence.  It never turns a heading or a
price-looking string into an approved catalog item by itself.
"""

from __future__ import annotations

import hashlib
import html as html_lib
import ipaddress
import json
import re
import socket
import time
import unicodedata
from collections import deque
from dataclasses import dataclass
from html.parser import HTMLParser
from math import isfinite
from typing import Any, Iterable, Mapping, Sequence
from urllib.robotparser import RobotFileParser
from urllib.parse import urldefrag, urljoin, urlparse

import httpx

from ..models import Observation, SourceRecord, SourceSpec


MAX_DEFAULT_RESPONSE_BYTES = 2_000_000
MAX_HARD_RESPONSE_BYTES = 10_000_000
MAX_HARD_PAGES = 500
MAX_HARD_DEPTH = 5
MAX_HARD_DELAY_SECONDS = 60.0
MAX_HARD_ATTEMPTS = 5
MAX_HARD_REDIRECTS = 10
MAX_DEFAULT_REDIRECTS = 5
DEFAULT_USER_AGENT = "PrueviaGenericCollector/0.1 (+https://pruevia.local/collector)"
GENERIC_PARSER_VERSION = "0.1.0"
PRICE_RE = re.compile(
    r"(?<![\w])(?:MXN\s*)?(?:\$\s*)?([0-9]{1,3}(?:[,.][0-9]{3})*(?:[,.][0-9]{1,2})?|[0-9]+(?:[,.][0-9]{1,2})?)(?:\s*MXN)?(?![\w])",
    re.IGNORECASE,
)
POSTAL_RE = re.compile(r"(?:C\.?\s*P\.?|codigo postal)\s*[:#-]?\s*(\d{5})", re.IGNORECASE)
PHONE_RE = re.compile(r"(?:\+?52\s*)?(?:\(?\d{2,3}\)?[\s.-]*)?\d{3,4}[\s.-]*\d{3,4}")
SERVICE_HINT_RE = re.compile(
    r"\b(?:biometr[ií]a|hemograma|orina|ego|glucosa|creatinina|tiroid\w*|tsh|qu[ií]mica|laboratorio|ultrasonido|radiolog[ií]a|tomograf[ií]a|resonancia|mastograf[ií]a|electrocardiograma|electromiograf[ií]a|an[aá]lisis cl[ií]nico|perfil|albumina|ant[ií]geno|covid|vdrl|reacciones|electrolitos|deshidrogenasa|lipidos|hep[aá]tico|rx|columna|torax|prueba)\b",
    re.IGNORECASE,
)
INSULIN_HINT_RE = re.compile(r"\binsulina\b", re.IGNORECASE)
GENERIC_TITLE_WORDS = {
    "inicio",
    "home",
    "inicio de sesion",
    "contacto",
    "nosotros",
    "servicios",
    "precios",
    "cotizacion",
    "ubicacion",
    "sucursales",
    "aviso de privacidad",
}
LOCATION_TYPES = {
    "localbusiness",
    "medicalbusiness",
    "medicalclinic",
    "diagnosticlab",
    "hospital",
    "pharmacy",
    "physician",
}
OFFER_TYPES = {"product", "service", "medicaltest", "offer"}


def _is_service_hint(value: object) -> bool:
    text = str(value or "")
    return bool(SERVICE_HINT_RE.search(text) or INSULIN_HINT_RE.search(text))


def _is_price_heading(value: object) -> bool:
    text = _clean_text(value)
    if not text:
        return False
    match = PRICE_RE.fullmatch(text)
    return bool(match and parse_price_minor(match.group(0)))


@dataclass(frozen=True)
class GenericPage:
    url: str
    html: str
    content_type: str


@dataclass(frozen=True)
class GenericCrawlConfig:
    seed_urls: tuple[str, ...]
    max_pages: int = 25
    max_depth: int = 1
    delay_seconds: float = 0.75
    max_response_bytes: int = MAX_DEFAULT_RESPONSE_BYTES

    def __post_init__(self) -> None:
        if not self.seed_urls:
            raise ValueError("at least one seed URL is required")
        if not 1 <= self.max_pages <= MAX_HARD_PAGES or not 0 <= self.max_depth <= MAX_HARD_DEPTH:
            raise ValueError("max_pages must be between 1 and 500; max_depth must be between 0 and 5")
        if not 0 <= self.delay_seconds <= MAX_HARD_DELAY_SECONDS:
            raise ValueError("delay_seconds must be between 0 and 60")
        if not 16_384 <= self.max_response_bytes <= MAX_HARD_RESPONSE_BYTES:
            raise ValueError("max_response_bytes must be between 16384 and 10000000")


def normalize(value: object | None) -> str:
    text = unicodedata.normalize("NFKD", repair_text(value).casefold())
    plain = "".join(char for char in text if not unicodedata.combining(char))
    return re.sub(r"[^a-z0-9]+", " ", plain).strip()


def repair_text(value: object | None) -> str:
    text = str(value or "").strip()
    for _ in range(2):
        if not any(marker in text for marker in ("Ã", "Â", "â", "ð")):
            break
        try:
            repaired = text.encode("latin-1").decode("utf-8")
            if repaired != text and "�" not in repaired and repaired.count("Ã") < text.count("Ã"):
                text = repaired
                continue
        except (UnicodeEncodeError, UnicodeDecodeError):
            pass
        break
    return text


def decode_html(raw: bytes, preferred_encoding: str | None = None) -> str:
    """Decode pages with a fallback for legacy Latin-1 provider websites."""

    encodings = []
    for encoding in (preferred_encoding, "utf-8", "cp1252", "latin-1"):
        if encoding and encoding.casefold() not in {item.casefold() for item in encodings}:
            encodings.append(encoding)
    decoded = [raw.decode(encoding, errors="replace") for encoding in encodings]
    return min(decoded, key=lambda value: (value.count("�"), value.count("Ã"))) if decoded else raw.decode("utf-8", errors="replace")


def parse_price_minor(value: object) -> int | None:
    """Parse Mexican-style price text into integer centavos."""

    text = str(value or "").strip().replace("\u00a0", " ")
    match = PRICE_RE.search(text)
    if not match:
        return None
    number = match.group(1)
    if "," in number and "." in number:
        decimal_separator = "," if number.rfind(",") > number.rfind(".") else "."
        thousands_separator = "." if decimal_separator == "," else ","
        number = number.replace(thousands_separator, "").replace(decimal_separator, ".")
    elif "," in number:
        parts = number.split(",")
        number = "".join(parts[:-1]) + ("." + parts[-1] if len(parts[-1]) in {1, 2} else parts[-1])
    elif "." in number:
        parts = number.split(".")
        number = "".join(parts[:-1]) + ("." + parts[-1] if len(parts[-1]) in {1, 2} else parts[-1])
    try:
        amount = round(float(number) * 100)
    except ValueError:
        return None
    return amount if amount >= 0 and amount <= 100_000_000 else None


def _host(value: str) -> str:
    parsed = urlparse(value)
    return (parsed.hostname or "").casefold().rstrip(".")


def _site_host(value: str) -> str:
    """Collapse only the conventional apex/www spelling of one site."""

    host = _host(value)
    return host[4:] if host.startswith("www.") else host


def _canonical_url(value: str, *, base_url: str | None = None) -> str:
    resolved = urljoin(base_url or "", value.strip())
    resolved, _ = urldefrag(resolved)
    parsed = urlparse(resolved)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError("generic crawler accepts only http(s) URLs without credentials")
    try:
        port = parsed.port
    except ValueError as error:
        raise ValueError("generic crawler URL has an invalid port") from error
    if port not in (None, 80, 443):
        raise ValueError("generic crawler accepts only standard HTTP(S) ports")
    return resolved


def _safe_link(value: object | None, *, fallback: str) -> str:
    """Keep candidate links navigable without emitting script/data URLs."""

    raw = str(value or "").strip()
    if not raw:
        return fallback
    try:
        return _canonical_url(raw, base_url=fallback)
    except ValueError:
        return fallback


def _public_host(host: str) -> bool:
    try:
        addresses = {info[4][0] for info in socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM)}
    except (OSError, socket.gaierror):
        return False
    return bool(addresses) and all(
        not (
            ipaddress.ip_address(address).is_private
            or ipaddress.ip_address(address).is_loopback
            or ipaddress.ip_address(address).is_link_local
            or ipaddress.ip_address(address).is_reserved
            or ipaddress.ip_address(address).is_multicast
        )
        for address in addresses
    )


class GenericWebClient:
    """HTTP client with host allowlisting, redirect checks and response caps."""

    def __init__(
        self,
        seed_urls: Sequence[str],
        *,
        timeout_seconds: float = 20.0,
        max_attempts: int = 2,
        max_redirects: int = MAX_DEFAULT_REDIRECTS,
        max_response_bytes: int = MAX_DEFAULT_RESPONSE_BYTES,
        allow_private_hosts: bool = False,
        respect_robots: bool = True,
        client: httpx.Client | None = None,
    ) -> None:
        seeds = tuple(_canonical_url(url) for url in seed_urls if url.strip())
        if not seeds:
            raise ValueError("at least one valid seed URL is required")
        if not 0 < timeout_seconds <= 120 or not 1 <= max_attempts <= MAX_HARD_ATTEMPTS or not 0 <= max_redirects <= MAX_HARD_REDIRECTS:
            raise ValueError("timeout_seconds must be between 0 and 120; attempts 1-5; redirects 0-10")
        if not 16_384 <= max_response_bytes <= MAX_HARD_RESPONSE_BYTES:
            raise ValueError("max_response_bytes must be between 16384 and 10000000")
        self.seed_urls = seeds
        self.allowed_hosts = {_host(url) for url in seeds}
        # Small sites commonly redirect between ``example.mx`` and
        # ``www.example.mx``.  Treat only that exact www/apex pair as the
        # same site; unrelated subdomains remain outside the allowlist.
        for host in tuple(self.allowed_hosts):
            self.allowed_hosts.add(host[4:] if host.startswith("www.") else f"www.{host}")
        self.timeout_seconds = timeout_seconds
        self.max_attempts = max_attempts
        self.max_redirects = max_redirects
        self.max_response_bytes = max_response_bytes
        self.allow_private_hosts = allow_private_hosts
        self.respect_robots = respect_robots
        self._robots: RobotFileParser | None = None
        self._robots_loaded = False
        self._owns_client = client is None
        self._client = client or httpx.Client(timeout=timeout_seconds, follow_redirects=True)

    def close(self) -> None:
        if self._owns_client:
            self._client.close()

    def fetch(self, url: str) -> GenericPage:
        canonical = _canonical_url(url)
        self._validate_host(canonical)
        if self.respect_robots and not self._allowed_by_robots(canonical):
            raise ValueError("generic crawler is disallowed by robots.txt")
        last_error: Exception | None = None
        for attempt in range(1, self.max_attempts + 1):
            try:
                current = canonical
                for redirect_count in range(self.max_redirects + 1):
                    # Validate each hop before issuing the next request.  Using
                    # httpx's automatic redirects would contact an external or
                    # private target before the final URL could be checked.
                    response = self._client.get(
                        current,
                        headers={"Accept": "text/html,application/xhtml+xml", "User-Agent": DEFAULT_USER_AGENT},
                        follow_redirects=False,
                    )
                    if 300 <= response.status_code < 400:
                        if redirect_count >= self.max_redirects:
                            raise ValueError("generic crawler exceeded max_redirects")
                        location = response.headers.get("location", "").strip()
                        if not location:
                            raise ValueError("generic redirect has no Location header")
                        current = _canonical_url(location, base_url=current)
                        self._validate_host(current)
                        continue
                    response.raise_for_status()
                    resolved = _canonical_url(str(response.url))
                    self._validate_host(resolved)
                    content_type = response.headers.get("content-type", "text/html").casefold()
                    if "html" not in content_type and "text/" not in content_type:
                        raise ValueError(f"unsupported generic page content type: {content_type}")
                    raw = response.content
                    if len(raw) > self.max_response_bytes:
                        raise ValueError("generic page exceeds max_response_bytes")
                    return GenericPage(url=resolved, html=decode_html(raw, response.encoding), content_type=content_type)
                raise ValueError("generic crawler exceeded max_redirects")
            except (httpx.HTTPStatusError, httpx.RequestError, ValueError) as error:
                last_error = error
                # Validation/content-limit failures are deterministic; retrying
                # them only adds latency and can repeat an unsafe redirect.
                if isinstance(error, ValueError):
                    break
                if isinstance(error, httpx.HTTPStatusError) and error.response.status_code not in {408, 425, 429, 500, 502, 503, 504}:
                    break
                if attempt < self.max_attempts:
                    time.sleep(0.5 * attempt)
        raise RuntimeError(f"generic fetch failed for {canonical}: {last_error}") from last_error

    def _allowed_by_robots(self, url: str) -> bool:
        if not self._robots_loaded:
            parsed = urlparse(self.seed_urls[0])
            try:
                robots_url = f"{parsed.scheme}://{parsed.netloc}/robots.txt"
                response = self._fetch_robots(robots_url)
                if response.status_code in {404, 410}:
                    self._robots = None
                elif response.status_code >= 400:
                    self._robots = RobotFileParser()
                    self._robots.parse(["User-agent: *", "Disallow: /"])
                else:
                    self._robots = RobotFileParser(robots_url)
                    self._robots.parse(response.text.splitlines())
            except (httpx.RequestError, UnicodeError):
                self._robots = RobotFileParser()
                self._robots.parse(["User-agent: *", "Disallow: /"])
            self._robots_loaded = True
        return self._robots is None or self._robots.can_fetch(DEFAULT_USER_AGENT, url)

    def _fetch_robots(self, robots_url: str) -> httpx.Response:
        """Fetch robots.txt without allowing an unchecked redirect hop."""

        current = _canonical_url(robots_url)
        self._validate_host(current)
        for redirect_count in range(self.max_redirects + 1):
            response = self._client.get(
                current,
                headers={"Accept": "text/plain", "User-Agent": DEFAULT_USER_AGENT},
                follow_redirects=False,
            )
            if not 300 <= response.status_code < 400:
                return response
            if redirect_count >= self.max_redirects:
                raise ValueError("generic robots.txt exceeded max_redirects")
            location = response.headers.get("location", "").strip()
            if not location:
                raise ValueError("generic robots.txt redirect has no Location header")
            current = _canonical_url(location, base_url=current)
            self._validate_host(current)
        raise ValueError("generic robots.txt exceeded max_redirects")

    def _validate_host(self, url: str) -> None:
        host = _host(url)
        if host not in self.allowed_hosts:
            raise ValueError("generic crawler refuses redirects or links outside the seed host allowlist")
        if not self.allow_private_hosts and not _public_host(host):
            raise ValueError("generic crawler refuses private, loopback, reserved or unresolved hosts")


class _DocumentParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.text_parts: list[str] = []
        self.headings: list[str] = []
        self.links: list[str] = []
        self.meta: dict[str, str] = {}
        self.jsonld: list[str] = []
        self._skip_depth = 0
        self._heading: tuple[str, list[str]] | None = None
        self._jsonld: list[str] | None = None
        self._anchor: tuple[str, list[str]] | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = {key.casefold(): value or "" for key, value in attrs}
        tag = tag.casefold()
        if tag in {"script", "style", "noscript", "template"}:
            self._skip_depth += 1
            if tag == "script" and "ld+json" in attributes.get("type", "").casefold():
                self._jsonld = []
            return
        if self._skip_depth:
            return
        if tag == "meta":
            key = attributes.get("property") or attributes.get("name")
            if key and attributes.get("content"):
                self.meta[key.casefold()] = attributes["content"].strip()
        elif tag in {"h1", "h2", "h3", "h4"}:
            self._heading = (tag, [])
        elif tag == "a" and attributes.get("href"):
            self._anchor = (attributes["href"], [])

    def handle_endtag(self, tag: str) -> None:
        tag = tag.casefold()
        if tag == "script":
            if self._jsonld is not None:
                content = "".join(self._jsonld).strip()
                if content:
                    self.jsonld.append(content)
                self._jsonld = None
            self._skip_depth = max(0, self._skip_depth - 1)
            return
        if tag in {"style", "noscript", "template"}:
            self._skip_depth = max(0, self._skip_depth - 1)
            return
        if self._skip_depth:
            return
        if self._heading and tag == self._heading[0]:
            text = _clean_text(" ".join(self._heading[1]))
            if text:
                self.headings.append(text)
            self._heading = None
        if self._anchor and tag == "a":
            self.links.append(self._anchor[0])
            self._anchor = None

    def handle_data(self, data: str) -> None:
        if self._jsonld is not None:
            self._jsonld.append(data)
            return
        if self._skip_depth:
            return
        if data.strip():
            self.text_parts.append(data)
            if self._heading:
                self._heading[1].append(data)
            if self._anchor:
                self._anchor[1].append(data)


def _clean_text(value: object) -> str:
    return re.sub(r"\s+", " ", html_lib.unescape(repair_text(value))).strip()


def _json_nodes(value: Any) -> Iterable[dict[str, Any]]:
    if isinstance(value, list):
        for item in value:
            yield from _json_nodes(item)
    elif isinstance(value, dict):
        graph = value.get("@graph")
        if isinstance(graph, list):
            yield from _json_nodes(graph)
        yield value


def _types(node: Mapping[str, Any]) -> set[str]:
    value = node.get("@type") or node.get("type")
    values = value if isinstance(value, list) else [value]
    return {str(item).casefold().replace(" ", "").rsplit("/", 1)[-1] for item in values if item}


def _first_text(*values: object) -> str:
    for value in values:
        if isinstance(value, str) and _clean_text(value):
            return _clean_text(value)
    return ""


def _address(node: Mapping[str, Any]) -> dict[str, str]:
    value = node.get("address")
    if isinstance(value, str):
        return {"formatted": _clean_text(value)}
    if not isinstance(value, Mapping):
        return {}
    fields = {
        "street": value.get("streetAddress"),
        "locality": value.get("addressLocality"),
        "region": value.get("addressRegion"),
        "postal_code": value.get("postalCode"),
        "country": value.get("addressCountry"),
    }
    return {key: _clean_text(item) for key, item in fields.items() if _clean_text(item)}


def _geo(node: Mapping[str, Any]) -> dict[str, float] | None:
    value = node.get("geo")
    if not isinstance(value, Mapping):
        return None
    try:
        latitude = float(value.get("latitude"))
        longitude = float(value.get("longitude"))
    except (TypeError, ValueError):
        return None
    if not (isfinite(latitude) and isfinite(longitude) and -90 <= latitude <= 90 and -180 <= longitude <= 180):
        return None
    return {"latitude": latitude, "longitude": longitude}


def _node_price(node: Mapping[str, Any]) -> int | None:
    for key in ("price", "lowPrice", "priceValue", "amount"):
        price = parse_price_minor(node.get(key))
        if price is not None and price > 0:
            return price
    return None


def _valid_title(value: str) -> bool:
    cleaned = _clean_text(value)
    normalized = normalize(cleaned)
    return bool(cleaned and len(cleaned) >= 3 and normalized not in GENERIC_TITLE_WORDS and len(cleaned) <= 180)


def _evidence_confidence(method: object | None) -> float:
    """Rate extraction strength without turning it into a clinical claim."""

    return {
        "jsonld_local_business": 0.95,
        "jsonld_offer": 0.90,
        "jsonld_price": 0.88,
        "embedded_script_pattern": 0.78,
        "price_pattern": 0.68,
        "jsonld_service": 0.65,
        "heading_pattern": 0.50,
    }.get(str(method or ""), 0.50)


class GenericPageParser:
    """Extract structured and text-pattern evidence from one HTML page."""

    def parse(self, page: GenericPage) -> dict[str, Any]:
        parser = _DocumentParser()
        parser.feed(page.html)
        parser.close()
        nodes: list[dict[str, Any]] = []
        for block in parser.jsonld:
            try:
                decoded = json.loads(block)
            except json.JSONDecodeError:
                continue
            nodes.extend(_json_nodes(decoded))
        provider_name = ""
        locations: list[dict[str, Any]] = []
        offers: list[dict[str, Any]] = []
        for node in nodes:
            types = _types(node)
            name = _first_text(node.get("name"), node.get("legalName"), node.get("alternateName"))
            if types & LOCATION_TYPES and name:
                provider_name = provider_name or name
                locations.append(
                    {
                        "name": name,
                        "legal_name": _first_text(node.get("legalName")),
                        "address": _address(node),
                        "coordinates": _geo(node),
                        "phone": _first_text(node.get("telephone")),
                        "url": _first_text(node.get("url"), page.url),
                    }
                )
            if types & OFFER_TYPES:
                nested = node.get("offers")
                nested_offers = nested if isinstance(nested, list) else [nested]
                found_nested = False
                for offer in nested_offers:
                    if not isinstance(offer, Mapping):
                        continue
                    price = _node_price(offer)
                    if price is not None:
                        offer_name = name or _first_text(offer.get("name"))
                        # Generic Product/Offer JSON-LD is common for
                        # unrelated merchandise.  Keep only clinically
                        # plausible labels unless the schema itself is a
                        # medical test/service.
                        if types & {"product", "offer"} and not _is_service_hint(offer_name):
                            continue
                        found_nested = True
                        offers.append(
                            {
                                "name": offer_name,
                                "price_minor": price,
                                "url": _safe_link(
                                    _first_text(node.get("url"), offer.get("url"), page.url),
                                    fallback=page.url,
                                ),
                                "method": "jsonld_offer",
                            }
                        )
                if not found_nested and name and _node_price(node) is not None:
                    if types & {"product", "offer"} and not _is_service_hint(name):
                        continue
                    offers.append(
                        {
                            "name": name,
                            "price_minor": _node_price(node),
                            "url": _safe_link(_first_text(node.get("url"), page.url), fallback=page.url),
                            "method": "jsonld_price",
                        }
                    )
                elif name and (types & {"service", "medicaltest"}) and not found_nested:
                    offers.append(
                        {
                            "name": name,
                            "price_minor": None,
                            "url": _safe_link(_first_text(node.get("url"), page.url), fallback=page.url),
                            "method": "jsonld_service",
                        }
                    )
        offers.extend(self._embedded_script_offers(page.url, page.html))
        host_parts = [part for part in _host(page.url).split(".") if part and part != "www"]
        provider_name = provider_name or parser.meta.get("og:site_name", "") or (host_parts[0].title() if host_parts else "Provider")
        text = _clean_text(" ".join(parser.text_parts))
        pattern_offers = self._pattern_offers(page.url, parser.headings, text)
        if not offers:
            offers.extend(pattern_offers)
        else:
            # Some CMS pages expose a service in JSON-LD but render its
            # price in an adjacent visible block (for example Elementor).
            # Keep a visible price only when the same service has no
            # structured price; never duplicate or override a stronger
            # JSON-LD price with a page-wide number.
            for pattern_offer in pattern_offers:
                if pattern_offer.get("price_minor") is None:
                    continue
                pattern_name = normalize(pattern_offer.get("name"))
                same_name = [offer for offer in offers if normalize(offer.get("name")) == pattern_name]
                if any(offer.get("price_minor") is not None for offer in same_name):
                    continue
                offers[:] = [offer for offer in offers if normalize(offer.get("name")) != pattern_name]
                offers.append(pattern_offer)
        # A page can contain several JSON-LD blocks and visible fallback text;
        # preserve the first price for an identical service URL/title pair.
        unique_offers: dict[tuple[str, int | None, str], dict[str, Any]] = {}
        for offer in offers:
            title = _clean_text(offer.get("name"))
            if not _valid_title(title):
                continue
            key = (normalize(title), offer.get("price_minor"), offer.get("url") or page.url)
            unique_offers.setdefault(key, offer)
        return {
            "provider_name": provider_name,
            "locations": locations,
            "offers": list(unique_offers.values()),
            "headings": parser.headings,
            "links": parser.links,
            "meta": parser.meta,
            "evidence_text": text[:4_000],
        }

    @staticmethod
    def _embedded_script_offers(page_url: str, source: str) -> list[dict[str, Any]]:
        """Read common CMS study objects when a site has no JSON-LD."""

        pattern = re.compile(
            r"[\"'](?:title|name)[\"']\s*:\s*[\"']([^\"']{3,180})[\"'](?P<body>(?:(?![{}]).){0,600}?)[\"'](?:precio|price|cost|amount)[\"']\s*:\s*(?:[\"']([^\"']*)[\"']|([^,}\s]+))",
            re.IGNORECASE | re.DOTALL,
        )
        results: list[dict[str, Any]] = []
        for match in pattern.finditer(source):
            title = _clean_text(match.group(1))
            if not _valid_title(title) or not _is_service_hint(title):
                continue
            raw_price = match.group(3) or match.group(4) or ""
            price = parse_price_minor(raw_price)
            if price is None or price <= 0:
                continue
            results.append(
                {
                    "name": title,
                    "price_minor": price,
                    "url": page_url,
                    "method": "embedded_script_pattern",
                }
            )
        return results[:100]

    @staticmethod
    def _pattern_offers(page_url: str, headings: Sequence[str], text: str) -> list[dict[str, Any]]:
        # Associate a price with the nearest clinical heading instead of
        # pairing the Nth page-wide number with the Nth heading.  This avoids
        # turning navigation counters, phone numbers and marketing copy into
        # medical prices.
        results: list[dict[str, Any]] = []
        cursor = 0
        folded_text = text.casefold()
        for heading in headings[:100]:
            cleaned_heading = _clean_text(heading)
            if not _valid_title(cleaned_heading) or not _is_service_hint(cleaned_heading):
                continue
            start = folded_text.find(cleaned_heading.casefold(), cursor)
            if start < 0:
                start = cursor
            next_positions = []
            for candidate in headings:
                candidate_text = _clean_text(candidate)
                if not _valid_title(candidate_text) or _is_price_heading(candidate_text):
                    continue
                position = folded_text.find(candidate_text.casefold(), start + len(cleaned_heading))
                if position >= 0:
                    next_positions.append(position)
            end = min(next_positions) if next_positions else min(len(text), start + 700)
            segment = text[start:end]
            cursor = max(cursor, start + len(cleaned_heading))
            for price_match in list(PRICE_RE.finditer(segment))[:5]:
                raw_price = price_match.group(0)
                context = segment[max(0, price_match.start() - 100) : min(len(segment), price_match.end() + 100)].casefold()
                explicit_currency = "$" in raw_price or "mxn" in raw_price.casefold()
                price_word = any(word in context for word in ("precio", "costo", "tarifa", "oferta", "promocion", "desde"))
                if not explicit_currency and not price_word:
                    continue
                price = parse_price_minor(raw_price)
                if price is not None and price > 0:
                    results.append({"name": cleaned_heading, "price_minor": price, "url": page_url, "method": "price_pattern"})
        if results:
            return results
        # Service-only pages are useful, but only take headings with a
        # clinical hint to avoid emitting navigation and marketing copy.
        return [
            {"name": heading, "price_minor": None, "url": page_url, "method": "heading_pattern"}
            for heading in headings
            if _is_service_hint(heading) and _valid_title(heading)
        ][:50]


def _stable_id(kind: str, url: str, name: str) -> str:
    return hashlib.sha256(f"{kind}|{url}|{normalize(name)}".encode("utf-8")).hexdigest()[:32]


def _source_key_for_host(host: str) -> str:
    clean = re.sub(r"[^a-z0-9_]", "", host.replace("-", "_").replace(".", "_")) or "provider"
    prefix = "generic_"
    if len(prefix) + len(clean) <= 80:
        return prefix + clean
    # Preserve uniqueness when a long host is truncated for the source key.
    suffix = hashlib.sha256(host.encode("utf-8")).hexdigest()[:12]
    return f"{prefix}{clean[:80 - len(prefix) - len(suffix) - 1]}_{suffix}"


def _location_record(source_key: str, page: GenericPage, provider_name: str, location: Mapping[str, Any]) -> SourceRecord:
    name = _first_text(location.get("name"), provider_name)
    external_id = _stable_id("location", page.url, name)
    payload = {
        "provider_display_name": name,
        "provider_legal_name": _first_text(location.get("legal_name")),
        "provider_external_id": external_id,
        "location_url": _safe_link(_first_text(location.get("url"), page.url), fallback=page.url),
        "address": dict(location.get("address") or {}),
        "coordinates": location.get("coordinates"),
        "phone": _first_text(location.get("phone")),
        "evidence_method": "jsonld_local_business",
        "evidence_page_url": page.url,
    }
    observations = [
        Observation(
            entity_type="provider_location",
            attribute_name="provider_display_name",
            observed_value=name,
            confidence=_evidence_confidence(payload["evidence_method"]),
        ),
        Observation(
            entity_type="provider_location",
            attribute_name="source_url",
            observed_value=page.url,
            confidence=_evidence_confidence(payload["evidence_method"]),
        ),
    ]
    for field in ("address", "coordinates", "phone"):
        if payload[field]:
            observations.append(
                Observation(
                    entity_type="provider_location",
                    attribute_name=field,
                    observed_value=payload[field],
                    confidence=_evidence_confidence(payload["evidence_method"]),
                )
            )
    return SourceRecord(
        source_key=source_key,
        record_type="provider_location_discovered",
        external_record_id=external_id,
        source_url=page.url,
        payload=payload,
        observations=tuple(observations),
    )


def _offer_record(source_key: str, page: GenericPage, provider_name: str, offer: Mapping[str, Any]) -> SourceRecord:
    title = _clean_text(offer.get("name"))
    external_id = _stable_id("offer", str(offer.get("url") or page.url), title)
    price = offer.get("price_minor")
    payload = {
        "provider_display_name": title,
        "provider_brand_hint": provider_name,
        "provider_external_id": external_id,
        "provider_sku": None,
        "product_url": _safe_link(_first_text(offer.get("url"), page.url), fallback=page.url),
        "prices": {"regular": price} if isinstance(price, int) else {},
        "evidence_method": offer.get("method", "pattern"),
        "evidence_page_url": page.url,
        "claim_status": "candidate",
    }
    observations = [
        Observation(
            entity_type="offer",
            attribute_name="provider_display_name",
            observed_value=title,
            confidence=_evidence_confidence(payload["evidence_method"]),
        ),
        Observation(
            entity_type="offer",
            attribute_name="product_url",
            observed_value=payload["product_url"],
            confidence=_evidence_confidence(payload["evidence_method"]),
        ),
        Observation(
            entity_type="offer",
            attribute_name="provider_brand_hint",
            observed_value=provider_name,
            confidence=_evidence_confidence(payload["evidence_method"]),
        ),
        Observation(
            entity_type="offer",
            attribute_name="evidence_method",
            observed_value=payload["evidence_method"],
            confidence=_evidence_confidence(payload["evidence_method"]),
        ),
    ]
    if payload["prices"]:
        observations.append(
            Observation(
                entity_type="price",
                attribute_name="prices",
                observed_value=payload["prices"],
                confidence=_evidence_confidence(payload["evidence_method"]),
            )
        )
    return SourceRecord(
        source_key=source_key,
        record_type="provider_offer_price" if payload["prices"] else "provider_offer_discovered",
        external_record_id=external_id,
        source_url=page.url,
        payload=payload,
        observations=tuple(observations),
    )


class GenericProviderAdapter:
    """Crawl one or more provider domains using deterministic patterns."""

    def __init__(
        self,
        config: GenericCrawlConfig,
        *,
        client: GenericWebClient | None = None,
        source_key: str | None = None,
    ) -> None:
        self.config = config
        if len({_site_host(url) for url in config.seed_urls}) != 1:
            raise ValueError("all generic seed URLs must belong to the same host")
        self.client = client or GenericWebClient(config.seed_urls, max_response_bytes=config.max_response_bytes)
        self._owns_client = client is None
        site_label = _site_host(config.seed_urls[0])
        self.source = SourceSpec(
            source_key=source_key or _source_key_for_host(site_label),
            name=f"Generic provider discovery — {site_label}",
            source_type="public_website",
            usage_policy_status="review_required",
            endpoint_type="html",
            endpoint_url=config.seed_urls[0],
            parser_version=GENERIC_PARSER_VERSION,
        )
        self.parser = GenericPageParser()
        self.errors: list[str] = []
        self.pages_fetched = 0
        self.pages_failed = 0

    def close(self) -> None:
        if self._owns_client:
            self.client.close()

    def collect(self) -> Iterable[SourceRecord]:
        self.errors.clear()
        self.pages_fetched = 0
        self.pages_failed = 0
        queue: deque[tuple[str, int]] = deque((_canonical_url(url), 0) for url in self.config.seed_urls)
        seen_urls: set[str] = set()
        seen_records: set[tuple[str, str, int | None]] = set()
        pages = 0
        while queue and pages < self.config.max_pages:
            url, depth = queue.popleft()
            if url in seen_urls:
                continue
            seen_urls.add(url)
            if pages and self.config.delay_seconds:
                time.sleep(self.config.delay_seconds)
            try:
                page = self.client.fetch(url)
            except (RuntimeError, ValueError) as error:
                self.pages_failed += 1
                self.errors.append(f"{url}: {error}")
                continue
            pages += 1
            self.pages_fetched += 1
            parsed = self.parser.parse(page)
            provider_name = parsed["provider_name"]
            for location in parsed["locations"]:
                record = _location_record(self.source.source_key, page, provider_name, location)
                key = ("location", record.external_record_id or "", None)
                if key not in seen_records:
                    seen_records.add(key)
                    yield record
            for offer in parsed["offers"]:
                record = _offer_record(self.source.source_key, page, provider_name, offer)
                price = record.payload.get("prices", {}).get("regular")
                key = ("offer", record.external_record_id or "", price)
                if key not in seen_records:
                    seen_records.add(key)
                    yield record
            if depth < self.config.max_depth:
                for href in parsed["links"]:
                    try:
                        link = _canonical_url(href, base_url=page.url)
                    except ValueError:
                        continue
                    if _host(link) in self.client.allowed_hosts and _crawlable_path(link):
                        queue.append((link, depth + 1))


def _crawlable_path(url: str) -> bool:
    path = urlparse(url).path.casefold()
    return not path.endswith((".pdf", ".jpg", ".jpeg", ".png", ".gif", ".zip", ".doc", ".docx", ".xls", ".xlsx"))


__all__ = [
    "GenericCrawlConfig",
    "GenericPage",
    "GenericPageParser",
    "GenericProviderAdapter",
    "GenericWebClient",
    "decode_html",
    "parse_price_minor",
    "repair_text",
]
