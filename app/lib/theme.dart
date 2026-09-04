import 'package:flutter/material.dart';

/// Centralised theme so the scoring/calibration screens (which draw a lot
/// of custom overlays on top of the camera preview) stay visually
/// consistent with the rest of the app.
class AppTheme {
  AppTheme._();

  static const Color accent = Color(0xFFE53935); // dartboard red
  static const Color accentGreen = Color(0xFF2E7D32); // dartboard green

  static ThemeData light() {
    final base = ColorScheme.fromSeed(seedColor: accent);
    return ThemeData(
      colorScheme: base,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
  }

  static ThemeData dark() {
    final base = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    );
    return ThemeData(
      colorScheme: base,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
  }
}
