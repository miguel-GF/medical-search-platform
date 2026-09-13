from __future__ import annotations

import argparse
import json
from pathlib import Path

from .pipeline import CollectorRunner
from .providers.salud_digna import SaludDignaClient, SaludDignaLocationInventoryAdapter


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the public Salud Digna Puebla-state clinic directory collector")
    parser.add_argument("--services-base-url", default=None, help="official API origin override for reviewed tests")
    parser.add_argument("--timeout-seconds", type=float, default=30.0)
    parser.add_argument("--max-attempts", type=int, default=3)
    parser.add_argument("--retry-backoff-seconds", type=float, default=1.5)
    parser.add_argument("--artifact-root", type=Path, default=Path("artifacts"))
    args = parser.parse_args()
    client_kwargs = {
        "timeout_seconds": args.timeout_seconds,
        "max_attempts": args.max_attempts,
        "retry_backoff_seconds": args.retry_backoff_seconds,
    }
    if args.services_base_url:
        client_kwargs["services_base_url"] = args.services_base_url
    client = SaludDignaClient(**client_kwargs)
    try:
        summary = CollectorRunner(args.artifact_root).run(SaludDignaLocationInventoryAdapter(client))
    finally:
        client.close()
    print(json.dumps(summary.__dict__, ensure_ascii=False, indent=2))
    return 0 if summary.status == "succeeded" else 2


if __name__ == "__main__":
    raise SystemExit(main())
