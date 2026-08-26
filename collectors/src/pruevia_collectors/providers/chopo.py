from __future__ import annotations

import re
import time
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from html.parser import HTMLParser
from typing import Any, Iterable, Mapping, Sequence
from urllib.parse import urljoin

import httpx

from ..models import Observation, SourceRecord, SourceSpec


CHOPO_PUEBLA_URL = "https://www.chopo.com.mx/puebla/estudios"


@dataclass(frozen=True)
class ChopoPage:
    page_number: int
    url: str
    html: str


class ChopoClient:
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
        self._client = client or httpx.Client(timeout=self.timeout_seconds, follow_redirects=True)

    def close(self) -> None:
        if self._owns_client:
            self._client.close()

    def fetch_page(self, page_number: int) -> ChopoPage:
        if page_number < 1:
            raise ValueError("Chopo page number must be positive")
        url = self.base_url if page_number == 1 else f"{self.base_url}?p={page_number}"
        for attempt in range(1, self.max_attempts + 1):
            try:
                response = self._client.get(url, headers={"Accept": "text/html", "User-Agent": "PrueviaCollector/0.1"})
                response.raise_for_status()
                response.encoding = "utf-8"
                return ChopoPage(page_number=page_number, url=str(response.url), html=response.text)
            except (httpx.HTTPStatusError, httpx.RequestError) as error:
                if (
                    isinstance(error, httpx.HTTPStatusError)
                    and error.response.status_code not in {429, 500, 502, 503, 504}
                ) or attempt == self.max_attempts:
                    raise
                time.sleep(self.retry_backoff_seconds * attempt)


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


def parse_chopo_page(page: ChopoPage) -> list[SourceRecord]:
    parser = ChopoListingParser(page_url=page.url)
    parser.feed(page.html)
    return [chopo_item_to_record(item, page=page) for item in parser.finish()]


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
    prices = {"regular": _to_minor_units(amounts[0])}
    if len(amounts) > 1:
        prices["online"] = _to_minor_units(amounts[1])
    return prices


def _to_minor_units(value: str) -> int:
    amount = Decimal(value.replace(",", "")).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    return int(amount * 100)
