"""Start the authorized Windows local stack, preserving review queue stops.

--install-startup installs a shortcut for the current Windows user and starts
missing services. Does not change PowerShell execution policy or remote flags.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
REF = "ymtcmfgwuzdqtsbuvzqf"
ARTIFACTS = ROOT / "collectors/artifacts/local-stack"
QUEUE = ROOT / "collectors/artifacts/local-review-queue"


def now():
    return datetime.now(timezone.utc).isoformat()


def save(name, payload):
    destination = ARTIFACTS / name
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    temporary.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    temporary.replace(destination)


def powershell(command, *, env=None):
    result = subprocess.run(
        ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", command],
        check=True, capture_output=True, text=True, env=env,
        creationflags=subprocess.CREATE_NO_WINDOW, timeout=30,
    )
    return result.stdout.strip()


def install_startup():
    pythonw = Path(sys.executable).with_name("pythonw.exe")
    if not pythonw.is_file():
        raise RuntimeError("A windowless Python executable is required")
    environment = dict(os.environ)
    environment.update(PRUEVIA_LOCAL_PYTHON=str(pythonw),
                       PRUEVIA_LOCAL_SCRIPT=str(Path(__file__).resolve()),
                       PRUEVIA_LOCAL_ROOT=str(ROOT))
    # Values are passed through the environment, never interpolated as code.
    command = r"""
$ErrorActionPreference = 'Stop'
$linkPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'PrueviaLocal.lnk'
$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut($linkPath)
$expectedArguments = '"' + $env:PRUEVIA_LOCAL_SCRIPT + '"'
if ((Test-Path -LiteralPath $linkPath) -and
    ($link.TargetPath -ne $env:PRUEVIA_LOCAL_PYTHON -or $link.Arguments -ne $expectedArguments)) {
    throw 'An unrelated startup shortcut already uses that name.'
}
$link.TargetPath = $env:PRUEVIA_LOCAL_PYTHON
$link.Arguments = $expectedArguments
$link.WorkingDirectory = $env:PRUEVIA_LOCAL_ROOT
$link.WindowStyle = 7
$link.Description = 'Pruevia local API, Admin, Patient and reviewed queue'
$link.Save()
Write-Output 'installed_current_user'
"""
    return powershell(command, env=environment)


def worker_pids():
    command = r"""
$ErrorActionPreference = 'Stop'
@((Get-CimInstance Win32_Process -Filter "Name = 'python.exe' OR Name = 'pythonw.exe'") |
    Where-Object { $_.CommandLine -like '*run_local_review_queue.py*' -and
        $_.CommandLine -like '*--project-ref ymtcmfgwuzdqtsbuvzqf*' -and
        $_.CommandLine -like '*--watch*' } |
    Select-Object -ExpandProperty ProcessId) | ConvertTo-Json -Compress
