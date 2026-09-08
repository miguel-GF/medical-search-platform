import json

from database.scripts.build_resolver_benchmark import build
from database.scripts.render_resolver_benchmark_sql import render


def test_benchmark_is_versioned_and_covers_safe_and_abstention_cases():
    fixture = build()
    cases = fixture["cases"]

    assert fixture["version"] == "resolver-benchmark-v1"
    assert len(cases) == 200
    assert sum(case["expected_status"] == "resolved" for case in cases) == 147
    assert sum(case["expected_status"] == "abstain" for case in cases) == 53
    assert len({case["id"] for case in cases}) == len(cases)
    assert next(case for case in cases if case["query"] == "T3 libre")["expected_status"] == "abstain"


def test_benchmark_sql_escapes_queries_and_contains_remote_assertions():
    fixture = build()
    sql = render(fixture)

    assert "resolver_benchmark_results" in sql
    assert "extensions.plan(10)" in sql
    assert "adversarial and unrelated input returns no_match" in sql
    assert "DROP TABLE catalog.items" in sql
    assert "<script>alert(''xss'')</script>" in sql
    assert sql.rstrip().endswith("rollback;")
    assert render(fixture, diagnostic=True).rstrip().endswith("rollback;")


def test_benchmark_fixture_round_trips_as_json():
    fixture = build()
    encoded = json.dumps(fixture, ensure_ascii=False)
    decoded = json.loads(encoded)
    assert decoded["case_count"] == 200
    assert decoded["cases"][-1]["id"].startswith("negative_")
