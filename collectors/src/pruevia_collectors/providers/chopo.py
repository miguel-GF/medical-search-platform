from __future__ import annotations

import re
import time
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from html.parser import HTMLParser
from typing import Any, Iterable, Mapping, Sequence
from json import JSONDecoder
from urllib.parse import urljoin, urlparse

import httpx

from ..models import Observation, SourceRecord, SourceSpec
from .http import request_with_same_host_redirects


CHOPO_PUEBLA_URL = "https://www.chopo.com.mx/puebla/estudios"


@dataclass(frozen=True)
class ChopoPage:
    page_number: int
    url: str
    html: str


@dataclass(frozen=True)
class ChopoProductPage:
    url: str
    html: str


class ChopoClient:
    _headers = {
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "es-MX,es;q=0.9,en;q=0.8",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36",
    }

    def __init__(
        self,
        *,
        base_url: str = CHOPO_PUEBLA_URL,
        timeout_seconds: float = 30.0,
        max_attempts: int = 3,
        retry_backoff_seconds: float = 1.5,
        client: httpx.Client | None = None,
    ) -> None:
        self.base_url = base_url
        self.timeout_seconds = timeout_seconds
        if max_attempts < 1:
            raise ValueError("max_attempts must be positive")
        self.max_attempts = max_attempts
        self.retry_backoff_seconds = retry_backoff_seconds
        self._owns_client = client is None
        self._client = client or httpx.Client(timeout=self.timeout_seconds, follow_redirects=False)

    def close(self) -> None:
        if self._owns_client:
            self._client.close()

    def reset_session(self) -> None:
        """Refresh the HTTP session after edge throttling during long runs."""

        if not self._owns_client:
            return
        self._client.close()
        self._client = httpx.Client(timeout=self.timeout_seconds, follow_redirects=False)

    def fetch_page(self, page_number: int) -> ChopoPage:
        if page_number < 1:
            raise ValueError("Chopo page number must be positive")
        if page_number == 1:
            url = self.base_url
        else:
            url = f"{self.base_url}?p={page_number}"
        for attempt in range(1, self.max_attempts + 1):
            try:
                response = request_with_same_host_redirects(
                    self._client.get,
                    url,
                    allowed_url=self.base_url,
                    max_redirects=5,
                    headers=self._headers,
                )
                response.raise_for_status()
                resolved_url = str(response.url)
                if not self._is_official_puebla_url(resolved_url):
                    raise ValueError("Chopo response redirected outside the official Puebla path")
                response.encoding = "utf-8"
                return ChopoPage(page_number=page_number, url=resolved_url, html=response.text)
            except (httpx.HTTPStatusError, httpx.RequestError) as error:
                if (
                    isinstance(error, httpx.HTTPStatusError)
                    and error.response.status_code not in {429, 500, 502, 503, 504}
                ) or attempt == self.max_attempts:
                    raise
                time.sleep(self.retry_backoff_seconds * attempt)

    def fetch_product(self, url: str) -> ChopoProductPage:
        """Fetch one official Chopo product page for the active market."""

        if not self._is_official_puebla_url(url):
            raise ValueError("Chopo product URL must use the configured official host and Puebla path")
        for attempt in range(1, self.max_attempts + 1):
            try:
                response = request_with_same_host_redirects(
                    self._client.get,
                    url,
                    allowed_url=self.base_url,
                    max_redirects=5,
                    headers=self._headers,
                )
                response.raise_for_status()
                resolved_url = str(response.url)
                if not self._is_official_puebla_url(resolved_url):
                    raise ValueError("Chopo response redirected outside the official Puebla path")
                response.encoding = "utf-8"
                return ChopoProductPage(url=resolved_url, html=response.text)
            except (httpx.HTTPStatusError, httpx.RequestError) as error:
                if (
                    isinstance(error, httpx.HTTPStatusError)
                    and error.response.status_code not in {429, 500, 502, 503, 504}
                ) or attempt == self.max_attempts:
                    raise
                time.sleep(self.retry_backoff_seconds * attempt)
        raise RuntimeError("unreachable")

    def _is_official_puebla_url(self, value: str) -> bool:
        parsed = urlparse(value)
        return (
            parsed.scheme in {"http", "https"}
            and parsed.hostname == urlparse(self.base_url).hostname
            and parsed.path.startswith("/puebla/")
        )


