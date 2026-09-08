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

  test('ignores non-finite numeric values from an untrusted payload', () {
    final offer = SearchOffer.fromJson({
      'id': 'offer-1',
      'provider': {'name': 'Proveedor'},
      'distance_meters': double.nan,
    });
    expect(offer.distanceMeters, isNull);
  });

  test('bounds and type-checks nested untrusted collections', () {
    final response = SearchResponse.fromJson({
      'query': 'hemograma',
      'results': List.generate(150, (index) => {
        'service': {'id': '$index', 'display_name': 'Servicio $index'},
        'offers': List.generate(150, (_) => {'provider': 'malformed'}),
      }),
    });
    expect(response.services, hasLength(100));
    expect(response.services.first.offers, hasLength(100));
    expect(response.services.first.offers.first.providerName, 'Proveedor');
  });

  test('bounds untrusted OCR review lines', () {
    final response = PackageResponse.fromJson({
      'ocr': {
        'text': 'hemograma',
        'low_confidence_lines': [
          'x' * 4097,
          'valid line',
        ],
      },
    });
    expect(response.ocr?.lowConfidenceLines, ['valid line']);
  });
}
