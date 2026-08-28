from __future__ import annotations

import argparse
import json
from pathlib import Path

from .pipeline import CollectorRunner
from .providers.chopo import ChopoAdapter, ChopoClient, ChopoProductAdapter


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the Pruevia Chopo Puebla listing collector")
    parser.add_argument("--max-pages", type=int, default=1)
    parser.add_argument("--page-delay-seconds", type=float, default=1.5)
    parser.add_argument("--max-attempts", type=int, default=5)
    parser.add_argument("--retry-backoff-seconds", type=float, default=2.0)
    parser.add_argument(
        "--product-url-file",
        type=Path,
        help="one official Puebla product URL per line; use this mode when listing pagination is unavailable",
    )
    parser.add_argument("--product-offset", type=int, default=0)
    parser.add_argument("--max-products", type=int, default=None)
    parser.add_argument("--session-batch-size", type=int, default=4)
    parser.add_argument("--artifact-root", type=Path, default=Path("artifacts"))
    args = parser.parse_args()
    client = ChopoClient(max_attempts=args.max_attempts, retry_backoff_seconds=args.retry_backoff_seconds)
    try:
        if args.product_url_file:
            urls = [line.strip() for line in args.product_url_file.read_text(encoding="utf-8").splitlines() if line.strip() and not line.lstrip().startswith("#")]
            if args.product_offset < 0:
                raise ValueError("product offset cannot be negative")
            urls = urls[args.product_offset :]
            if args.max_products is not None:
                if args.max_products < 1:
                    raise ValueError("max products must be positive")
                urls = urls[: args.max_products]
            adapter = ChopoProductAdapter(
                client,
                urls,
                page_delay_seconds=args.page_delay_seconds,
                session_batch_size=args.session_batch_size,
            )
        else:
            adapter = ChopoAdapter(client, max_pages=args.max_pages, page_delay_seconds=args.page_delay_seconds)
        summary = CollectorRunner(args.artifact_root).run(adapter)
    finally:
        client.close()
    print(json.dumps(summary.__dict__, ensure_ascii=False, indent=2))
    return 0 if summary.status == "succeeded" else 2


if __name__ == "__main__":
    raise SystemExit(main())
