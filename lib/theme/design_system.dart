import 'package:flutter/material.dart';

/// Haul Alerts Design System
/// 
/// A rugged, high-contrast theme engineered for high-vibration truck environments.
/// Updated to match the high-fidelity HTML specification.
class AppDesignSystem {
  // Spacing & Layout
  static const double baseUnit = 8.0;
  static const double marginEdge = 24.0;
  static const double gutter = 16.0;
  static const double stackGap = 12.0;
  static const double touchTargetMin = 56.0;

  // Colors
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF131313); 
  static const Color surfaceContainer = Color(0xFF201F1F);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);
  
  static const Color primary = Color(0xFFFF8C00); // Safety Orange
  static const Color primaryVariant = Color(0xFFFFB77D); // Primary from HTML
  static const Color secondary = Color(0xFF4A8EFF); // Electric Blue
  static const Color tertiary = Color(0xFF4AE183); // Success Green
  static const Color error = Color(0xFFFFB4AB);

  static const Color onBackground = Color(0xFFE5E2E1);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFDDC1AE);
  static const Color onPrimary = Color(0xFF4D2600);
  static const Color outline = Color(0xFFA48C7A);

  // Shapes
  static const double radiusSmall = 4.0;
  static const double radiusDefault = 8.0;
  static const double radiusLarge = 16.0;

  // Typography
  static TextStyle get displayLarge => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.02 * 40,
        height: 48 / 40,
        color: onBackground,
      );

  static TextStyle get headlineLarge => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 34 / 28,
        color: onBackground,
      );

  static TextStyle get headlineMedium => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 28 / 22,
        color: onBackground,
      );

  static TextStyle get bodyLarge => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 26 / 18,
        color: onBackground,
      );

  static TextStyle get bodyMedium => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: onBackground,
      );

  static TextStyle get labelBold => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 20 / 14,
        color: onBackground,
      );

  static TextStyle get labelLarge => labelBold;

  /// Returns the complete ThemeData for the application
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        tertiary: tertiary,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        background: background,
        onBackground: onBackground,
        outline: outline,
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
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          side: BorderSide(color: outline.withOpacity(0.2), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: primary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
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
          textStyle: labelBold.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: Colors.grey[700],
        thumbColor: primary,
        overlayColor: primary.withOpacity(0.2),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, pressedElevation: 8),
        trackHeight: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: secondary, width: 2),
        ),
        hintStyle: bodyLarge.copyWith(color: onSurfaceVariant.withOpacity(0.5)),
        prefixIconColor: secondary,
      ),
    );
  }
}