class ChopoListingParser(HTMLParser):
    """Extracts listing cards from Chopo's server-rendered catalog HTML."""

    def __init__(self, *, page_url: str) -> None:
        super().__init__(convert_charrefs=True)
        self.page_url = page_url
        self.records: list[dict[str, Any]] = []
        self.current: dict[str, Any] | None = None
        self.stack: list[str] = []
        self.capture: tuple[str, str, int, list[str]] | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = dict(attrs)
        classes = set((attributes.get("class") or "").split())
        self.stack.append(tag)

        if tag == "a" and "catalog-grid-item__name-link" in classes:
            self._flush_current()
            self.current = {
                "name": "",
                "url": urljoin(self.page_url, attributes.get("href") or ""),
            }
            self._start_capture("name", tag)
        elif self.current is not None and "catalog-grid-item__price" in classes:
            self._start_capture("price_text", tag)
        elif self.current is not None and "catalog-grid-discount" in classes:
            self._start_capture("discount_text", tag)
        elif self.current is not None and "product-ico-specialty" in classes:
            specialty = attributes.get("alt")
            if specialty:
                self.current["specialty"] = specialty.strip()
        elif self.current is not None and tag == "form" and attributes.get("data-role") == "tocart-form":
            sku = attributes.get("data-product-sku")
            if sku:
                self.current["sku"] = sku.strip()

    def handle_endtag(self, tag: str) -> None:
        if self.capture is not None:
            field, capture_tag, depth, buffer = self.capture
            if tag == capture_tag and len(self.stack) == depth:
                if self.current is not None:
                    self.current[field] = " ".join("".join(buffer).split())
                self.capture = None
        if self.stack:
            self.stack.pop()

    def handle_data(self, data: str) -> None:
        if self.capture is not None:
            self.capture[3].append(data)

    def finish(self) -> list[dict[str, Any]]:
        self._flush_current()
        return self.records

    def _start_capture(self, field: str, tag: str) -> None:
        self.capture = (field, tag, len(self.stack), [])

    def _flush_current(self) -> None:
        if not self.current:
            return
        self.records.append(self.current)
        self.current = None
        self.capture = None


class ChopoAdapter:
    source = SourceSpec(
        source_key="chopo_puebla",
        name="Laboratorio Médico del Chopo — Puebla",
        source_type="provider_official",
        usage_policy_status="review_required",
        endpoint_type="html",
        endpoint_url=CHOPO_PUEBLA_URL,
    )

    def __init__(self, client: ChopoClient, *, max_pages: int = 1, page_delay_seconds: float = 0.5) -> None:
        if max_pages < 1:
            raise ValueError("max_pages must be positive")
        self.client = client
        self.max_pages = max_pages
        self.page_delay_seconds = page_delay_seconds

    def collect(self) -> Iterable[SourceRecord]:
        seen: set[str] = set()
        for page_number in range(1, self.max_pages + 1):
            if page_number > 1 and self.page_delay_seconds:
                time.sleep(self.page_delay_seconds)
            page = self.client.fetch_page(page_number)
            records = parse_chopo_page(page)
            if not records:
                break
            for record in records:
                key = record.external_record_id or record.source_url or ""
                if key in seen:
                    continue
                seen.add(key)
                yield record


class ChopoProductAdapter:
    """Collect a reviewed set of Chopo product pages for a Puebla run.

    This mode complements paginated discovery when a provider edge temporarily
    rejects a listing page. URLs are explicit and auditable; no search result
    or fuzzy clinical equivalence is inferred by the collector.
    """

    source = ChopoAdapter.source

    def __init__(
        self,
        client: ChopoClient,
        product_urls: Sequence[str],
        *,
        page_delay_seconds: float = 1.0,
        session_batch_size: int = 4,
    ) -> None:
        urls = tuple(dict.fromkeys(url.strip() for url in product_urls if url.strip()))
        if not urls:
            raise ValueError("at least one Chopo product URL is required")
        if page_delay_seconds < 0:
            raise ValueError("page_delay_seconds cannot be negative")
        if session_batch_size < 1:
            raise ValueError("session batch size must be positive")
        self.client = client
        self.product_urls = urls
        self.page_delay_seconds = page_delay_seconds
        self.session_batch_size = session_batch_size

    def collect(self) -> Iterable[SourceRecord]:
        for index, url in enumerate(self.product_urls):
            if index and index % self.session_batch_size == 0:
                self.client.reset_session()
            if index and self.page_delay_seconds:
                time.sleep(self.page_delay_seconds)
            yield parse_chopo_product(self.client.fetch_product(url))


def parse_chopo_page(page: ChopoPage) -> list[SourceRecord]:
    parser = ChopoListingParser(page_url=page.url)
    parser.feed(page.html)
    return [chopo_item_to_record(item, page=page) for item in parser.finish()]


