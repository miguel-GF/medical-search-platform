from database.scripts.report_generic_coverage import build_report


def test_report_separates_discovery_from_approved_mappings():
    manifest = {
        "version": "puebla-generic-discovery-v1",
        "status": "partial",
        "denue_source_records": 489,
        "denue_rows_considered": 213,
        "rows_with_website": 90,
        "unique_hosts": 47,
        "status_counts": {"empty": 10, "failed": 27, "succeeded": 10},
        "totals": {"pages_fetched": 63, "pages_failed": 27, "locations": 6, "offers": 48},
        "providers": [],
    }
    mappings = {
        "mappings": [
            {"source_key": "generic_familylabs_com_mx", "external_record_id": "one", "catalog_item_id": "item-1", "provider_key": "familylabs"},
            {"source_key": "generic_semindigital_com", "external_record_id": "two", "catalog_item_id": "item-2", "provider_key": "semin"},
        ]
    }
    retry = {
        "version": "puebla-generic-retry-v1",
        "providers_considered": 11,
        "status_counts": {"empty": 11},
        "totals": {"pages_fetched": 20, "offers": 0},
    }

    report = build_report(manifest, mappings, retry)

    assert report["discovered_offers"] == 48
    assert report["approved_mapping_records"] == 2
    assert report["unmapped_offer_records"] == 46
    assert report["retry"]["providers_considered"] == 11
