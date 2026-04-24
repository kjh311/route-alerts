import 'package:flutter/material.dart';

/// Route Alerts Design System
/// 
/// A rugged, high-contrast theme engineered for high-vibration truck environments.
/// Extracted from Stitch Project 'Route Alerts Planner UI'.
class AppDesignSystem {
  // Spacing & Layout
  static const double baseUnit = 8.0;
  static const double marginEdge = 24.0;
  static const double gutter = 16.0;
  static const double stackGap = 12.0;
  static const double touchTargetMin = 56.0;

  // Colors
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E); // Level 1 (Cards)
  static const Color surfaceLighter = Color(0xFF2C2C2C); // Level 2 (Modals)
  
  static const Color primary = Color(0xFFFF8C00); // Safety Orange
  static const Color secondary = Color(0xFF007BFF); // Electric Blue
  static const Color tertiary = Color(0xFF2ECC71); // Success Green
  static const Color error = Color(0xFFFFB4AB);

  static const Color onBackground = Color(0xFFE5E2E1);
  static const Color onPrimary = Color(0xFF4D2600);
  static const Color onSecondary = Colors.white;

  // Shapes
  static const double radiusSmall = 4.0;
  static const double radiusDefault = 8.0;
  static const double radiusLarge = 16.0;
  static const double radiusExtraLarge = 24.0;

  // Typography (Inter is assumed to be imported in pubspec.yaml)
  static TextStyle get displayLarge => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.02 * 40,
        height: 48 / 40,
      );

  static TextStyle get headlineLarge => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 34 / 28,
      );

  static TextStyle get headlineMedium => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 28 / 22,
      );

  static TextStyle get bodyLarge => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 26 / 18,
      );

  static TextStyle get bodyMedium => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
      );

  static TextStyle get labelBold => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 20 / 14,
      );

  /// Returns the complete ThemeData for the application
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        surface: surface,
        onSurface: onBackground,
        background: background,
        onBackground: onBackground,
        error: error,
      ),
      textTheme: TextTheme(
        displayLarge: displayLarge,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        labelLarge: labelBold,
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          side: const BorderSide(color: Color(0xFF333333), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(touchTargetMin),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusDefault),
          ),
          textStyle: labelBold.copyWith(fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: Color(0xFF333333), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: Color(0xFF333333), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: secondary, width: 2),
        ),
        labelStyle: bodyMedium,
      ),
    );
  }
}
