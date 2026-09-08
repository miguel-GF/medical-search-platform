"""Fan out DENUE provider candidates into bounded generic web discovery.

The DENUE collector gives us an auditable provider universe, but its website
field is only a lead.  This module turns those leads into one bounded,
provider-agnostic crawl per host.  It deliberately keeps the DENUE identity
and the web evidence separate: the output is a local manifest plus the normal
RAW artifacts emitted by :class:`CollectorRunner`, never a canonical claim.
"""

from __future__ import annotations

import argparse
import json
import re
import time
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from math import isfinite
from typing import Any, Iterable, Mapping, Sequence
from urllib.parse import urlsplit, urlunsplit

from .config import load_local_environment, require_local_private_host_mode
from .pipeline import CollectorRunner, _safe_error_detail
from .providers.generic import GenericCrawlConfig, GenericProviderAdapter, GenericWebClient


DISCOVERY_VERSION = "puebla-generic-discovery-v1"
DEFAULT_MAX_PROVIDERS = 100
DEFAULT_MAX_SEEDS_PER_HOST = 3
MAX_HARD_PROVIDERS = 500
MAX_HARD_SEEDS_PER_HOST = 10
MAX_DISCOVERY_DELAY_SECONDS = 60.0
MAX_DISCOVERY_FIXTURE_BYTES = 16 * 1024 * 1024
MAX_SUMMARY_ROWS = 100_000
MAX_SUMMARY_LINE_BYTES = 2 * 1024 * 1024


@dataclass(frozen=True)
class PueblaSeed:
    """A unique website host with the DENUE rows that pointed to it."""

    host: str
    seed_urls: tuple[str, ...]
    denue_record_ids: tuple[str, ...]
    classifications: tuple[str, ...]


def normalize_website_url(value: object | None) -> str | None:
    """Normalize DENUE's scheme-less website field without broadening scope."""

    raw = str(value or "").strip()
    if not raw:
        return None
    raw = raw.strip("<>[](){}\"'.,; ")
    if not raw:
        return None
    if not re.match(r"^https?://", raw, flags=re.IGNORECASE):
        raw = "https://" + raw
    try:
        parts = urlsplit(raw)
    except ValueError:
        return None
    if parts.scheme.casefold() not in {"http", "https"} or not parts.hostname:
        return None
    if parts.username or parts.password:
        return None
    try:
        port = parts.port
    except ValueError:
        return None
    if port not in (None, 80, 443):
        return None
    # DENUE often contains both ``example.mx`` and ``www.example.mx`` for
    # the same small provider.  Bucket the exact apex/www pair together so a
    # provider is not crawled twice (unrelated subdomains stay distinct).
    host = parts.hostname.casefold().rstrip(".")
    if host.startswith("www."):
        host = host[4:]
    netloc = host if port is None else f"{host}:{port}"
    path = parts.path or "/"
    # Website fields are leads, not credentials. Never carry signed query
    # material into crawl manifests or exception messages.
    return urlunsplit((parts.scheme.casefold(), netloc, path, "", ""))


def _rows(fixture: Mapping[str, Any], include_review: bool) -> list[Mapping[str, Any]]:
    groups = [fixture.get("candidates", [])]
    if include_review:
        groups.append(fixture.get("review_queue", []))
    result: list[Mapping[str, Any]] = []
    for group in groups:
        if not isinstance(group, list):
            raise ValueError("DENUE fixture groups must be arrays")
        result.extend(row for row in group if isinstance(row, Mapping))
    return result


def build_puebla_seeds(
    fixture: Mapping[str, Any],
    *,
    include_review: bool = False,
    max_seeds_per_host: int = DEFAULT_MAX_SEEDS_PER_HOST,
) -> tuple[PueblaSeed, ...]:
    """Build deterministic host buckets from a classified DENUE fixture."""

    if not 1 <= max_seeds_per_host <= MAX_HARD_SEEDS_PER_HOST:
        raise ValueError(f"max_seeds_per_host must be between 1 and {MAX_HARD_SEEDS_PER_HOST}")
    buckets: dict[str, dict[str, Any]] = {}
    for row in _rows(fixture, include_review):
        url = normalize_website_url(row.get("website_url"))
        if not url:
            continue
        host = urlsplit(url).hostname or ""
        bucket = buckets.setdefault(
            host,
            {"urls": set(), "ids": set(), "classifications": set()},
        )
        bucket["urls"].add(url)
        identifier = str(row.get("external_record_id") or "").strip()
        if identifier:
            bucket["ids"].add(identifier)
        classification = str(row.get("classification") or "").strip()
        if classification:
            bucket["classifications"].add(classification)
    seeds = [
        PueblaSeed(
            host=host,
            seed_urls=tuple(sorted(bucket["urls"])[:max_seeds_per_host]),
            denue_record_ids=tuple(sorted(bucket["ids"])),
            classifications=tuple(sorted(bucket["classifications"])),
        )
        for host, bucket in buckets.items()
    ]
    return tuple(sorted(seeds, key=lambda item: item.host))


