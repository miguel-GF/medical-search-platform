from __future__ import annotations

import argparse
import json
from pathlib import Path

from .pipeline import CollectorRunner
from .providers.ruiz import RuizAdapter, RuizClient


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the Pruevia Laboratorios Ruiz Puebla collector")
    parser.add_argument("--max-records", type=int, default=200)
    parser.add_argument("--per-department", type=int, default=20)
    parser.add_argument("--artifact-root", type=Path, default=Path("artifacts"))
    args = parser.parse_args()
    client = RuizClient()
    try:
        summary = CollectorRunner(args.artifact_root).run(
            RuizAdapter(client, max_records=args.max_records, per_department_limit=args.per_department)
        )
    finally:
        client.close()
    print(json.dumps(summary.__dict__, ensure_ascii=False, indent=2))
    return 0 if summary.status == "succeeded" else 2


if __name__ == "__main__":
    raise SystemExit(main())
