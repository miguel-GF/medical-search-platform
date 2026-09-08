from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_provider_identity_gate_treats_unknown_anonymous_marker_as_unsafe():
    """Keep the SQL gate fail-closed if Auth ever exposes a nullable marker."""
    sql = (ROOT / "supabase/migrations/20260906220000_provider_non_anonymous_identity.sql").read_text(
        encoding="utf-8-sig"
    )
    assert "u.is_anonymous is false" in sql
    assert "coalesce(u.is_anonymous, false)" not in sql


def test_early_provider_boundaries_are_safe_before_later_replacements():
    """A partially applied migration window must not weaken provider MFA."""
    for relative in (
        "supabase/migrations/20260904115000_provider_aal2_immediate_hardening.sql",
        "supabase/migrations/20260904110000_provider_aal2_enforcement.sql",
        "supabase/migrations/20260904130000_provider_worker_trust_boundary.sql",
        "supabase/migrations/20260904150000_provider_document_storage.sql",
    ):
        sql = (ROOT / relative).read_text(encoding="utf-8-sig")
        assert "u.is_anonymous is false" in sql
        assert "auth.mfa_factors" in sql
