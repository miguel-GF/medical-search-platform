import 'package:flutter_test/flutter_test.dart';

import 'package:pruevia_patient/src/models.dart';

void main() {
  test('search offers tolerate a null price history', () {
    final offer = SearchOffer.fromJson({
      'id': 'offer-1',
      'provider': {'name': 'Proveedor'},
      'price': null,
      'prices': null,
    });

    expect(offer.amountMinor, isNull);
    expect(offer.prices, isEmpty);
  });
}
