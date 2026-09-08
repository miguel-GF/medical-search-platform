import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pruevia_patient/src/local_preferences.dart';

void main() {
  test('anonymous telemetry id is a UUID and legacy ids rotate', () async {
    SharedPreferences.setMockInitialValues({
      'pruevia.anonymous_id.v1': '0123456789abcdef0123456789abcdef',
    });
    final preferences = await PatientPreferences.load();

    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(preferences.anonymousId),
      isTrue,
    );
  });

  test('consent can be declined and revoked with identifier rotation', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await PatientPreferences.load();
    await preferences.completeOnboarding(consent: false);
    expect(preferences.onboardingComplete, isTrue);
    expect(preferences.consentGiven, isFalse);
    final before = preferences.anonymousId;
    await preferences.completeOnboarding(consent: true);
    expect(preferences.consentGiven, isTrue);
    await preferences.revokeConsent();
    expect(preferences.consentGiven, isFalse);
    expect(preferences.anonymousId, isNot(before));
  });
}
