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

  test('parses link capabilities without assuming a deep link exists', () {
    final response = SearchResponse.fromJson({
      'query': 'biometria hematica',
      'results': [
        {
          'service': {'id': 'service-1', 'display_name': 'Biometría hemática'},
          'offers': [
            {
              'id': 'offer-1',
              'provider': {'name': 'Salud Digna'},
              'location': {'id': 'location-1', 'name': 'Sucursal Centro'},
              'source': {
                'url': 'https://salud-digna.org/sucursal-centro',
                'location_url': 'https://salud-digna.org/sucursal-centro',
                'link_capability': 'location_only',
              },
            },
          ],
        },
      ],
    });
    final offer = response.services.single.offers.single;
    expect(offer.linkCapability, 'location_only');
    expect(offer.locationUrl, 'https://salud-digna.org/sucursal-centro');
    expect(offer.studyUrl, isNull);
  });

  test('ignores non-finite numeric values from an untrusted payload', () {
    final offer = SearchOffer.fromJson({
      'id': 'offer-1',
      'provider': {'name': 'Proveedor'},
      'distance_meters': double.nan,
    });
    expect(offer.distanceMeters, isNull);
  });

  test('parses a sourced patient-facing service description', () {
    final response = SearchResponse.fromJson({
      'query': 'biometría',
      'results': [
        {
          'service': {
            'id': 'service-1',
            'display_name': 'Biometría hemática',
            'description':
                'Mide las células presentes en una muestra de sangre.',
            'description_source_url': 'https://medlineplus.gov/spanish/',
          },
          'offers': [],
        },
      ],
    });

    expect(
      response.services.single.description,
      'Mide las células presentes en una muestra de sangre.',
    );
    expect(
      response.services.single.descriptionSourceUrl,
      'https://medlineplus.gov/spanish/',
    );
  });

  test('bounds and type-checks nested untrusted collections', () {
    final response = SearchResponse.fromJson({
      'query': 'hemograma',
      'results': List.generate(
        150,
        (index) => {
          'service': {'id': '$index', 'display_name': 'Servicio $index'},
          'offers': List.generate(150, (_) => {'provider': 'malformed'}),
        },
      ),
    });
    expect(response.services, hasLength(100));
    expect(response.services.first.offers, hasLength(100));
    expect(response.services.first.offers.first.providerName, 'Proveedor');
  });

  test('bounds untrusted OCR review lines', () {
    final response = PackageResponse.fromJson({
      'ocr': {
        'text': 'hemograma',
        'low_confidence_lines': ['x' * 4097, 'valid line'],
      },
    });
    expect(response.ocr?.lowConfidenceLines, ['valid line']);
  });

  test('keeps an extracted preparation qualifier as display-only metadata', () {
    final response = PackageResponse.fromJson({
      'items': [
        {
          'index': 1,
          'input': 'Biometría hemática',
          'status': 'resolved',
          'preparation_note': 'en ayuno de 8 horas',
          'candidates': [],
        },
      ],
    });
    expect(response.items.single.preparationNote, 'en ayuno de 8 horas');
  });
}
