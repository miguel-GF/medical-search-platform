from __future__ import annotations

import argparse
import json
from pathlib import Path

from .pipeline import CollectorRunner
from .providers.salud_digna import SaludDignaAdapter, SaludDignaClient


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the Pruevia Salud Digna Puebla collector")
    parser.add_argument("--location-slug", action="append", dest="location_slugs", help="Official clinic slug; repeat for multiple clinics")
    parser.add_argument("--origin", default=None, help="Official web origin override")
    parser.add_argument("--services-base-url", default=None, help="Official services API base URL override")
    parser.add_argument("--no-catalog", action="store_true", help="Collect locations only")
    parser.add_argument("--artifact-root", type=Path, default=Path("artifacts"))
    args = parser.parse_args()
    slugs = tuple(args.location_slugs or ("puebla-municipio-libre",))
    client_kwargs = {}
    if args.origin:
        client_kwargs["origin"] = args.origin
    if args.services_base_url:
        client_kwargs["services_base_url"] = args.services_base_url
    client = SaludDignaClient(**client_kwargs)
    try:
        summary = CollectorRunner(args.artifact_root).run(
            SaludDignaAdapter(client, slugs, include_catalog=not args.no_catalog)
        )
    finally:
        client.close()
    print(json.dumps(summary.__dict__, ensure_ascii=False, indent=2))
    return 0 if summary.status == "succeeded" else 2


if __name__ == "__main__":
    raise SystemExit(main())
