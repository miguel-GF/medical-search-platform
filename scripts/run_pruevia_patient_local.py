"""Compile and serve the authorized loopback patient app without DWDS.

Keeps the existing HTTP-only-for-debug client policy. Generated files stay in
ignored artifacts; source changes require a new build before being served.
"""
from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import subprocess
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_WEB_ROOT = ROOT / 'collectors/artifacts/local-stack/patient-web-debug'


class PatientHandler(SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        # Do not retain URLs, query text, cookies or client identifiers.
        return

    def list_directory(self, path):
        self.send_error(404)
        return None

    def end_headers(self):
        # Local source updates must not leave a stale shell in the browser cache.
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--web-root', type=Path, default=DEFAULT_WEB_ROOT)
    args = parser.parse_args()
    if os.name != 'nt':
        raise RuntimeError('This local builder uses the existing Windows Flutter installation')
    web_root = args.web_root.resolve()
    if (not web_root.is_relative_to((ROOT / 'collectors/artifacts').resolve())
            or web_root.name != 'patient-web-debug'):
        raise ValueError('Generated public files must stay inside ignored workspace artifacts')
    flutter = shutil.which('flutter.bat')
    if not flutter:
        raise RuntimeError('The existing Flutter installation is required')
    web_root.parent.mkdir(parents=True, exist_ok=True)
    # Fixed developer arguments only; no source values or secrets enter the shell.
    command = [flutter, 'build', 'web', '--debug', '--no-pub', '--no-wasm-dry-run',
               '--dart-define=API_BASE_URL=http://localhost:8787', '--output=' + str(web_root)]
    subprocess.run(command, cwd=ROOT / 'apps/patient', check=True)
    if not (web_root / 'index.html').is_file() or not (web_root / 'main.dart.js').is_file():
        raise RuntimeError('The compiled public app is incomplete')
    receipt = {'observed_at':datetime.now(timezone.utc).isoformat(), 'build_mode':'debug',
               'api_origin':'http://localhost:8787', 'host':'127.0.0.1', 'port':8080,
               'web_root':web_root.relative_to(ROOT).as_posix(), 'dwds_required':False,
               'formal_tests_executed':False}
    (web_root.parent / 'patient-server.json').write_text(
        json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(receipt),flush=True)
    with ThreadingHTTPServer(('127.0.0.1',8080),partial(PatientHandler,directory=str(web_root))) as server:
        server.serve_forever()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
