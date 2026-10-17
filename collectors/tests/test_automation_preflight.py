from unittest.mock import MagicMock

import pytest

from pruevia_collectors.automation_preflight import (
    SCHEDULE_CANDIDATES,
    SourceNotApproved,
    check_source,
)


def _connection(rows):
    connection = MagicMock()
    connection.execute.return_value.fetchall.return_value = rows
    return connection


def test_preflight_accepts_unique_reviewed_source_at_expected_endpoint():
    source = SCHEDULE_CANDIDATES["chopo_puebla"]
    connection = _connection([
        ("source-id", "active", "approved", "brand-id", "endpoint-id", "active", source.endpoint_url)
    ])

    result = check_source(connection, source)

    assert result.source_id == "source-id"
    assert result.endpoint_id == "endpoint-id"
    assert connection.execute.call_args.args[1] == (
        source.name, source.source_type, f"{source.name} collector endpoint"
    )


@pytest.mark.parametrize("rows", [
    [],
    [("source-id", "active", "review_required", "brand-id", "endpoint-id", "active", "https://example.test")],
    [("source-id", "blocked", "approved", "brand-id", "endpoint-id", "active", "https://example.test")],
    [("source-id", "active", "approved", None, "endpoint-id", "active", "https://example.test")],
    [("source-id", "active", "approved", "brand-id", "endpoint-id", "paused", "https://example.test")],
])
def test_preflight_rejects_unreviewed_or_inactive_source(rows):
    with pytest.raises(SourceNotApproved):
        check_source(_connection(rows), SCHEDULE_CANDIDATES["chopo_puebla"])


def test_preflight_rejects_duplicate_or_changed_endpoint():
    source = SCHEDULE_CANDIDATES["chopo_puebla"]
    row = ("source-id", "active", "approved", "brand-id", "endpoint-id", "active", source.endpoint_url)
    with pytest.raises(SourceNotApproved, match="exactly one"):
        check_source(_connection([row, row]), source)
    changed = (*row[:-1], "https://different.example.test/catalog")
    with pytest.raises(SourceNotApproved, match="endpoint is not approved"):
        check_source(_connection([changed]), source)
