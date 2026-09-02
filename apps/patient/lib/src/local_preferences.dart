import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PatientPreferences {
  PatientPreferences._(this._prefs);

  final SharedPreferences _prefs;
  static const _consentKey = 'pruevia.consent.v1';
  static const _themeKey = 'pruevia.theme.v1';
  static const _anonymousIdKey = 'pruevia.anonymous_id.v1';

  static Future<PatientPreferences> load() async =>
      PatientPreferences._(await SharedPreferences.getInstance());

  bool get consentGiven => _prefs.getBool(_consentKey) ?? false;

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

  Future<void> grantConsent() async => _prefs.setBool(_consentKey, true);
  Future<void> setThemeMode(ThemeMode mode) async =>
      _prefs.setString(_themeKey, switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
      });
}
