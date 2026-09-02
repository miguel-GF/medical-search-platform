import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pruevia_patient/main.dart';
import 'package:pruevia_patient/src/models.dart';

void main() {
  testWidgets('consent screen explains traceability and privacy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ConsentScreen(onAccept: () async {})),
    );

    expect(find.text('Encuentra dónde hacer tus estudios'), findsOneWidget);
    expect(find.text('Información transparente'), findsOneWidget);
    expect(find.text('Privacidad desde el inicio'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('provider access stays secondary and explains step-up security', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProviderAccessSheet())),
    );

    expect(find.text('Acceso para proveedores'), findsOneWidget);
    expect(find.text('Continuar al acceso seguro'), findsOneWidget);
    expect(find.text('Segundo factor'), findsOneWidget);
  });

  testWidgets('search results group providers and branches', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SearchResultsExplorer(
              services: [
                SearchService(
                  id: 'service-1',
                  displayName: 'Biometría hemática',
                  confidence: 1,
                  offers: [
                    SearchOffer(
                      id: 'offer-1',
                      providerId: 'provider-1',
                      providerName: 'Laboratorio pequeño',
                      locationId: 'location-1',
                      locationName: 'Sucursal Centro',
                    ),
                    SearchOffer(
                      id: 'offer-2',
                      providerId: 'provider-1',
                      providerName: 'Laboratorio pequeño',
                      locationId: 'location-2',
                      locationName: 'Sucursal Norte',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Proveedores encontrados'), findsOneWidget);
    expect(find.text('Laboratorio pequeño'), findsWidgets);
    expect(find.textContaining('2 sucursales'), findsWidgets);
    expect(find.text('Selecciona una sucursal para ver sus estudios y precios'), findsOneWidget);
  });
}