"""
    value = powershell(command)
    parsed = json.loads(value) if value else []
    return parsed if isinstance(parsed, list) else [parsed]


def listening(port):
    with socket.socket() as connection:
        connection.settimeout(1)
        return connection.connect_ex(("127.0.0.1", port)) == 0


def launch(name, args, directory, stamp, *, env=None):
    with (ARTIFACTS / f"{stamp}-{name}.stdout.log").open("ab") as output, \
            (ARTIFACTS / f"{stamp}-{name}.stderr.log").open("ab") as errors:
        process = subprocess.Popen(
            args, cwd=ROOT / directory, stdin=subprocess.DEVNULL,
            stdout=output, stderr=errors, env=env, creationflags=subprocess.CREATE_NO_WINDOW,
        )
    return process.pid


def batch_command(binary, arguments):
    # Windows executable paths cannot contain double quotes. Only fixed arguments
    # occur here; never use this helper for source data, secrets or user text.
    if any(character in binary for character in '\"\r\n'):
        raise ValueError("Unexpected executable path")
    return f'"{os.environ["COMSPEC"]}" /d /s /c ""{binary}" {arguments}"'


def installed_node():
    """Use an existing compatible runtime even when Windows login has old PATH."""
    candidates = []
    current = shutil.which("node.exe")
    if current:
        candidates.append(Path(current))
    # This workspace lives in Laragon. Limit fallback discovery to its runtime
    # directory; do not download, install, or change the user's global PATH.
    laragon_runtimes = ROOT.parents[1] / "bin/nodejs"
    candidates.extend(sorted(laragon_runtimes.glob("node-v*-win-x64/node.exe"), reverse=True))
    for candidate in dict.fromkeys(candidates):
        result = subprocess.run([str(candidate), "--version"], check=True,
                                capture_output=True, text=True, timeout=10,
                                creationflags=subprocess.CREATE_NO_WINDOW)
        version = tuple(int(part) for part in result.stdout.strip().lstrip("v").split("."))
        npm = candidate.with_name("npm.cmd")
        if version >= (22, 12, 0) and npm.is_file():
            return candidate, npm, result.stdout.strip()
    raise RuntimeError("An existing Node.js >=22.12 with npm is required; no runtime was installed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install-startup", action="store_true")
    args = parser.parse_args()
    if os.name != "nt":
        raise RuntimeError("This launcher requires Windows")
    if (ROOT / "database/supabase/.temp/project-ref").read_text().strip() != REF:
        raise RuntimeError("Linked project differs from the authorized destination")
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    import msvcrt
    with (ARTIFACTS / "startup.lock").open("a+b") as lock:
        lock.seek(0)
        if not lock.read(1):
            lock.write(b"0")
            lock.flush()
        lock.seek(0)
        try:
            msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
        except OSError:
            return 0
        receipt = {"project_ref": REF, "started_at": now(), "services": []}
        try:
            if args.install_startup:
                receipt["startup_shortcut"] = install_startup()
            node, npm, node_version = installed_node()
            child_env = dict(os.environ)
            child_env["PATH"] = str(node.parent) + os.pathsep + child_env.get("PATH", "")
            receipt["node_runtime"] = {"path": str(node), "version": node_version,
                                       "global_path_modified": False}
            flutter = shutil.which("flutter.bat")
            if not npm or not flutter:
                raise RuntimeError("Existing npm and Flutter installations are required")
            stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S-%f")
            services = [
                ("api", 8787, "apps/api", batch_command(str(npm), "run dev -- --ip 127.0.0.1 --port 8787")),
                ("admin", 5173, "apps/admin", batch_command(str(npm), "run dev -- --host 127.0.0.1 --port 5173 --strictPort")),
                ("patient", 8080, ".", [sys.executable, str(ROOT / "scripts/run_pruevia_patient_local.py")]),
            ]
            for name, port, directory, command in services:
                entry = {"service": name, "port": port}
                if listening(port):
                    entry["status"] = "port_in_use"
                else:
                    entry.update(status="started", process_id=launch(name, command, directory, stamp, env=child_env))
                receipt["services"].append(entry)
            pids = worker_pids()
            status_path = QUEUE / "status.json"
            status = json.loads(status_path.read_text(encoding="utf-8")) if status_path.exists() else {}
            entry = {"service": "review_queue"}
            if pids:
                entry.update(status="already_running", process_ids=pids)
            elif (QUEUE / "STOP").exists():
                entry["status"] = "stop_marker_preserved"
            elif status.get("status") in {"starting", "scanning", "stopped_error"}:
                entry["status"] = "ledger_inspection_required"
            else:
                command = [sys.executable, str(ROOT / "database/scripts/run_local_review_queue.py"),
                           "--queue", str(QUEUE / "queue.json"), "--project-ref", REF,
                           "--execute-reviewed", "--watch", "--interval-seconds", "300"]
                entry.update(status="started", process_id=launch("review-queue", command, ".", stamp))
            receipt["services"].append(entry)
            receipt["updated_at"] = now()
            save("startup.json", receipt)
            if sys.stdout is not None:
                print(json.dumps(receipt))
            return 0
        except Exception as error:
            receipt.update(status="startup_error", error_type=type(error).__name__, updated_at=now())
            save("startup-error.json", receipt)
            return 1
        finally:
            lock.seek(0)
            msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)


if __name__ == "__main__":
    raise SystemExit(main())
