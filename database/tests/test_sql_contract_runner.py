import importlib.util
import json
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("sql_contract_runner", ROOT / "scripts/run_sql_contracts.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


def response(*lines):
    return json.dumps({"rows": [{"result": line} for line in lines]})


def test_accepts_complete_ordered_tap():
    assert runner.validate_results(response("1..2", "ok 1 - first", "ok 2 - second"), 0, 2) == [
        "1..2", "ok 1 - first", "ok 2 - second"]


@pytest.mark.parametrize("output,code", [
    (response("1..2", "not ok 1 - bypass", "ok 2 - last passes"), 0),
    (response("ok 2 - only last result survived"), 0),
    (response("1..2", "ok 1 - first"), 0),
    (response("1..2", "ok 2 - wrong order", "ok 1 - first"), 0),
    (response("1..2", "ok 1 - duplicate", "ok 1 - duplicate"), 0),
    (response("1..2", "ok 1 - first # SKIP unavailable", "ok 2 - second"), 0),
    (response("1..2", "ok 1 - first # TODO missing control", "ok 2 - second"), 0),
    (response("1..2", "ok 1 - first", "ok 2 - second", "# Looks like you failed"), 0),
    (response("1..2", "ok 1 - first", "ok 2 - second"), 1),
    ('{"_tag":"Error","error":{"message":"SQL error"}}', 0),
    ('{"rows":[]}', 0),
    ('{"rows":[{"result":null}]}', 0),
    ('{"rows":[', 0),
    ('[]', 0),
])
def test_fails_closed(output, code):
    with pytest.raises(ValueError):
        runner.validate_results(output, code, 2)


@pytest.mark.parametrize("path", sorted((ROOT / "supabase/tests").glob("*.sql")), ids=lambda path: path.name)
def test_every_repository_contract_can_capture_all_results(path):
    sql, expected = runner.prepare_contract(path.read_text(encoding="utf-8-sig"))
    assert expected > 0
    assert sql.count("create temporary table security_contract_results") == 1
    assert "insert into security_contract_results(result) select extensions.plan(" in sql
    assert "insert into security_contract_results(result) select * from extensions.finish();" in sql
    assert sql.rstrip().endswith("select result from security_contract_results order by ordinal;\nrollback;")


@pytest.mark.parametrize("sql", [
    "begin;\nselect extensions.plan(1);\nselect * from extensions.finish();\ncommit;",
    "begin;\nselect extensions.no_plan();\nselect * from extensions.finish();\nrollback;",
    "begin;\nselect extensions.plan(1);\nrollback;\nselect 1;",
    "begin;\nselect extensions.plan(1);\nrollback;",
])
def test_rejects_unrecognized_transaction_contract(sql):
    with pytest.raises(ValueError):
        runner.prepare_contract(sql)
