import 'package:flutter/material.dart';

/// Shared Pruevia visual tokens. Keep these values mirrored by the Vue Admin
/// and future Nuxt tokens so the products feel like one system.
abstract final class PrueviaColors {
  static const teal = Color(0xFF0F766E);
  static const tealStrong = Color(0xFF115E59);
  static const navy = Color(0xFF0F172A);
  static const canvas = Color(0xFFF8FAFC);
  static const success = Color(0xFF15803D);
  static const warning = Color(0xFFB45309);
  static const danger = Color(0xFFB91C1C);
}

ThemeData buildPrueviaTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: PrueviaColors.teal,
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFF5EEAD4) : PrueviaColors.teal,
        onPrimary: dark ? PrueviaColors.navy : Colors.white,
        secondary: dark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
        surface: dark ? const Color(0xFF111827) : Colors.white,
        surfaceContainerHighest: dark
            ? const Color(0xFF1F2937)
            : const Color(0xFFE2E8F0),
      );
  final text = dark ? Colors.white : PrueviaColors.navy;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF0B1220)
        : PrueviaColors.canvas,
    fontFamily: 'Inter',
    textTheme: Typography.material2021().black.apply(
      bodyColor: text,
      displayColor: text,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF0B1220) : PrueviaColors.canvas,
      foregroundColor: text,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF111827) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: dark ? const Color(0xFF111827) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: scheme.outlineVariant),
    ),
  );
}
