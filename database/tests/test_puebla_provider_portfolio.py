from database.scripts.build_puebla_provider_portfolio import build_portfolio


def test_portfolio_joins_denue_identity_and_discovery_without_publishing():
    report = build_portfolio(
        {
            "version": "puebla-generic-discovery-v1",
            "fixture_source_run_id": "denue-run",
            "providers": [
                {
                    "host": "example.test",
                    "seed_urls": ["https://www.example.test/"],
                    "status": "succeeded",
                    "run_id": "crawl-run",
                    "records_received": 3,
                    "records_valid": 3,
                    "offers": 2,
                    "locations": 1,
                    "priced_offers": 1,
                }
            ],
        },
        {
            "providers": [
                {
                    "source_key": "generic_example_test",
                    "provider_key": "example_lab",
                    "brand_name": "Example Lab",
                    "website_url": "https://example.test/",
                    "denue_record_ids": ["1"],
                    "identity_note": "candidate",
                }
            ],
            "mappings": [{"source_key": "generic_example_test"}],
        },
        {
            "candidates": [
                {
                    "external_record_id": "1",
                    "name": "EXAMPLE LAB",
                    "postal_code": "72000",
                    "phone": "2220000000",
                    "coordinates": {"latitude": 19.04, "longitude": -98.2},
                }
            ]
        },
    )

    assert report["version"] == "puebla-provider-portfolio-v1"
    assert report["totals"] == {
        "providers": 1,
        "providers_with_website_evidence": 1,
        "denue_locations": 1,
        "discovered_offers": 2,
        "discovered_locations": 1,
        "priced_offers": 1,
        "approved_exact_mappings": 1,
    }
    assert report["providers"][0]["identity_status"] == "verification_pending"


def test_portfolio_rejects_missing_denue_identity():
    try:
        build_portfolio(
            {"version": "puebla-generic-discovery-v1", "providers": []},
            {
                "providers": [
                    {
                        "source_key": "generic_example_test",
                        "provider_key": "example_lab",
                        "brand_name": "Example Lab",
                        "website_url": "https://example.test/",
                        "denue_record_ids": ["missing"],
                    }
                ],
                "mappings": [],
            },
            {"candidates": []},
        )
    except ValueError as error:
        assert "missing DENUE" in str(error)
    else:  # pragma: no cover
        raise AssertionError("missing DENUE identity must fail closed")
