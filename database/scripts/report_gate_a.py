"""Read-only Gate A coverage report for the Puebla data engine."""

from __future__ import annotations

import argparse
import json
import os
from typing import Any

import psycopg

METRICS: dict[str, str] = {
    "active_services": "select count(*) from catalog.items where status = 'active'",
    "active_offers": "select count(*) from supply.offers where status = 'active'",
    "provider_brands": "select count(*) from core.provider_brands where status <> 'closed'",
    "current_prices": "select count(*) from supply.price_versions where is_current and amount_minor > 0",
    "shared_services": """
        select count(*) from (
          select o.catalog_item_id
          from supply.offers o
          join core.provider_brands b on b.id = o.provider_brand_id and b.status = 'active'
          where o.status = 'active'
          group by o.catalog_item_id
          having count(distinct o.provider_brand_id) >= 2
        ) shared
    """,
    "shared_priced_services": """
        select count(*) from (
          select o.catalog_item_id
          from supply.offers o
          join core.provider_brands b on b.id = o.provider_brand_id and b.status = 'active'
          join supply.offer_scopes os on os.offer_id = o.id and os.status = 'active'
          join supply.price_versions pv on pv.offer_scope_id = os.id and pv.is_current and pv.amount_minor > 0
          where o.status = 'active'
          group by o.catalog_item_id
          having count(distinct o.provider_brand_id) >= 2
        ) shared
    """,
    "active_locations": "select count(*) from core.provider_locations where status = 'active'",
    "locations_with_coordinates": "select count(*) from core.provider_locations where status = 'active' and coordinates is not null",
    "stale_current_prices_30d": "select count(*) from supply.price_versions where is_current and amount_minor > 0 and last_seen_at < now() - interval '30 days'",
    "failed_or_quarantined_runs": "select count(*) from ingest.crawl_runs where status in ('failed', 'quarantined', 'partial')",
    "normalization_review_queue": "select count(*) from ingest.normalization_runs where status in ('pending', 'ambiguous', 'no_match')",
}


def collect_metrics(dsn: str) -> dict[str, int | float]:
    with psycopg.connect(dsn, connect_timeout=15) as connection, connection.cursor() as cursor:
        result: dict[str, int | float] = {}
        for name, query in METRICS.items():
            cursor.execute(query)
            value = cursor.fetchone()[0]
            result[name] = float(value) if isinstance(value, float) else int(value)
    active_locations = int(result["active_locations"])
    result["location_coordinate_pct"] = round(
        (int(result["locations_with_coordinates"]) / active_locations * 100) if active_locations else 0,
        2,
    )
    return result


def evaluate(metrics: dict[str, int | float], *, min_shared_services: int, min_shared_priced_services: int, min_coordinate_pct: float) -> dict[str, Any]:
    checks = {
        "shared_services": int(metrics["shared_services"]) >= min_shared_services,
        "shared_priced_services": int(metrics["shared_priced_services"]) >= min_shared_priced_services,
        "location_coordinate_pct": float(metrics["location_coordinate_pct"]) >= min_coordinate_pct,
    }
    return {
        "gate_a_passed": all(checks.values()),
        "thresholds": {
            "min_shared_services": min_shared_services,
            "min_shared_priced_services": min_shared_priced_services,
            "min_coordinate_pct": min_coordinate_pct,
        },
        "checks": checks,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Report read-only Gate A coverage metrics")
    parser.add_argument("--dsn", default=os.getenv("PRUEVIA_DATABASE_URL"), help="PostgreSQL DSN; defaults to PRUEVIA_DATABASE_URL")
    parser.add_argument("--min-shared-services", type=int, default=30)
    parser.add_argument("--min-shared-priced-services", type=int, default=10)
    parser.add_argument("--min-coordinate-pct", type=float, default=90.0)
    args = parser.parse_args()
    if not args.dsn:
        parser.error("PRUEVIA_DATABASE_URL or --dsn is required")
    metrics = collect_metrics(args.dsn)
    print(json.dumps({"metrics": metrics, **evaluate(metrics, min_shared_services=args.min_shared_services, min_shared_priced_services=args.min_shared_priced_services, min_coordinate_pct=args.min_coordinate_pct)}, ensure_ascii=False, indent=2))
    return 0 if evaluate(metrics, min_shared_services=args.min_shared_services, min_shared_priced_services=args.min_shared_priced_services, min_coordinate_pct=args.min_coordinate_pct)["gate_a_passed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
