import re
from pathlib import Path


CONFIG = Path(__file__).resolve().parents[1] / "supabase" / "config.toml"


def test_local_auth_defaults_fail_closed_for_privileged_access():
    """Keep the reproducible local Auth profile aligned with the AAL2 policy."""
    text = CONFIG.read_text(encoding="utf-8")

    def section(name: str) -> str:
        match = re.search(
            rf"(?ms)^\[{re.escape(name)}\]\s*(.*?)(?=^\[|\Z)", text
        )
        assert match, f"missing Supabase config section [{name}]"
        return match.group(1)

    def value(body: str, key: str) -> str:
        match = re.search(rf"(?m)^\s*{re.escape(key)}\s*=\s*(.+?)\s*$", body)
        assert match, f"missing Supabase config key {key}"
        return match.group(1).strip().strip('"')

    auth = section("auth")
    assert value(auth, "enable_signup") == "false"
    assert value(auth, "enable_anonymous_sign_ins") == "false"
    assert value(auth, "enable_manual_linking") == "false"
    assert value(auth, "enable_refresh_token_rotation") == "true"
    assert int(value(auth, "minimum_password_length")) >= 12
    assert value(auth, "password_requirements") == "lower_upper_letters_digits_symbols"

    email = section("auth.email")
    assert value(email, "enable_signup") == "false"
    assert value(email, "secure_password_change") == "true"
    assert value(email, "enable_confirmations") == "true"

    totp = section("auth.mfa.totp")
    assert value(totp, "enroll_enabled") == "true"
    assert value(totp, "verify_enabled") == "true"

    # SMS MFA is intentionally disabled: this deployment uses TOTP and must
    # not silently add a weaker factor to the privileged authentication path.
    phone = section("auth.mfa.phone")
    assert value(phone, "enroll_enabled") == "false"
    assert value(phone, "verify_enabled") == "false"
