from types import SimpleNamespace

import pytest

from pruevia_collectors.puebla_discovery import (
    _summarize_run,
    build_puebla_seeds,
    normalize_website_url,
    run_puebla_discovery,
)


def test_normalize_website_url_adds_scheme_and_rejects_credentials():
    assert normalize_website_url(" WWW.Foo.example/path#fragment ") == "https://foo.example/path"
    assert normalize_website_url("https://foo.example/path?token=do-not-persist") == "https://foo.example/path"
    assert normalize_website_url("https://user:pass@example.test") is None
    assert normalize_website_url("https://example.test:8443") is None
    assert normalize_website_url("mailto:lab@example.test") is None
    assert normalize_website_url("") is None


def test_build_puebla_seeds_deduplicates_hosts_and_keeps_denue_identity():
    fixture = {
        "candidates": [
            {"external_record_id": "2", "website_url": "WWW.Foo.example/servicios", "classification": "direct_clinical"},
            {"external_record_id": "1", "website_url": "https://www.foo.example", "classification": "direct_clinical"},
            {"external_record_id": "3", "website_url": "https://bar.example", "classification": "direct_clinical"},
        ],
        "review_queue": [
            {"external_record_id": "4", "website_url": "https://review.example", "classification": "related_clinical"}
        ],
    }
    seeds = build_puebla_seeds(fixture, max_seeds_per_host=1)
    assert [seed.host for seed in seeds] == ["bar.example", "foo.example"]
    assert seeds[1].seed_urls == ("https://foo.example/",)
    assert seeds[1].denue_record_ids == ("1", "2")
    assert len(build_puebla_seeds(fixture, include_review=True)) == 3


def test_build_puebla_seeds_rejects_invalid_budget():
    with pytest.raises(ValueError, match="max_seeds_per_host"):
        build_puebla_seeds({"candidates": []}, max_seeds_per_host=0)
    with pytest.raises(ValueError, match="max_seeds_per_host"):
        build_puebla_seeds({"candidates": []}, max_seeds_per_host=11)


def test_puebla_discovery_marks_empty_website_population(tmp_path):
    fixture = tmp_path / "candidates.json"
    fixture.write_text('{"source_records": 489, "candidates": []}', encoding="utf-8")

    result = run_puebla_discovery(fixture, tmp_path / "artifacts")

    assert result["status"] == "empty"
    assert result["denue_source_records"] == 489
    assert result["denue_rows_considered"] == 0


def test_puebla_summary_streams_and_ignores_unhashable_record_types(tmp_path):
    artifact = tmp_path / "run"
    artifact.mkdir()
    (artifact / "raw_records.jsonl").write_text(
        '{"record_type": ["attacker-controlled"]}\n'
        '{"record_type": "provider_offer_discovered"}\n',
        encoding="utf-8",
    )
    summary = SimpleNamespace(
        artifact_directory=str(artifact),
        status="succeeded",
        records_received=2,
        records_valid=2,
        records_rejected=0,
        run_id="run-1",
        errors=[],
    )
    adapter = SimpleNamespace(pages_fetched=1, pages_failed=0)
    seed = SimpleNamespace(host="example.test", seed_urls=(), denue_record_ids=(), classifications=())

    result = _summarize_run(seed, summary, adapter, tmp_path)

    assert result["offers"] == 1