def _empty_summary(seed: PueblaSeed, status: str, error: str | None = None) -> dict[str, Any]:
    result: dict[str, Any] = {
        "host": seed.host,
        "seed_urls": list(seed.seed_urls),
        "denue_record_ids": list(seed.denue_record_ids),
        "classifications": list(seed.classifications),
        "status": status,
        "run_id": None,
        "artifact_directory": None,
        "records_received": 0,
        "records_valid": 0,
        "records_rejected": 0,
        "pages_fetched": 0,
        "pages_failed": 0,
        "locations": 0,
        "offers": 0,
        "priced_offers": 0,
        "service_only_offers": 0,
        "errors": [],
    }
    if error:
        result["errors"] = [error]
    return result


def _summarize_run(seed: PueblaSeed, summary: Any, adapter: GenericProviderAdapter, artifact_root: Path) -> dict[str, Any]:
    counts = Counter()
    raw_path = Path(summary.artifact_directory) / "raw_records.jsonl"
    if raw_path.exists():
        # The artifact contains provider-controlled evidence. Stream it with
        # the same hard line/row bounds as CollectorRunner instead of creating
        # a second, unbounded in-memory copy while building the coverage
        # manifest.
        with raw_path.open("rb") as handle:
            for _ in range(MAX_SUMMARY_ROWS):
                raw_line = handle.readline(MAX_SUMMARY_LINE_BYTES + 1)
                if not raw_line:
                    break
                if len(raw_line) > MAX_SUMMARY_LINE_BYTES:
                    raise ValueError("raw record line exceeds the hard artifact limit")
                try:
                    line = raw_line.decode("utf-8").strip()
                    if not line:
                        continue
                    value = json.loads(line)
                except (UnicodeError, json.JSONDecodeError):
                    continue
                if isinstance(value, Mapping):
                    record_type = value.get("record_type")
                    if isinstance(record_type, str) and record_type:
                        counts[record_type] += 1
            else:
                # A well-formed CollectorRunner artifact cannot exceed this
                # row budget. Reject a tampered artifact rather than silently
                # producing an incomplete coverage report.
                if handle.readline(1):
                    raise ValueError("raw artifact exceeds the hard row limit")
    status = summary.status
    # A reachable page with no extractable evidence is different from a
    # successful discovery and must be visible in coverage reports.
    if status == "succeeded" and summary.records_valid == 0:
        status = "empty"
    return {
        "host": seed.host,
        "seed_urls": list(seed.seed_urls),
        "denue_record_ids": list(seed.denue_record_ids),
        "classifications": list(seed.classifications),
        "status": status,
        "run_id": summary.run_id,
        "artifact_directory": str(Path(summary.artifact_directory).relative_to(artifact_root)),
        "records_received": summary.records_received,
        "records_valid": summary.records_valid,
        "records_rejected": summary.records_rejected,
        "pages_fetched": adapter.pages_fetched,
        "pages_failed": adapter.pages_failed,
        "locations": counts["provider_location_discovered"],
        "offers": counts["provider_offer_discovered"] + counts["provider_offer_price"],
        "priced_offers": counts["provider_offer_price"],
        "service_only_offers": counts["provider_offer_discovered"],
        "errors": list(summary.errors),
    }


