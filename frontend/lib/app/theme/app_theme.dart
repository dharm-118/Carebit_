import 'package:flutter/material.dart';

/// Semantic color palette used throughout the Carebit UI.
class CarebitColors {
  const CarebitColors._();

  final Color pageBackground = const Color(0xFFF4F1FB);
  final Color gradientStart = const Color(0xFF2F5BFF);
  final Color gradientEnd = const Color(0xFF6F2CFF);
  final Color brandText = const Color(0xFF221B5C);
  final Color mutedText = const Color(0xFF7E7B97);
  final Color summaryValue = const Color(0xFF221B5C);
  final Color summaryLabel = const Color(0xFF7E7B97);
  final Color vitalValueMuted = const Color(0xFF7E7B97);
  final Color navInactive = const Color(0xFF7E7B97);

  // Soft icon backgrounds
  final Color softBlue = const Color(0xFFE3EAFD);
  final Color softPink = const Color(0xFFFDE3EF);
  final Color softGreen = const Color(0xFFE3FDEA);
  final Color softOrange = const Color(0xFFFDF3E3);
  final Color softPurple = const Color(0xFFF0E3FD);

  // Icon foreground colors
  final Color stepsIcon = const Color(0xFF2F5BFF);
  final Color heartIcon = const Color(0xFFE91E63);
  final Color oxygenIcon = const Color(0xFF00BCD4);
  final Color burnIcon = const Color(0xFFFF5722);
  final Color sleepIcon = const Color(0xFF7C4DFF);

  // Status colors
  final Color danger = const Color(0xFFE91E63);
  final Color success = const Color(0xFF4CAF50);

  // Anomaly card
  final Color anomalyBackground = const Color(0xFFFFF8E1);
  final Color anomalyBorder = const Color(0xFFFFB300);
  final Color anomalyText = const Color(0xFF6D4C00);

  // Warning icon
  final Color warningBackground = const Color(0xFFFFECB3);
  final Color warningForeground = const Color(0xFFFF6F00);
}

extension CarebitColorsExtension on BuildContext {
  static const CarebitColors _colors = CarebitColors._();

  CarebitColors get carebitColors => _colors;
}

/// Shared Carebit theme configuration.
///
/// This theme is inspired by the uploaded health dashboard design:
/// - purple/blue brand colors
/// - soft background
/// - rounded cards
/// - modern premium dashboard feel
class AppTheme {
  AppTheme._();

  static const Color primaryPurple = Color(0xFF5B3DF5);
  static const Color deepBlue = Color(0xFF2F5BFF);
  static const Color softBackground = Color(0xFFF4F1FB);
  static const Color darkText = Color(0xFF221B5C);
  static const Color mutedText = Color(0xFF7E7B97);

  static ThemeData get lightTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: primaryPurple,
      brightness: Brightness.light,
      primary: primaryPurple,
      secondary: deepBlue,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: softBackground,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: darkText,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: darkText,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: darkText,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: darkText,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: mutedText,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}