def parse_chopo_product(page: ChopoProductPage) -> SourceRecord:
    marker = "magentoStorefrontEvents.context.setProduct("
    start = page.html.find(marker)
    if start < 0:
        raise ValueError(f"Chopo product page has no structured product payload: {page.url}")
    try:
        product, _ = JSONDecoder().raw_decode(page.html[start + len(marker) :])
    except ValueError as error:
        raise ValueError(f"Chopo product payload is not valid JSON: {page.url}") from error
    if not isinstance(product, Mapping):
        raise ValueError(f"Chopo product payload is not an object: {page.url}")

    name = str(product.get("name") or "").strip()
    sku = str(product.get("sku") or "").strip() or None
    product_id = product.get("productId")
    if not name or product_id in (None, ""):
        raise ValueError(f"Chopo product requires name and productId: {page.url}")
    pricing = product.get("pricing")
    if not isinstance(pricing, Mapping):
        raise ValueError(f"Chopo product has no pricing payload: {page.url}")

    regular = _price_minor(pricing.get("regularPrice"))
    special = _price_minor(pricing.get("specialPrice"))
    prices: dict[str, int] = {}
    if regular is not None and regular > 0:
        prices["regular"] = regular
    if special is not None and special > 0 and (regular is None or special != regular):
        prices["online"] = special
    if not prices:
        raise ValueError(f"Chopo product has no positive price: {name}")

    payload = {
        "provider_brand": "Laboratorio Médico del Chopo",
        "market": "Puebla",
        "provider_display_name": name,
        "provider_sku": sku,
        "provider_product_id": str(product_id),
        "product_url": page.url,
        "canonical_product_url": product.get("canonicalUrl"),
        "specialty": None,
        "prices": prices,
    }
    observations = [
        Observation(entity_type="offer", attribute_name="provider_display_name", observed_value=name),
        Observation(entity_type="offer", attribute_name="provider_sku", observed_value=sku),
        Observation(entity_type="offer", attribute_name="provider_product_id", observed_value=str(product_id)),
        Observation(entity_type="offer", attribute_name="product_url", observed_value=page.url),
        Observation(entity_type="price", attribute_name="prices", observed_value=prices),
    ]
    return SourceRecord(
        source_key="chopo_puebla",
        record_type="provider_offer_price",
        external_record_id=sku or str(product_id),
        source_url=page.url,
        payload=payload,
        observations=tuple(observations),
    )


def chopo_item_to_record(item: Mapping[str, Any], *, page: ChopoPage) -> SourceRecord:
    name = str(item.get("name") or "").strip()
    url = str(item.get("url") or "").strip()
    sku = str(item.get("sku") or "").strip() or None
    if not name or not url:
        raise ValueError("Chopo item requires a name and product URL")
    prices = parse_price_text(str(item.get("price_text") or ""))
    if not prices:
        raise ValueError(f"Chopo item has no parseable price: {name}")
    payload = {
        "provider_brand": "Laboratorio Médico del Chopo",
        "market": "Puebla",
        "provider_display_name": name,
        "provider_sku": sku,
        "product_url": url,
        "specialty": item.get("specialty"),
        "discount_text": item.get("discount_text"),
        "price_text": item.get("price_text"),
        "prices": prices,
        "page_number": page.page_number,
    }
    observations = [
        Observation(entity_type="offer", attribute_name="provider_display_name", observed_value=name),
        Observation(entity_type="offer", attribute_name="provider_sku", observed_value=sku),
        Observation(entity_type="offer", attribute_name="product_url", observed_value=url),
        Observation(entity_type="price", attribute_name="prices", observed_value=prices),
    ]
    if item.get("specialty"):
        observations.append(Observation(entity_type="offer", attribute_name="specialty", observed_value=item["specialty"]))
    return SourceRecord(
        source_key="chopo_puebla",
        record_type="provider_offer_price",
        external_record_id=sku or url,
        source_url=url,
        payload=payload,
        observations=tuple(observations),
    )


def parse_price_text(value: str) -> dict[str, int]:
    amounts = re.findall(r"\$\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)", value)
    if not amounts:
        return {}
    parsed = [_to_minor_units(amount) for amount in amounts]
    if parsed[0] <= 0:
        return {}
    prices = {"regular": parsed[0]}
    if len(parsed) > 1 and parsed[1] > 0:
        prices["online"] = parsed[1]
    return prices


def _to_minor_units(value: str) -> int:
    amount = Decimal(value.replace(",", "")).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    return int(amount * 100)


def _price_minor(value: Any) -> int | None:
    if value in (None, ""):
        return None
    try:
        amount = Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    except Exception:
        return None
    return int(amount * 100)
