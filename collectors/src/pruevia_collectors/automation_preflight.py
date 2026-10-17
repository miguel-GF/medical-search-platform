"""Read-only gate for future scheduled first-party collectors.

The database, not a collector manifest, owns source approval. This module
deliberately does not launch collectors or change source policy.
"""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass

import psycopg
from psycopg import Connection

from .config import load_local_environment
from .models import SourceSpec
from .providers.chopo import ChopoAdapter
from .providers.salud_digna import SaludDignaAdapter
from .providers.semin import SeminAdapter
from .publisher import _safe_endpoint_url


SCHEDULE_CANDIDATES: dict[str, SourceSpec] = {
    source.source_key: source
    for source in (ChopoAdapter.source, SaludDignaAdapter.source, SeminAdapter.source)
}


class SourceNotApproved(ValueError):
    """A source cannot be scheduled under its current persisted policy."""


@dataclass(frozen=True)
class ApprovedSource:
    source_key: str
    source_id: str
    endpoint_id: str


def check_source(connection: Connection, source: SourceSpec) -> ApprovedSource:
    """Require one active, approved provider source at the expected endpoint."""

    expected_url = _safe_endpoint_url(source.endpoint_url)
    if not expected_url or source.source_type not in {"government", "provider_official", "official_api"}:
        raise SourceNotApproved("collector source is not eligible for scheduling")
    rows = connection.execute(
        """
        select s.id, s.status, s.usage_policy_status, s.provider_brand_id,
               se.id, se.status, se.url
        from ingest.sources s
        join ingest.source_endpoints se on se.source_id = s.id
        where s.name = %s and s.source_type = %s
          and se.name = %s
        order by s.created_at, se.created_at
        limit 2
        """,
        (source.name, source.source_type, f"{source.name} collector endpoint"),
    ).fetchall()
    if len(rows) != 1:
        raise SourceNotApproved("expected exactly one reviewed source endpoint")
    source_id, source_status, policy, brand_id, endpoint_id, endpoint_status, stored_url = rows[0]
    if (
        source_status != "active"
        or policy != "approved"
        or brand_id is None
        or endpoint_status != "active"
        or _safe_endpoint_url(stored_url) != expected_url
    ):
        raise SourceNotApproved("source policy, provider identity, or endpoint is not approved")
    return ApprovedSource(source.source_key, str(source_id), str(endpoint_id))


def main() -> int:
    load_local_environment()
    parser = argparse.ArgumentParser(description="Check a collector's persisted source policy before scheduling")
    parser.add_argument("source_key", choices=sorted(SCHEDULE_CANDIDATES))
    args = parser.parse_args()
    database_url = os.getenv("PRUEVIA_DATABASE_URL")
    if not database_url:
        parser.error("PRUEVIA_DATABASE_URL is required")
    try:
        with psycopg.connect(database_url) as connection:
            approved = check_source(connection, SCHEDULE_CANDIDATES[args.source_key])
    except SourceNotApproved as error:
        print(json.dumps({"source_key": args.source_key, "eligible": False, "reason": str(error)}))
        return 2
    print(json.dumps({"source_key": approved.source_key, "eligible": True}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
