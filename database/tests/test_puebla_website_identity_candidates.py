import json
from pathlib import Path

from database.scripts.build_puebla_website_identity_candidates import build_fixture


ROOT = Path(__file__).parents[1]


def test_builder_keeps_a_broad_identity_only_puebla_portfolio():
    fixture = json.loads((ROOT / "fixtures/denue_candidates_puebla_v1.json").read_text(encoding="utf-8"))
    result = build_fixture(fixture)

    assert result["version"] == "generic-provider-identity-candidates-puebla-v1"
    assert result["summary"]["providers"] >= 20
    assert result["summary"]["denue_locations"] >= 25
    assert result["mappings"] == []
    assert all(provider["identity_note"].endswith("verification_pending.") for provider in result["providers"])
    assert not {provider["source_key"] for provider in result["providers"]} & {
        "generic_chopo_com_mx",
        "generic_salud_digna_org",
        "generic_ssdrsimi_com_mx",
    }

