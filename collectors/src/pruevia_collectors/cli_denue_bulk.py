"""Produce traceable statewide healthcare discovery using an official ZIP."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path

from .pipeline import CollectorRunner
from .providers.denue_bulk import DenueBulkAdapter


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--artifact-root", type=Path, required=True)
    args = parser.parse_args()
    adapter = DenueBulkAdapter(args.archive)
    summary = CollectorRunner(args.artifact_root).run(adapter)
    if summary.status == "succeeded":
        report = Path(summary.artifact_directory) / "healthcare_inventory.json"
        report.write_text(json.dumps(adapter.summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(asdict(summary), ensure_ascii=False))
    return 0 if summary.status == "succeeded" else 2


if __name__ == "__main__":
    raise SystemExit(main())
