import importlib.util
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "migration_order", ROOT / "scripts/check_migration_order.py"
)
gate = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(gate)


def payload(*rows):
    return {"migrations": [{"local": local, "remote": remote} for local, remote in rows]}


def test_accepts_applied_prefix_with_pending_tail():
    assert gate.validate_migrations(
        payload(
            ("20260904110000", "20260904110000"),
            ("20260904120000", ""),
            ("20260904130000", ""),
        )
    ) == {"local": 3, "applied": 1, "pending": 2}


@pytest.mark.parametrize(
    "value",
    [
        payload(
            ("20260904110000", "20260904110000"),
            ("20260904120000", ""),
            ("20260904130000", "20260904130000"),
        ),
        payload(
            ("20260904120000", "20260904120000"),
            ("20260904110000", "20260904110000"),
        ),
        payload(
            ("20260904110000", "20260904100000"),
        ),
        payload(
            ("20260904110000", "20260904110000"),
            ("20260904110000", ""),
        ),
    ],
)
def test_rejects_skips_mismatches_and_duplicates(value):
    with pytest.raises(ValueError):
        gate.validate_migrations(value)


def test_rejects_malformed_response():
    with pytest.raises(ValueError):
        gate.validate_migrations({"migrations": []})
