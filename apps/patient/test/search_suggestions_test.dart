import 'package:flutter_test/flutter_test.dart';
import 'package:pruevia_patient/src/models.dart';

void main() {
  test('suggestions do not count as confirmed services or offers', () {
    final response = SearchResponse.fromJson({
      'query': 'biometira hematica',
      'results': [],
      'suggestions': [
        {'item_id': 'item-1', 'display_name': 'Biometría hemática'},
      ],
    });
    expect(response.services, isEmpty);
    expect(response.suggestions.single.displayName, 'Biometría hemática');
  });
}
