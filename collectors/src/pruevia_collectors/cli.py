from __future__ import annotations

import argparse
import json
from pathlib import Path

from .pipeline import CollectorRunner
from .providers.denue import DenueAdapter, DenueClient, DenueQuery


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
    query = DenueQuery(args.condition, args.latitude, args.longitude, args.radius_meters)
    adapter = DenueAdapter(DenueClient(), [query])
    summary = CollectorRunner(args.artifact_root).run(adapter)
    print(json.dumps(summary.__dict__, ensure_ascii=False, indent=2))
    return 0 if summary.status == "succeeded" else 2


if __name__ == "__main__":
    raise SystemExit(main())
