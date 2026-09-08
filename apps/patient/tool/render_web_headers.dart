import 'dart:io';

const _header = '''Content-Security-Policy: default-src 'self'; base-uri 'none'; object-src 'none'; frame-ancestors 'none'; form-action 'self'; script-src 'self' https://www.gstatic.com 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src '';
  worker-src 'self' blob:; manifest-src 'self'; media-src 'self' blob:; frame-src 'none'
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(self), microphone=(), geolocation=(self), payment=(), usb=()
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Resource-Policy: same-origin

/
  Cache-Control: no-cache, no-store, must-revalidate

/index.html
  Cache-Control: no-cache, no-store, must-revalidate

/flutter_service_worker.js
  Cache-Control: no-cache, no-store, must-revalidate

/main.dart.js
  Cache-Control: public, max-age=31536000, immutable
''';

void main(List<String> args) {
  String? output;
  String? hosts;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--output' && i + 1 < args.length) output = args[++i];
    if (args[i] == '--allowed-hosts' && i + 1 < args.length) hosts = args[++i];
  }
  if (output == null || hosts == null) {
    stderr.writeln('usage: dart run tool/render_web_headers.dart --output PATH --allowed-hosts HOST[,HOST]');
    exitCode = 2;
    return;
  }
  final values = hosts
      .split(',')
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();
  if (values.isEmpty || values.any((value) => !RegExp(r'^[a-z0-9.-]+$').hasMatch(value) || value.contains('..'))) {
    stderr.writeln('allowed hosts must be exact DNS hostnames');
    exitCode = 2;
    return;
  }
  final connectSources = ["'self'", ...values.map((value) => 'https://$value')].join(' ');
  final rendered = _header.replaceFirst("connect-src '';", "connect-src $connectSources;");
  final file = File(output);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(rendered);
}
