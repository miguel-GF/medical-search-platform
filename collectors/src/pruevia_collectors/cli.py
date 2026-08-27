from __future__ import annotations

import argparse
import json
from pathlib import Path

from .config import load_local_environment
from .pipeline import CollectorRunner
from .providers.denue import DenueAdapter, DenueClient, DenueQuery


# Load local secrets before ``main`` is called.
load_local_environment()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run a Pruevia DENUE discovery collector")
    parser.add_argument("--condition", default="laboratorio", help="DENUE search condition")
    parser.add_argument("--latitude", type=float, required=True)
    parser.add_argument("--longitude", type=float, required=True)
    parser.add_argument("--radius-meters", type=int, default=5000)
    parser.add_argument("--artifact-root", type=Path, default=Path("artifacts"))
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        query = DenueQuery(args.condition, args.latitude, args.longitude, args.radius_meters)
        adapter = DenueAdapter(DenueClient(), [query])
    except ValueError as error:
        print(json.dumps({"status": "blocked", "error": str(error)}, ensure_ascii=False, indent=2))
        return 2
    summary = CollectorRunner(args.artifact_root).run(adapter)
    print(json.dumps(summary.__dict__, ensure_ascii=False, indent=2))
    return 0 if summary.status == "succeeded" else 2


if __name__ == "__main__":
    raise SystemExit(main())
