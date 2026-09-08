"""Local configuration loading for collector command-line tools."""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv


COLLECTORS_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_ENV_FILE = COLLECTORS_ROOT / ".env"


def load_local_environment(env_file: Path = DEFAULT_ENV_FILE) -> None:
    """Load collector-local ``.env`` without overriding process variables."""

    # Explicit process/CI variables win because override=False is intentional.
    # Missing files are harmless, allowing the same CLI to run in CI/production.
    load_dotenv(dotenv_path=env_file, override=False)


def require_local_private_host_mode(enabled: bool) -> None:
    """Prevent the SSRF-prone private-host test mode outside local environments."""

    if enabled and os.environ.get("APP_ENV", "").strip().casefold() not in {"development", "test"}:
        raise ValueError("private-host mode requires APP_ENV=development or APP_ENV=test")
