import importlib.util
import json
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("runtime_schema", ROOT / "scripts/check_runtime_schema.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


def valid_payload(value=None):
    return json.dumps({"rows": [{"security_schema": json.dumps(value or gate.EXPECTED)}]})


def test_accepts_exact_least_privilege_schema():
    assert gate.validate_payload(valid_payload(), 0) == gate.EXPECTED


@pytest.mark.parametrize("stdout,code", [
    (valid_payload({**gate.EXPECTED, "internal_document_storage_freeze": 0}), 0),
    (valid_payload({**gate.EXPECTED, "internal_document_write_freeze": 0}), 0),
    (valid_payload({**gate.EXPECTED, "worker_rpc_anon_exec": 1}), 0),
    (valid_payload({**gate.EXPECTED, "obsolete_scan_attestation": 1}), 0),
    (valid_payload({**gate.EXPECTED, "scan_queue_service_exec": 0}), 0),
    (json.dumps({"rows": []}), 0),
    (json.dumps({"_tag": "Error", "error": {"message": "failed"}}), 0),
    ("prefix {not-json}", 0),
    (valid_payload(), 1),
])
def test_fails_closed_on_unready_or_malformed_schema(stdout, code):
    with pytest.raises(ValueError):
        gate.validate_payload(stdout, code)
