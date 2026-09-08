"""Run repository pgTAP contracts, preserving and checking every assertion.

Supabase's Management API returns only the last result set. Capture TAP into a
transaction-local table so earlier failures cannot disappear behind finish().
This runs against an already migrated linked database; it never applies DDL
migrations. The SQL fixtures retain their BEGIN/ROLLBACK boundary.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


DATABASE = Path(__file__).resolve().parents[1]
FLAGS = re.IGNORECASE | re.MULTILINE


def prepare_contract(source: str) -> tuple[str, int]:
    """Instrument the repository's explicit, fixed-plan SQL contract format.

    This is not a parser for arbitrary SQL. Reject unfamiliar transaction or
    plan layouts instead of silently running a partially instrumented test.
    """
    if (len(re.findall(r"^begin;[ \t]*$", source, FLAGS)) != 1
            or len(re.findall(r"^rollback;[ \t]*$", source, FLAGS)) != 1
            or re.search(r"^commit\b", source, FLAGS)
            or not re.search(r"^rollback;\s*\Z", source, FLAGS)):
        raise ValueError("Contract must have one BEGIN and a final ROLLBACK, without COMMIT")
    plans = re.findall(r"^select extensions\.plan\(([0-9]+)\);[ \t]*$", source, FLAGS)
    if len(plans) != 1 or int(plans[0]) < 1:
        raise ValueError("Contract must declare one positive fixed pgTAP plan")
    if len(re.findall(r"^select \* from extensions\.finish\(\);[ \t]*$", source, FLAGS)) != 1:
        raise ValueError("Contract must call pgTAP finish exactly once")
    expected = int(plans[0])
    source = re.sub(
        r"^begin;[ \t]*$",
        "begin;\nset local lock_timeout = '5s';\nset local statement_timeout = '60s';\n"
        "create temporary table security_contract_results "
        "(ordinal bigint generated always as identity, result text);",
        source, flags=FLAGS,
    )
    source = re.sub(r"^select extensions\.",
                    "insert into security_contract_results(result) select extensions.", source, flags=FLAGS)
    source = re.sub(r"^select \* from extensions\.finish\(\);[ \t]*$",
                    "insert into security_contract_results(result) select * from extensions.finish();",
                    source, flags=FLAGS)
    source = re.sub(r"^rollback;[ \t]*$",
                    "select result from security_contract_results order by ordinal;\nrollback;",
                    source, flags=FLAGS)
    return source, expected


def validate_results(stdout: str, returncode: int, expected: int) -> list[str]:
    if returncode != 0:
        raise ValueError(f"Supabase CLI exited with status {returncode}")
    try:
        result = json.loads(stdout)
    except (ValueError, TypeError) as exc:
        raise ValueError("Supabase did not return a complete JSON result") from exc
    if not isinstance(result, dict) or result.get("_tag") == "Error":
        raise ValueError("Supabase returned an error or an invalid result")
    rows = result.get("rows")
    if not isinstance(rows, list) or not rows:
        raise ValueError("No TAP result rows returned")
    lines: list[str] = []
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get("result"), str):
            raise ValueError("Malformed TAP result row")
        lines.extend(row["result"].splitlines())
    if not lines or lines[0] != f"1..{expected}":
        raise ValueError("Missing or incorrect TAP plan")
    assertions = lines[1:]
    # This project's release gates allow neither skips nor TODO failures. An
    # empty, truncated, duplicated, reordered or extra result fails closed.
    if len(assertions) != expected:
        raise ValueError(f"Expected {expected} passing assertions; received {len(assertions)} result lines")
    for number, line in enumerate(assertions, 1):
        if not re.fullmatch(rf"ok {number} - [^\r\n]+", line) or re.search(r"#\s*(skip|todo)\b", line, re.I):
            raise ValueError(f"Non-passing TAP assertion {number}: {line}")
    return lines


def run_contract(path: Path, cli: str) -> int:
    sql, expected = prepare_contract(path.read_text(encoding="utf-8-sig"))
    # TemporaryDirectory handles only this runner's generated artifact. Never
    # run a cleanup against a user-provided repository or database path.
    with tempfile.TemporaryDirectory(prefix="pruevia-contract-") as directory:
        artifact = Path(directory) / "contract.sql"
        artifact.write_text(sql, encoding="utf-8")
        response = subprocess.run(
            [cli, "db", "query", "--linked", "--file", str(artifact)],
            cwd=DATABASE, capture_output=True, text=True, encoding="utf-8",
            timeout=120, check=False,
        )
    # Do not print raw upstream data or stderr (which may contain credentials,
    # row contents or SQL internals). TAP labels alone identify failing tests.
    validate_results(response.stdout, response.returncode, expected)
    return expected


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--test", help="One filename from supabase/tests (default: all)")
    parser.add_argument("--cli", default="supabase", help="Installed Supabase executable")
    args = parser.parse_args()
    cli = shutil.which(args.cli)
    if not cli:
        parser.error("Supabase CLI executable is not installed")
    contracts = DATABASE / "supabase" / "tests"
    if args.test:
        if not re.fullmatch(r"[a-z0-9_]+\.sql", args.test):
            parser.error("--test must be a SQL contract filename")
        paths = [contracts / args.test]
    else:
        paths = sorted(contracts.glob("*.sql"))
    if not paths:
        parser.error("No SQL contracts found")
    for path in paths:
        try:
            count = run_contract(path, cli)
        except (ValueError, OSError, subprocess.TimeoutExpired) as exc:
            print(f"FAIL {path.name}: {exc}")
            return 1
        print(f"PASS {path.name}: {count}/{count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
