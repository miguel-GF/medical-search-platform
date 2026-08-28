import pytest

from pruevia_collectors.puebla_retry import build_retry_seeds, is_retryable_provider


def _manifest():
    return {
        "version": "puebla-generic-discovery-v1",
        "providers": [
            {
                "host": "empty.example",
                "seed_urls": ["https://empty.example/"],
                "status": "empty",
                "denue_record_ids": ["1"],
                "classifications": ["direct_clinical"],
            },
            {
                "host": "timeout.example",
                "seed_urls": ["https://timeout.example/"],
                "status": "failed",
                "errors": ["adapter: timeout"],
            },
            {
                "host": "robots.example",
                "seed_urls": ["https://robots.example/"],
                "status": "failed",
                "errors": ["adapter: disallowed by robots.txt"],
            },
            {
                "host": "dns.example",
                "seed_urls": ["https://dns.example/"],
                "status": "failed",
                "errors": ["adapter: unresolved hosts"],
            },
        ],
    }


def test_retry_policy_only_selects_empty_and_transient_errors():
    manifest = _manifest()
    assert is_retryable_provider(manifest["providers"][0])
    assert is_retryable_provider(manifest["providers"][1])
    assert not is_retryable_provider(manifest["providers"][2])
    assert not is_retryable_provider(manifest["providers"][3])
    assert [seed.host for seed in build_retry_seeds(manifest, max_providers=50)] == ["empty.example", "timeout.example"]


def test_retry_seeds_reject_wrong_manifest_version():
    manifest = _manifest()
    manifest["version"] = "other"
    with pytest.raises(ValueError, match="version"):
        build_retry_seeds(manifest, max_providers=1)