def run_puebla_discovery(
    fixture_path: str | Path,
    artifact_root: str | Path,
    *,
    include_review: bool = False,
    max_providers: int = DEFAULT_MAX_PROVIDERS,
    max_seeds_per_host: int = DEFAULT_MAX_SEEDS_PER_HOST,
    max_pages: int = 3,
    max_depth: int = 1,
    delay_seconds: float = 0.75,
    delay_between_providers: float = 1.0,
    timeout_seconds: float = 15.0,
    max_response_bytes: int = 2_000_000,
    allow_private_hosts: bool = False,
    respect_robots: bool = True,
) -> dict[str, Any]:
    """Run bounded discovery for a deterministic subset of Puebla hosts."""

    require_local_private_host_mode(allow_private_hosts)
    if not 1 <= max_providers <= MAX_HARD_PROVIDERS:
        raise ValueError(f"max_providers must be between 1 and {MAX_HARD_PROVIDERS}")
    if not isinstance(delay_between_providers, (int, float)) or isinstance(delay_between_providers, bool) or not isfinite(float(delay_between_providers)) or not 0 <= delay_between_providers <= MAX_DISCOVERY_DELAY_SECONDS:
        raise ValueError("delay_between_providers must be between 0 and 60")
    fixture_file = Path(fixture_path)
    with fixture_file.open("rb") as handle:
        fixture_bytes = handle.read(MAX_DISCOVERY_FIXTURE_BYTES + 1)
    if len(fixture_bytes) > MAX_DISCOVERY_FIXTURE_BYTES:
        raise ValueError("DENUE fixture exceeds the hard size limit")
    fixture = json.loads(fixture_bytes.decode("utf-8"))
    if not isinstance(fixture, Mapping):
        raise ValueError("DENUE fixture must be a JSON object")
    seeds = build_puebla_seeds(
        fixture,
        include_review=include_review,
        max_seeds_per_host=max_seeds_per_host,
    )
    selected = seeds[:max_providers]
    root = Path(artifact_root)
    root.mkdir(parents=True, exist_ok=True)
    summaries: list[dict[str, Any]] = []
    for index, seed in enumerate(selected):
        if index and delay_between_providers:
            time.sleep(delay_between_providers)
        try:
            config = GenericCrawlConfig(
                seed_urls=seed.seed_urls,
                max_pages=max_pages,
                max_depth=max_depth,
                delay_seconds=delay_seconds,
                max_response_bytes=max_response_bytes,
            )
            client = GenericWebClient(
                config.seed_urls,
                timeout_seconds=timeout_seconds,
                max_response_bytes=max_response_bytes,
                allow_private_hosts=allow_private_hosts,
                respect_robots=respect_robots,
            )
            adapter = GenericProviderAdapter(config, client=client)
        except (ValueError, OSError) as error:
            summaries.append(_empty_summary(seed, "blocked", _safe_error_detail(error)))
            continue
        try:
            summary = CollectorRunner(root).run(adapter)
            summaries.append(_summarize_run(seed, summary, adapter, root))
        finally:
            adapter.close()
            client.close()
    status_counts = Counter(item["status"] for item in summaries)
    totals = {
        key: sum(int(item[key]) for item in summaries)
        for key in (
            "records_received",
            "records_valid",
            "records_rejected",
            "pages_fetched",
            "pages_failed",
            "locations",
            "offers",
            "priced_offers",
            "service_only_offers",
        )
    }
    result = {
        "version": DISCOVERY_VERSION,
        "fixture_path": Path(fixture_path).as_posix(),
        "fixture_source_run_id": fixture.get("source_run_id"),
        "include_review": include_review,
        # Keep the original DENUE population visible separately from the
        # classified rows selected for web discovery.  The latter may be
        # smaller after deduplication/classification (e.g. 489 raw rows can
        # yield 213 direct candidates).
        "denue_source_records": fixture.get("source_records"),
        "denue_rows_considered": len(_rows(fixture, include_review)),
        "rows_with_website": sum(bool(normalize_website_url(row.get("website_url"))) for row in _rows(fixture, include_review)),
        "unique_hosts": len(seeds),
        "providers_selected": len(selected),
        "providers_not_selected": max(0, len(seeds) - len(selected)),
        "status_counts": dict(sorted(status_counts.items())),
        "totals": totals,
        "providers": summaries,
    }
    bad_statuses = sum(status_counts.get(status, 0) for status in ("failed", "quarantined", "blocked", "empty"))
    result["status"] = (
        "empty"
        if not selected
        else "succeeded"
        if bad_statuses == 0
        else "partial"
        if any(item["status"] == "succeeded" for item in summaries)
        else "failed"
    )
    (root / "puebla_generic_discovery_manifest.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run bounded generic discovery for Puebla DENUE websites")
    parser.add_argument("--fixture", type=Path, required=True, help="classified DENUE fixture JSON")
    parser.add_argument("--artifact-root", type=Path, default=Path("artifacts/puebla-generic"))
    parser.add_argument("--include-review", action="store_true", help="include DENUE related_clinical review leads")
    parser.add_argument("--max-providers", type=int, default=DEFAULT_MAX_PROVIDERS)
    parser.add_argument("--max-seeds-per-host", type=int, default=DEFAULT_MAX_SEEDS_PER_HOST)
    parser.add_argument("--max-pages", type=int, default=3)
    parser.add_argument("--max-depth", type=int, default=1)
    parser.add_argument("--delay-seconds", type=float, default=0.75)
    parser.add_argument("--delay-between-providers", type=float, default=1.0)
    parser.add_argument("--timeout-seconds", type=float, default=15.0)
    parser.add_argument("--max-response-bytes", type=int, default=2_000_000)
    parser.add_argument("--allow-private-hosts", action="store_true", help="only for local fixtures")
    parser.add_argument("--ignore-robots", action="store_true", help="only for an explicitly reviewed test")
    return parser


def main() -> int:
    load_local_environment()
    args = build_parser().parse_args()
    try:
        result = run_puebla_discovery(
            args.fixture,
            args.artifact_root,
            include_review=args.include_review,
            max_providers=args.max_providers,
            max_seeds_per_host=args.max_seeds_per_host,
            max_pages=args.max_pages,
            max_depth=args.max_depth,
            delay_seconds=args.delay_seconds,
            delay_between_providers=args.delay_between_providers,
            timeout_seconds=args.timeout_seconds,
            max_response_bytes=args.max_response_bytes,
            allow_private_hosts=args.allow_private_hosts,
            respect_robots=not args.ignore_robots,
        )
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(json.dumps({"status": "blocked", "error": _safe_error_detail(error)}, ensure_ascii=False, indent=2))
        return 2
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["status"] == "succeeded" else 2


if __name__ == "__main__":
    raise SystemExit(main())
