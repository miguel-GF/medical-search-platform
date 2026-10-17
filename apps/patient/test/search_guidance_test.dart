import 'package:flutter_test/flutter_test.dart';
import 'package:pruevia_patient/src/search_guidance.dart';

void main() {
  test('blood alone does not become a confirmed study', () {
    final message = noMatchGuidance('metieron sangre');
    expect(message, contains('no identifica un estudio único'));
    expect(message, contains('sólo si eso es lo que te solicitaron'));
  });

  test('other no-match queries remain a clarification', () {
    expect(
      noMatchGuidance('estudio desconocido'),
      contains('no son estudios confirmados'),
    );
  });
}
