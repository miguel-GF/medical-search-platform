import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pruevia_patient/main.dart';

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
}
