from database.scripts.build_puebla_source_inventory import build_inventory


def test_inventory_separates_priority_chains_from_long_tail():
    report = build_inventory(
        {
            "source_run_id": "run-1",
            "source_records": 3,
            "candidates": [
                {"classification": "direct_clinical", "name": "ANÁLISIS CLÍNICOS DEL DOCTOR SIMI", "legal_name": "SISTEMAS DE SALUD DEL DR SIMI", "website_url": "WWW.SSDRSIMI.COM.MX"},
                {"classification": "direct_clinical", "name": "Laboratorio local", "legal_name": "", "website_url": ""},
                {"classification": "related_clinical", "name": "Hospital", "legal_name": "", "website_url": ""},
            ]
        },
        {"providers": [{"status": "succeeded", "records_valid": 2, "locations": 1, "offers": 1}]},
    )
    assert report["denue"]["direct_clinical"] == 2
    assert report["denue"]["direct_with_website"] == 1
    assert report["priority_groups"]["dr_simi"]["denue_records"] == 1
    assert report["denue"]["ungrouped_direct_records"] == 1
    assert report["generic_discovery"]["status_counts"] == {"succeeded": 1}
