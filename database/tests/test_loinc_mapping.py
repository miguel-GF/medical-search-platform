import json
from pathlib import Path

import pytest

from database.scripts.render_loinc_mapping import load_fixture, render


ITEM_ID = "00000000-0000-0000-0000-000000001103"


def _fixture(**overrides):
    mapping = {
        "item_id": ITEM_ID,
        "loinc_code": "57021-8",
        "mapping_type": "exact",
        "verified": True,
        "source_note": "RELMA reviewed; note 'safe'",
        "attributes": {
            "component": "Complete blood count",
            "property": "Number concentration",
            "system": "Blood",
            "order_observation": "both",
        },
    }
    mapping.update(overrides)
    return {"loinc_version": "2.83", "mappings": [mapping]}


def test_render_escapes_review_notes_and_preserves_mapping_identity():
    sql = render(_fixture())

    assert "http://loinc.org" in sql
    assert "57021-8" in sql
    assert "note ''safe''" in sql
    assert "on conflict (item_id, system, code, version)" in sql
    assert "loinc_version = excluded.loinc_version" in sql


def test_render_defaults_required_order_observation_when_attributes_are_partial():
    fixture = _fixture(attributes={"component": "Complete blood count"})

    sql = render(fixture)

    assert "'unknown'" in sql


def test_exact_mapping_requires_review_approval():
    with pytest.raises(ValueError, match="verified=true"):
        render(_fixture(verified=False))


def test_active_non_exact_mapping_requires_explicit_approval():
    with pytest.raises(ValueError, match="approved=true"):
        render(_fixture(mapping_type="related"))

    sql = render(_fixture(mapping_type="related", approved=True))
    assert "'related'" in sql


def test_invalid_code_and_duplicate_mapping_are_rejected():
    with pytest.raises(ValueError, match="invalid LOINC code"):
        render(_fixture(loinc_code="not-a-loinc-code"))

    duplicate = _fixture()
    duplicate["mappings"].append(dict(duplicate["mappings"][0]))
    with pytest.raises(ValueError, match="duplicate mapping"):
        render(duplicate)


def test_fixture_is_json_and_has_required_version(tmp_path: Path):
    path = tmp_path / "mapping.json"
    path.write_text(json.dumps(_fixture()), encoding="utf-8")

    loaded = load_fixture(path)

    assert loaded["loinc_version"] == "2.83"
    assert loaded["mappings"][0]["item_id"] == ITEM_ID
