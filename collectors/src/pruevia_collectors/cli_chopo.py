from __future__ import annotations

import argparse
import json
from pathlib import Path

from .pipeline import CollectorRunner
from .providers.chopo import (
    MAX_CHOPO_PRODUCTS,
    ChopoAdapter,
    ChopoClient,
    ChopoProductAdapter,
)


MAX_PRODUCT_URL_FILE_BYTES = 256 * 1024
MAX_PRODUCT_URLS = 10_000
MAX_PRODUCT_URL_LINE_BYTES = 4 * 1024


def _read_product_urls(path: Path) -> list[str]:
    """Read an operator-supplied URL list with explicit resource limits."""

    with path.open("rb") as handle:
        raw = handle.read(MAX_PRODUCT_URL_FILE_BYTES + 1)
    if len(raw) > MAX_PRODUCT_URL_FILE_BYTES:
        raise ValueError("product URL file exceeds the safety limit")
    urls: list[str] = []
    for raw_line in raw.splitlines():
        if len(raw_line) > MAX_PRODUCT_URL_LINE_BYTES:
            raise ValueError("product URL line exceeds the safety limit")
        line = raw_line.decode("utf-8").strip()
        if line and not line.lstrip().startswith("#"):
            urls.append(line)
    if len(urls) > MAX_PRODUCT_URLS:
        raise ValueError("product URL file contains too many URLs")
    return urls


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
            urls = _read_product_urls(args.product_url_file)
            if not 0 <= args.product_offset <= MAX_CHOPO_PRODUCTS:
                raise ValueError("product offset must be between 0 and 10000")
            urls = urls[args.product_offset :]
            if args.max_products is not None:
                if not 1 <= args.max_products <= MAX_CHOPO_PRODUCTS:
                    raise ValueError("max products must be between 1 and 10000")
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
