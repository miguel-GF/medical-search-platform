import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const privacyNoticeVersion = 'pruevia-privacidad-2026-10-15-v1';
const privacyNoticeReminderPeriod = Duration(days: 180);

class PatientPreferences {
  PatientPreferences._(this._prefs);

  final SharedPreferences _prefs;
  static const _consentKey = 'pruevia.consent.v1';
  static const _onboardingKey = 'pruevia.onboarding.v1';
  static const _themeKey = 'pruevia.theme.v1';
  static const _anonymousIdKey = 'pruevia.anonymous_id.v1';
  static const _privacyNoticeKey = 'pruevia.privacy_notice.acknowledgment.v1';

  static Future<PatientPreferences> load() async =>
      PatientPreferences._(await SharedPreferences.getInstance());

  bool get consentGiven => _prefs.getBool(_consentKey) ?? false;
  bool get onboardingComplete => _prefs.getBool(_onboardingKey) ?? false;

  DateTime? get privacyNoticeAcknowledgedAt {
    try {
      final raw = _prefs.getString(_privacyNoticeKey);
      if (raw == null) return null;
      final acknowledgment = jsonDecode(raw);
      if (acknowledgment is! Map<String, dynamic> ||
          acknowledgment['version'] != privacyNoticeVersion ||
          acknowledgment['date'] is! String) return null;
      return DateTime.tryParse(acknowledgment['date'] as String)?.toUtc();
    } catch (_) {
      return null;
    }
  }

  bool privacyNoticeReminderDue({DateTime? now}) {
    final current = (now ?? DateTime.now()).toUtc();
    final acknowledged = privacyNoticeAcknowledgedAt;
    return acknowledged == null ||
        acknowledged.isAfter(current) ||
        !current.isBefore(acknowledged.add(privacyNoticeReminderPeriod));
  }

  Future<void> acknowledgePrivacyNotice() async {
    // Informational acknowledgment only. No consent, identifier or API event.
    final saved = await _prefs.setString(_privacyNoticeKey, jsonEncode({
      'version': privacyNoticeVersion,
      'date': DateTime.now().toUtc().toIso8601String(),
    }));
    if (!saved) throw StateError('No se pudo guardar el recordatorio local.');
  }

  ThemeMode get themeMode => switch (_prefs.getString(_themeKey)) {
    'dark' => ThemeMode.dark,
    'light' => ThemeMode.light,
    _ => ThemeMode.system,
  };

  String get anonymousId {
    final existing = _prefs.getString(_anonymousIdKey);
    if (existing != null && _isUuid(existing)) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    // UUID v4-like identifier: anonymous and compatible with the API/DB type.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final value =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    _prefs.setString(_anonymousIdKey, value);
    return value;
  }

  bool _isUuid(String value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value);

  Future<void> completeOnboarding({required bool consent}) async {
    await _prefs.setBool(_consentKey, consent);
    await _prefs.setBool(_onboardingKey, true);
  }

  Future<void> grantConsent() => completeOnboarding(consent: true);

  Future<void> revokeConsent() async {
    await _prefs.setBool(_consentKey, false);
    // A new identifier prevents linking events recorded before revocation to
    // events recorded after a later opt-in.
    await _prefs.remove(_anonymousIdKey);
  }

  Future<void> setThemeMode(ThemeMode mode) async =>
      _prefs.setString(_themeKey, switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
      });
}
