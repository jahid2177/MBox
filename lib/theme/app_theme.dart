import 'package:flutter/material.dart';

abstract final class AppColors {
  static const bg = Color(0xFF09090D);
  static const card = Color(0xFF17171F);
  static const surface = Color(0xFF22222D);
  static const teal = Color(0xFF00ADB5);
  static const muted = Color(0xFF9B9BAB);
  static const red = Color(0xFFE64654);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    brightness: Brightness.dark,
    surface: AppColors.bg,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: scheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: Colors.white,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.teal),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(color: AppColors.card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
  );
}
