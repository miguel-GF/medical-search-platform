from __future__ import annotations

import argparse
import json
from pathlib import Path

from .pipeline import CollectorRunner
from .providers.linfolab import LinfolabAdapter, LinfolabClient


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the public Linfolab Puebla branch collector")
    parser.add_argument("--branches-url", default=None, help="official HTTPS branch page override for reviewed tests")
    parser.add_argument("--timeout-seconds", type=float, default=30.0)
    parser.add_argument("--ignore-robots", action="store_true", help="disable robots.txt checks only for a reviewed local test")
    parser.add_argument("--artifact-root", type=Path, default=Path("artifacts"))
    args = parser.parse_args()
    client_kwargs = {"timeout_seconds": args.timeout_seconds, "respect_robots": not args.ignore_robots}
    if args.branches_url:
        client_kwargs["branches_url"] = args.branches_url
    client = LinfolabClient(**client_kwargs)
    try:
        summary = CollectorRunner(args.artifact_root).run(LinfolabAdapter(client))
    finally:
        client.close()
    print(json.dumps(summary.__dict__, ensure_ascii=False, indent=2))
    return 0 if summary.status == "succeeded" else 2


if __name__ == "__main__":
    raise SystemExit(main())
