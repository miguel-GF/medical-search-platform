import 'package:web/web.dart' as web;

void clearProviderLink() {
  if (web.window.location.hash.startsWith('#application=')) {
    web.window.history.replaceState(
      null,
      '',
      '${web.window.location.pathname}?provider=1',
    );
  }
}
