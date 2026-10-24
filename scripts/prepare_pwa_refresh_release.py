"""Freeze PWA entrypoint fixes over the last verified public Flutter build."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'collectors/artifacts/android-optional-version-20261023'
PATIENT = ROOT / 'apps/patient'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.relative_to(ROOT / 'collectors/artifacts')
    out.mkdir(exist_ok=False, parents=True)
    receipt = json.loads((BASE / 'patient-release-receipt.json').read_bytes())
    for name, expected in receipt['source_hashes'].items():
        if name.startswith('lib/') or name in ('pubspec.yaml', 'pubspec.lock'):
            assert sha(PATIENT / name) == expected, 'Flutter source differs: ' + name
    original = BASE / 'patient-release/web'
    assert sha(original / 'main.dart.js') == receipt['main_js_sha256']
    dest = out / 'patient-release'
    shutil.copytree(original, dest / 'web')
    for name in ['index.html', 'install.js', 'pruevia-sw.js', 'pwa-updates.js', 'pwa-updates.css']:
        content = (PATIENT / 'web' / name).read_bytes().replace(b'$FLUTTER_BASE_HREF', b'/')
        (dest / 'web' / name).write_bytes(content)
    node = 'C:/laragon/bin/nodejs/node-v24.19.0-win-x64/node.exe'
    commands = [[node, '--check', str(dest / 'web' / name)] for name in ['install.js', 'pruevia-sw.js', 'pwa-updates.js']]
    commands.append(['C:/src/flutter/bin/dart.bat', 'run', 'tool/render_web_headers.dart', '--output', str(dest / 'web/_headers'), '--allowed-hosts', 'api.pruevia.com.mx'])
    for i, command in enumerate(commands):
        result = subprocess.run(command, cwd=PATIENT, capture_output=True, creationflags=subprocess.CREATE_NO_WINDOW)
        (out / ('package-' + str(i) + '.log')).write_bytes(result.stdout + result.stderr)
        assert result.returncode == 0, 'Packaging failed; inspect private log'
    assert sha(dest / 'web/main.dart.js') == receipt['main_js_sha256']
    shutil.copyfile(BASE / 'patient-release/wrangler.production.toml', dest / 'wrangler.production.toml')
    # Reuse the existing scoped publisher without changing its pinned original.
    helper = ROOT / 'collectors/artifacts/mobile-controls-20261018/release_ops.py'
    (out / 'release_ops.py').write_text(helper.read_text(encoding='utf-8'), encoding='utf-8')
    manifest = json.loads((dest / 'web/app-version.json').read_bytes())
    record = {'at': datetime.now(timezone.utc).isoformat(), 'base_version': '3073f58a-f0f3-40ab-8a2b-ca823820f54b', 'compiled_flutter_unchanged': True,
              'manifest': manifest, 'files_sha256': {p.relative_to(dest / 'web').as_posix(): sha(p) for p in (dest / 'web').rglob('*') if p.is_file()},
              'source_sha256': {p.relative_to(PATIENT).as_posix(): sha(p) for p in [*(PATIENT / 'lib').rglob('*.dart'), *(PATIENT / 'web').glob('*'), *(PATIENT / 'tool').glob('*.dart')] if p.is_file()},
              'scope': 'PWA shell and immutable entry URLs only; no SQL, API or landing deploy', 'deployed': False}
    (out / 'preparation.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'packaged': True, 'build': manifest['build'], 'compiled_flutter_unchanged': True, 'deployed': False}))


if __name__ == '__main__':
    main()
