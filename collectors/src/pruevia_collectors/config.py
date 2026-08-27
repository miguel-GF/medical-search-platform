"""Local configuration loading for collector command-line tools."""

from __future__ import annotations

from pathlib import Path

from dotenv import load_dotenv


COLLECTORS_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_ENV_FILE = COLLECTORS_ROOT / ".env"


def load_local_environment(env_file: Path = DEFAULT_ENV_FILE) -> None:
    """Load collector-local ``.env`` without overriding process variables."""

    # Explicit process/CI variables win because override=False is intentional.
    # Missing files are harmless, allowing the same CLI to run in CI/production.
    load_dotenv(dotenv_path=env_file, override=False)
