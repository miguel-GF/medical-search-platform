"""Render the versioned resolver benchmark fixture as a pgTAP SQL test."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

try:  # Package import for tests; direct import for the CLI entrypoint.
    from .artifact_io import MAX_FIXTURE_BYTES, read_json_file
except ImportError:  # pragma: no cover - exercised by direct script invocation
    from artifact_io import MAX_FIXTURE_BYTES, read_json_file


def sql(value: object) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    text = str(value).replace("'", "''")
    return f"'{text}'"


def render(fixture: dict, *, diagnostic: bool = False) -> str:
    cases = fixture.get("cases")
    if not isinstance(cases, list) or not 100 <= len(cases) <= 200:
        raise ValueError("fixture must contain 100-200 cases")
    values: list[str] = []
    for case in cases:
        if not isinstance(case, dict):
            raise ValueError("benchmark cases must be objects")
        case_id = str(case.get("id") or "").strip()
        query = str(case.get("query") or "")
        expected = str(case.get("expected_status") or "").strip()
        if not case_id or expected not in {"resolved", "abstain"}:
            raise ValueError(f"invalid benchmark case: {case!r}")
        allowed = case.get("allowed_statuses") or (["resolved"] if expected == "resolved" else ["ambiguous", "no_match"])
        if not isinstance(allowed, list) or not allowed:
            raise ValueError(f"case {case_id} needs allowed_statuses")
        allowed_sql = "array[" + ", ".join(sql(str(status)) for status in allowed) + "]::text[]"
        methods = case.get("allowed_match_methods") or []
        methods_sql = "array[" + ", ".join(sql(str(method)) for method in methods) + "]::text[]"
        values.append(
            "(" + ", ".join(
                [
                    sql(case_id),
                    sql(query),
                    sql(expected),
                    sql(case.get("expected_item_id")),
                    allowed_sql,
                    methods_sql,
                    sql(str(case.get("class") or "")),
                ]
            ) + ")"
        )

    expected_safe = sum(1 for case in cases if case.get("expected_status") == "resolved")
    expected_panels = sum(1 for case in cases if case.get("id", "").startswith("panels_"))
    expected_under = sum(1 for case in cases if case.get("id", "").startswith("underspecified_"))
    expected_negative = sum(1 for case in cases if case.get("id", "").startswith("negative_"))
    values_sql = ",\n    ".join(values)
    if diagnostic:
        tail = """select case_id, query, expected_status, expected_item_id,
       actual_status, actual_item_id, actual_match_method, actual_candidate_count
from resolver_benchmark_results
where (expected_status = 'resolved' and (actual_status <> 'resolved'
    or actual_item_id::text <> expected_item_id
    or actual_match_method <> all(allowed_match_methods)))
   or (expected_status = 'abstain' and not (actual_status = any(allowed_statuses)))
order by case_id;
"""
    else:
        tail = f"""select extensions.plan(10);
select extensions.is((select count(*)::integer from resolver_benchmark_results), {len(cases)}, 'benchmark contains the reviewed 100-200 cases');
select extensions.is((select count(*)::integer from resolver_benchmark_results where expected_status = 'resolved'), {expected_safe}, 'safe variant cases are present');
select extensions.is((select count(*)::integer from resolver_benchmark_results where case_id like 'panels_%'), {expected_panels}, 'panel ambiguity cases are present');
select extensions.is((select count(*)::integer from resolver_benchmark_results where case_id like 'underspecified_%'), {expected_under}, 'underspecified cases are present');
select extensions.is((select count(*)::integer from resolver_benchmark_results where case_id like 'negative_%'), {expected_negative}, 'negative/adversarial cases are present');
select extensions.is((select count(*)::integer from resolver_benchmark_results where expected_status = 'resolved' and actual_status = 'resolved'), {expected_safe}, 'every safe variant resolves');
select extensions.is((select count(*)::integer from resolver_benchmark_results where expected_status = 'resolved' and actual_item_id::text = expected_item_id), {expected_safe}, 'every safe variant resolves to its reviewed item');
select extensions.is((select count(*)::integer from resolver_benchmark_results where expected_status = 'resolved' and actual_match_method = any(allowed_match_methods)), {expected_safe}, 'every safe variant has exact or approved-alias evidence');
select extensions.is((select count(*)::integer from resolver_benchmark_results where expected_status = 'abstain' and actual_status = any(allowed_statuses)), {len(cases) - expected_safe}, 'every ambiguous or unrelated query abstains safely');
select extensions.is((select count(*)::integer from resolver_benchmark_results where case_id like 'negative_%' and actual_status = 'no_match'), {expected_negative}, 'adversarial and unrelated input returns no_match');
select * from extensions.finish();
"""
    version = str(fixture.get("version") or "resolver-benchmark")
    return f"""-- Generated from {version}; do not hand-edit.
begin;
create extension if not exists pgtap with schema extensions;

create temporary table resolver_benchmark_results on commit drop as
with cases(case_id, query, expected_status, expected_item_id, allowed_statuses, allowed_match_methods, case_class) as (
  values
    {values_sql}
), resolved as (
  select
    c.*,
    r.item_id as actual_item_id,
    coalesce(r.resolution_status, 'no_match') as actual_status,
    r.match_method as actual_match_method,
    coalesce(r.candidate_count, 0)::integer as actual_candidate_count
  from cases c
  left join lateral (
    select x.*, count(*) over ()::integer as candidate_count
    from catalog.resolve_items_v6(c.query, 'health_diagnostics', null, 10) x
    order by x.result_rank
    limit 1
  ) r on true
)
select * from resolved;

{tail}

rollback;
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--diagnostic", action="store_true")
    args = parser.parse_args()
    fixture = read_json_file(args.fixture, max_bytes=MAX_FIXTURE_BYTES)
    args.output.write_text(render(fixture, diagnostic=args.diagnostic), encoding="utf-8")
    print(f"wrote benchmark SQL for {len(fixture['cases'])} cases to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
