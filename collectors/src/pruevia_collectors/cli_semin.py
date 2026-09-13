from __future__ import annotations

import argparse
import json
from pathlib import Path

from .config import load_local_environment
from .pipeline import CollectorRunner, _safe_error_detail
from .providers.semin import (
    MAX_SEMIN_DELAY_SECONDS,
    MAX_SEMIN_DETAILS,
    MAX_SEMIN_PAGES,
    MAX_SEMIN_RESULTS,
    SeminAdapter,
    SeminClient,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Capture the public SEMIN Puebla catalog as candidate evidence")
    parser.add_argument("--max-pages", type=int, default=MAX_SEMIN_PAGES)
    parser.add_argument("--max-results", type=int, default=MAX_SEMIN_RESULTS)
    parser.add_argument("--max-details", type=int, default=MAX_SEMIN_DETAILS)
    parser.add_argument("--page-delay-seconds", type=float, default=0.25)
    parser.add_argument("--sentence", default="", help="public catalog search text; empty captures the provider's first-party catalog")
    parser.add_argument("--artifact-root", type=Path, default=Path("artifacts/semin-catalog-puebla"))
    parser.add_argument("--no-details", action="store_true", help="skip per-study detail requests")
    parser.add_argument("--ignore-robots", action="store_true", help="only for explicitly reviewed local fixtures")
    return parser


def main() -> int:
    load_local_environment()
    args = build_parser().parse_args()
    if not 0 <= args.page_delay_seconds <= MAX_SEMIN_DELAY_SECONDS:
        print(json.dumps({"status": "blocked", "error": "page-delay-seconds must be between 0 and 60"}, ensure_ascii=False))
        return 2
    try:
        client = SeminClient(respect_robots=not args.ignore_robots)
        adapter = SeminAdapter(
            client,
            sentence=args.sentence,
            max_pages=args.max_pages,
            max_results=args.max_results,
            include_details=not args.no_details,
            max_details=args.max_details,
            page_delay_seconds=args.page_delay_seconds,
        )
    except (TypeError, ValueError, OSError) as error:
        print(json.dumps({"status": "blocked", "error": _safe_error_detail(error)}, ensure_ascii=False, indent=2))
        return 2
    try:
        summary = CollectorRunner(args.artifact_root).run(adapter)
    finally:
        adapter.client.close()
    print(json.dumps(summary.__dict__, ensure_ascii=False, indent=2))
    return 0 if summary.status == "succeeded" else 2


if __name__ == "__main__":
    raise SystemExit(main())
