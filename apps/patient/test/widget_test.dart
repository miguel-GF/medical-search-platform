import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pruevia_patient/main.dart';
import 'package:pruevia_patient/src/api_client.dart';
import 'package:pruevia_patient/src/models.dart';

void main() {
  test('provider route stays closed unless the release gate is enabled', () {
    final uri = Uri.parse('https://app.pruevia.com.mx/?provider=1');
    expect(shouldOpenProviderPortal(uri, enabled: false), isFalse);
    expect(shouldOpenProviderPortal(uri, enabled: true), isTrue);
  });

  test('privacy and support destinations reject unsafe build values', () {
    expect(
      privacyPolicyUri('https://pruevia.com.mx/privacidad'),
      Uri.parse('https://pruevia.com.mx/privacidad'),
    );
    for (final value in [
      'http://pruevia.com.mx/privacidad',
      'https://pruevia.com.mx/otra',
      'https://pruevia.com.mx/privacidad?token=x',
      'https://evil.example/privacidad',
    ]) {
      expect(privacyPolicyUri(value), isNull);
    }
    expect(
      supportMailUri(' Soporte@Pruevia.com.mx '),
      Uri.parse('mailto:soporte@pruevia.com.mx'),
    );
    expect(supportMailUri('not-an-email'), isNull);
  });

  testWidgets('onboarding explains traceability and disabled analytics', (
    tester,
  ) async {
    var accepted = false;
    var declined = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ConsentScreen(
          onAccept: () async => accepted = true,
          onDecline: () async => declined = true,
        ),
      ),
    );

    expect(find.text('Encuentra dónde hacer tus estudios'), findsOneWidget);
    expect(find.text('Información transparente'), findsOneWidget);
    expect(find.text('Privacidad desde el inicio'), findsOneWidget);
    expect(
      find.textContaining('Esta versión no envía analítica'),
      findsOneWidget,
    );
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Continuar sin analítica'), findsNothing);

    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(accepted, isFalse);
    expect(declined, isTrue);
  });

  testWidgets('analytics build offers explicit accept and decline paths', (
    tester,
  ) async {
    var accepted = false;
    var declined = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ConsentScreen(
          analyticsEnabled: true,
          onAccept: () async => accepted = true,
          onDecline: () async => declined = true,
        ),
      ),
    );

    expect(find.textContaining('Si aceptas, el uso anónimo'), findsOneWidget);
    expect(find.text('Continuar sin analítica'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(accepted, isTrue);
    expect(declined, isFalse);
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
                  description:
                      'Mide las células presentes en una muestra de sangre.',
                  displayName: 'Biometría hemática',
                  confidence: 1,
                  offers: [
                    SearchOffer(
                      id: 'offer-1',
                      providerId: 'provider-1',
                      providerName: 'Laboratorio pequeño',
                      locationId: 'location-1',
                      locationName: 'Sucursal Centro',
                      prices: const [
                        SearchPrice(
                          type: 'online',
                          amountMinor: 18479,
                          currency: 'MXN',
                        ),
                        SearchPrice(
                          type: 'regular',
                          amountMinor: 28428,
                          currency: 'MXN',
                        ),
                      ],
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
    expect(
      find.text(
        'Compara las sucursales: sus estudios y precios aparecen debajo',
      ),
      findsOneWidget,
    );
    expect(find.text('En línea'), findsWidgets);
    expect(find.text('En sucursal'), findsWidgets);
    expect(
      find.text('Mide las células presentes en una muestra de sangre.'),
      findsOneWidget,
    );
    expect(find.text('Sobre este estudio'), findsOneWidget);
  });

  testWidgets(
    'feedback asks structured questions without requesting medical text',
    (tester) async {
      final api = PatientApiClient(baseUrl: 'https://api.test');
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedbackSheet(
              api: api,
              resultState: 'results',
              resultCount: 2,
            ),
          ),
        ),
      );

      expect(find.text('¿Te gustó la experiencia?'), findsOneWidget);
      expect(find.text('¿Te ayudó a encontrar una opción?'), findsOneWidget);
      expect(find.text('¿Coincidió con lo que esperabas?'), findsOneWidget);
      expect(find.textContaining('Evita compartir nombres'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    },
  );
}
