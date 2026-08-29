import json
import unicodedata
from pathlib import Path
import re

from database.scripts.build_resolver_benchmark_v2 import build
from database.scripts.render_resolver_benchmark_sql import render


ROOT = Path(__file__).parents[1]


def _normalize(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value)
    plain = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    return re.sub(r"[^a-z0-9]+", " ", plain.lower()).strip()


def test_field_benchmark_v2_is_new_and_balanced():
    fixture = build()
    cases = fixture["cases"]
    fixture_path = ROOT / "fixtures" / "resolver_benchmark_v2.json"
    committed = json.loads(fixture_path.read_text(encoding="utf-8"))
    v1 = json.loads((ROOT / "fixtures" / "resolver_benchmark_v1.json").read_text(encoding="utf-8"))

    assert committed == fixture
    assert fixture["version"] == "resolver-benchmark-v2"
    assert len(cases) == 200
    assert sum(case["expected_status"] == "resolved" for case in cases) == 184
    assert sum(case["expected_status"] == "abstain" for case in cases) == 16
    assert len({case["id"] for case in cases}) == len(cases)
    assert len({case["query"] for case in cases}) == len(cases)
    assert not ({_normalize(case["query"]) for case in cases} & {
        _normalize(case["query"]) for case in v1["cases"]
    })


def test_field_benchmark_v2_renders_assertions_and_scope_guards():
    sql = render(build())

    assert "Generated from resolver-benchmark-v2" in sql
    assert "benchmark contains the reviewed 100-200 cases" in sql
    assert "every safe variant resolves to its reviewed item" in sql
    assert "pruebas de covid" in sql
    assert "tomografía con contraste" in sql


def test_public_query_research_fixture_is_anonymized_and_bounded():
    fixture = json.loads(
        (ROOT / "fixtures" / "public_query_research_v1.json").read_text(encoding="utf-8")
    )
    assert fixture["privacy"]["clinical_authority"] is False
    assert len(fixture["records"]) == 64
    source_ids = {source["id"] for source in fixture["sources"]}
    assert {record["source_id"] for record in fixture["records"]} <= source_ids
    forbidden_keys = {"username", "author", "email", "address", "diagnosis", "post_body"}
    assert not forbidden_keys & set(fixture)
    assert all(len(record["query"]) <= 120 for record in fixture["records"])
