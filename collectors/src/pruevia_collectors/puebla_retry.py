"""Retry only transient/empty Puebla generic-discovery hosts.

The first fan-out manifest is the source of truth.  This command never retries
robots-denied, unresolved-DNS or permanent-HTTP hosts by default; it creates a
separate RAW run and a coverage manifest so retries cannot overwrite history.
"""

from __future__ import annotations

import argparse
import json
import re
import time
from collections import Counter
from pathlib import Path
from typing import Any, Mapping

from .config import load_local_environment
from .pipeline import CollectorRunner
from .puebla_discovery import DISCOVERY_VERSION, PueblaSeed, _empty_summary, _summarize_run
from .providers.generic import GenericCrawlConfig, GenericProviderAdapter, GenericWebClient


RETRYABLE_ERROR = re.compile(r"timed out|timeout|temporar|connection reset|connection refused|\b408\b|\b425\b|\b429\b|\b5\d\d\b", re.IGNORECASE)
PERMANENT_ERROR = re.compile(r"robots\.txt|private, loopback|unresolved|\b404\b|\b410\b|\b401\b|\b403\b", re.IGNORECASE)


def _json(path: Path) -> object:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"invalid discovery manifest: {path}: {error}") from error


def is_retryable_provider(provider: Mapping[str, Any]) -> bool:
    """Return whether a provider deserves another network attempt."""

    status = str(provider.get("status") or "")
    if status == "empty":
        return True
    if status != "failed":
        return False
    errors = " ".join(str(item) for item in (provider.get("errors") or []))
    return bool(RETRYABLE_ERROR.search(errors)) and not PERMANENT_ERROR.search(errors)


def build_retry_seeds(manifest: Mapping[str, Any], *, max_providers: int) -> tuple[PueblaSeed, ...]:
    if manifest.get("version") != DISCOVERY_VERSION:
        raise ValueError("manifest version is not supported by this retry command")
    if max_providers < 1:
        raise ValueError("max_providers must be positive")
    providers = manifest.get("providers")
    if not isinstance(providers, list):
        raise ValueError("manifest providers must be an array")
    seeds: list[PueblaSeed] = []
    for item in providers:
        if not isinstance(item, Mapping) or not is_retryable_provider(item):
            continue
        seed_urls = item.get("seed_urls")
        if not isinstance(seed_urls, list) or not seed_urls:
            continue
        seeds.append(
            PueblaSeed(
                host=str(item.get("host") or ""),
                seed_urls=tuple(str(url) for url in seed_urls if str(url).strip()),
                denue_record_ids=tuple(str(value) for value in (item.get("denue_record_ids") or [])),
                classifications=tuple(str(value) for value in (item.get("classifications") or [])),
            )
        )
    return tuple(sorted(seeds, key=lambda item: item.host)[:max_providers])


def retry_puebla_discovery(
    manifest_path: str | Path,
    artifact_root: str | Path,
    *,
    max_providers: int = 50,
    max_pages: int = 2,
    max_depth: int = 1,
    delay_seconds: float = 0.5,
    delay_between_providers: float = 1.0,
    timeout_seconds: float = 10.0,
    max_response_bytes: int = 2_000_000,
    allow_private_hosts: bool = False,
    respect_robots: bool = True,
) -> dict[str, Any]:
    manifest_value = _json(Path(manifest_path))
    if not isinstance(manifest_value, Mapping):
        raise ValueError("discovery manifest must be an object")
    seeds = build_retry_seeds(manifest_value, max_providers=max_providers)
    root = Path(artifact_root)
    root.mkdir(parents=True, exist_ok=True)
    summaries: list[dict[str, Any]] = []
    for index, seed in enumerate(seeds):
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
            summaries.append(_empty_summary(seed, "blocked", str(error)))
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
    result: dict[str, Any] = {
        "version": "puebla-generic-retry-v1",
        "parent_manifest": Path(manifest_path).as_posix(),
        "retry_policy": "empty or transient transport errors only; robots/DNS/permanent HTTP failures are not retried",
        "providers_considered": len(seeds),
        "status_counts": dict(sorted(status_counts.items())),
        "totals": totals,
        "providers": summaries,
    }
    result["status"] = "empty" if not summaries else "succeeded" if all(item["status"] == "succeeded" for item in summaries) else "partial"
    (root / "puebla_generic_retry_manifest.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Retry transient/empty Puebla generic discovery hosts")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--artifact-root", type=Path, default=Path("artifacts/puebla-generic-retry"))
    parser.add_argument("--max-providers", type=int, default=50)
    parser.add_argument("--max-pages", type=int, default=2)
    parser.add_argument("--max-depth", type=int, default=1)
    parser.add_argument("--delay-seconds", type=float, default=0.5)
    parser.add_argument("--delay-between-providers", type=float, default=1.0)
    parser.add_argument("--timeout-seconds", type=float, default=10.0)
    parser.add_argument("--max-response-bytes", type=int, default=2_000_000)
    parser.add_argument("--allow-private-hosts", action="store_true")
    parser.add_argument("--ignore-robots", action="store_true")
    return parser


def main() -> int:
    load_local_environment()
    args = build_parser().parse_args()
    try:
        result = retry_puebla_discovery(
            args.manifest,
            args.artifact_root,
            max_providers=args.max_providers,
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
        print(json.dumps({"status": "blocked", "error": str(error)}, ensure_ascii=False, indent=2))
        return 2
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["status"] == "succeeded" else 2


if __name__ == "__main__":
    raise SystemExit(main())
