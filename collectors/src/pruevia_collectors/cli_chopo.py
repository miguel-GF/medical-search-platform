from __future__ import annotations

import argparse
import json
from pathlib import Path

from .pipeline import CollectorRunner
from .providers.chopo import ChopoAdapter, ChopoClient


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the Pruevia Chopo Puebla listing collector")
    parser.add_argument("--max-pages", type=int, default=1)
    parser.add_argument("--artifact-root", type=Path, default=Path("artifacts"))
    args = parser.parse_args()
    summary = CollectorRunner(args.artifact_root).run(ChopoAdapter(ChopoClient(), max_pages=args.max_pages))
    print(json.dumps(summary.__dict__, ensure_ascii=False, indent=2))
    return 0 if summary.status == "succeeded" else 2


if __name__ == "__main__":
    raise SystemExit(main())
