import 'package:flutter/material.dart';

import 'widgets/app_widgets.dart';

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF101827) : canvas;
    final surface = isDark ? const Color(0xFF1C2940) : Colors.white;
    final foreground = isDark ? const Color(0xFFF2F5FC) : ink;
    final secondary = isDark ? const Color(0xFFB4C1D4) : muted;
    final primary = isDark ? const Color(0xFF91A9FF) : accent;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      cardColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        centerTitle: false,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: background),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: foreground),
        bodySmall: TextStyle(color: secondary),
      ),
    );
  }
}
