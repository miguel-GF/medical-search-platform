import 'package:flutter_test/flutter_test.dart';

import '../tool/render_web_headers.dart';

void main() {
  test('web CSP permits only the runtime origins Flutter needs', () {
    final headers = renderWebHeaders(['api.pruevia.com.mx']);

    expect(headers, contains("base-uri 'self'"));
    expect(headers, isNot(contains("base-uri 'none'")));
    expect(headers, contains('https://api.pruevia.com.mx'));
    expect(headers, contains('https://www.gstatic.com'));
    expect(headers, contains('https://fonts.gstatic.com'));
    expect(headers, isNot(contains('https://*')));
  });

  test('web CSP rejects non-host connect destinations', () {
    expect(
      () => renderWebHeaders(['https://api.pruevia.com.mx']),
      throwsArgumentError,
    );
    expect(() => renderWebHeaders(['']), throwsArgumentError);
  });

  test('fixed-name Flutter bundle must revalidate across releases', () {
    final headers = renderWebHeaders(['api.pruevia.com.mx']);
    expect(
      headers,
      contains('/main.dart.js\n  Cache-Control: no-cache, no-store, must-revalidate'),
    );
    expect(headers, isNot(contains('immutable')));
  });
}
