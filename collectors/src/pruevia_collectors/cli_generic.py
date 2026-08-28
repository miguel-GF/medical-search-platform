from __future__ import annotations

import argparse
import json
from pathlib import Path

from .config import load_local_environment
from .pipeline import CollectorRunner
from .providers.generic import GenericCrawlConfig, GenericProviderAdapter, GenericWebClient


load_local_environment()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run the bounded provider-agnostic web discovery collector"
    )
    parser.add_argument(
        "--seed-url",
        action="append",
        required=True,
        help="Provider page to crawl; repeat only for paths on the same host",
    )
    parser.add_argument("--max-pages", type=int, default=25)
    parser.add_argument("--max-depth", type=int, default=1)
    parser.add_argument("--delay-seconds", type=float, default=0.75)
    parser.add_argument("--max-response-bytes", type=int, default=2_000_000)
    parser.add_argument("--timeout-seconds", type=float, default=20.0)
    parser.add_argument("--artifact-root", type=Path, default=Path("artifacts"))
    parser.add_argument(
        "--allow-private-hosts",
        action="store_true",
        help="Allow private hosts for local fixtures; never use this for arbitrary user URLs",
    )
    parser.add_argument(
        "--ignore-robots",
        action="store_true",
        help="Ignore robots.txt only for an explicitly reviewed local/test run",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        config = GenericCrawlConfig(
            seed_urls=tuple(args.seed_url),
            max_pages=args.max_pages,
            max_depth=args.max_depth,
            delay_seconds=args.delay_seconds,
            max_response_bytes=args.max_response_bytes,
        )
        client = GenericWebClient(
            config.seed_urls,
            timeout_seconds=args.timeout_seconds,
            max_response_bytes=config.max_response_bytes,
            allow_private_hosts=args.allow_private_hosts,
            respect_robots=not args.ignore_robots,
        )
        adapter = GenericProviderAdapter(config, client=client)
    except ValueError as error:
        print(json.dumps({"status": "blocked", "error": str(error)}, ensure_ascii=False, indent=2))
        return 2
    try:
        summary = CollectorRunner(args.artifact_root).run(adapter)
    finally:
        adapter.close()
        client.close()
    print(json.dumps(summary.__dict__, ensure_ascii=False, indent=2))
    return 0 if summary.status == "succeeded" else 2


if __name__ == "__main__":
    raise SystemExit(main())
