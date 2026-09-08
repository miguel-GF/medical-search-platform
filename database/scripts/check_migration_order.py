"""Fail-closed check for the linked Supabase migration ledger.

Supabase applies migrations in filename order.  A later migration recorded as
applied while an earlier local migration is still pending means the database
cannot be reproduced safely from this checkout.  This read-only gate catches
that state before a Worker or another migration is deployed.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
from typing import Any


DATABASE = Path(__file__).resolve().parents[1]
VERSION_RE = re.compile(r"^\d{14}$")


def _version(value: Any, field: str) -> str:
    if not isinstance(value, str) or not VERSION_RE.fullmatch(value):
        raise ValueError(f"invalid {field} migration version")
    return value


def validate_migrations(payload: Any) -> dict[str, int]:
    """Validate the JSON returned by ``supabase migration list``.

    The remote ledger must be an exact prefix of the local migration list.
    This permits normal pending migrations but rejects skipped local versions,
    unknown remote versions, duplicates and out-of-order application.
    """
    if not isinstance(payload, dict) or not isinstance(payload.get("migrations"), list):
        raise ValueError("Supabase migration list returned an unexpected shape")
    entries = payload["migrations"]
    if not entries:
        raise ValueError("Supabase migration list is empty")

    local: list[str] = []
    remote: list[str] = []
    seen_local: set[str] = set()
    seen_remote: set[str] = set()
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError("Supabase migration list contains a malformed entry")
        local_version = _version(entry.get("local"), "local")
        if local_version in seen_local:
            raise ValueError(f"duplicate local migration {local_version}")
        seen_local.add(local_version)
        local.append(local_version)

        raw_remote = entry.get("remote")
        if raw_remote in (None, ""):
            continue
        remote_version = _version(raw_remote, "remote")
        if remote_version in seen_remote:
            raise ValueError(f"duplicate remote migration {remote_version}")
        seen_remote.add(remote_version)
        remote.append(remote_version)
        if remote_version != local_version:
            raise ValueError(
                f"remote migration {remote_version} does not match local {local_version}"
            )

    if local != sorted(local):
        raise ValueError("local migration list is not in timestamp order")
    if remote != sorted(remote):
        raise ValueError("remote migration ledger is out of order")
    applied_prefix = local[: len(remote)]
    if remote != applied_prefix:
        missing = next((version for version in local if version not in seen_remote), "unknown")
        raise ValueError(
            f"migration ledger skipped a local version before a later applied migration (first pending: {missing})"
        )
    return {"local": len(local), "applied": len(remote), "pending": len(local) - len(remote)}


def _find_json(stdout: str) -> Any:
    decoder = json.JSONDecoder()
    # The CLI may print progress messages before its final JSON response.
    for match in re.finditer(r"\{", stdout):
        try:
            value, end = decoder.raw_decode(stdout[match.start() :])
        except json.JSONDecodeError:
            continue
        if not stdout[match.start() + end :].strip():
            return value
    raise ValueError("Supabase did not return a complete migration list")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", default="supabase")
    parser.add_argument(
        "--package",
        help="Optional package/version argument when invoking through npx (for example supabase@2.116.0)",
    )
    args = parser.parse_args()
    cli = shutil.which(args.cli)
    if not cli:
        parser.error("Supabase CLI executable is not installed")
    try:
        response = subprocess.run(
            [cli, *([args.package] if args.package else []), "migration", "list", "--linked"],
            cwd=DATABASE,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=90,
            check=False,
        )
        if response.returncode != 0:
            raise ValueError("Supabase migration list failed")
        summary = validate_migrations(_find_json(response.stdout))
    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
        print(f"FAIL migration order gate: {exc}")
        return 1
    print(
        "PASS migration order gate: "
        f"{summary['applied']}/{summary['local']} applied, "
        f"{summary['pending']} pending"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
