import os
from pathlib import Path

from pruevia_collectors.config import load_local_environment


def test_load_local_environment_reads_file_without_overriding_process_value(
    monkeypatch, tmp_path: Path
):
    env_file = tmp_path / ".env"
    env_file.write_text("DENUE_API_TOKEN=from-file\n", encoding="utf-8")
    monkeypatch.delenv("DENUE_API_TOKEN", raising=False)

    load_local_environment(env_file)

    assert os.environ["DENUE_API_TOKEN"] == "from-file"

    monkeypatch.setenv("DENUE_API_TOKEN", "from-process")
    load_local_environment(env_file)
    assert os.environ["DENUE_API_TOKEN"] == "from-process"
