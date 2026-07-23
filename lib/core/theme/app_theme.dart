import 'package:flutter/material.dart';

class AppTheme {
  static const cream = Color(0xFFFFF8E8);
  static const ink = Color(0xFF25332C);
  static const coral = Color(0xFFE96F51);
  static const leaf = Color(0xFF4D8B63);
  static const amber = Color(0xFFF2B84B);
  static const sky = Color(0xFF65A8B0);

  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: coral,
          brightness: Brightness.light,
          surface: cream,
        ).copyWith(
          primary: coral,
          onPrimary: Colors.black,
          secondary: leaf,
          onSecondary: Colors.black,
          tertiary: sky,
          onTertiary: Colors.black,
          onSurface: ink,
          surfaceContainerLowest: const Color(0xFFFFFCF5),
          surfaceContainerLow: const Color(0xFFFFF4DE),
          surfaceContainer: const Color(0xFFF9EBD1),
          outline: const Color(0xFF88796A),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: cream,
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
          color: ink,
        ),
        headlineSmall: TextStyle(fontWeight: FontWeight.w700, color: ink),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: ink),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: ink),
        bodyLarge: TextStyle(height: 1.45, color: ink),
        bodyMedium: TextStyle(height: 1.4, color: ink),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        height: 72,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        useIndicator: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
