import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const brandStart = Color(0xFF2948DF);
  static const brandEnd = Color(0xFF9C39F3);
  static const pageBackground = Color(0xFFF5F1FF);
  static const brandText = Color(0xFF27213E);
  static const mutedText = Color(0xFF8D7281);
  static const success = Color(0xFF26B36C);
  static const danger = Color(0xFFE66868);

  static ThemeData get lightTheme {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: brandStart,
      brightness: Brightness.light,
    );
    final colorScheme = baseScheme.copyWith(
      primary: brandStart,
      secondary: brandEnd,
      surface: Colors.white,
      onSurface: brandText,
      onSurfaceVariant: const Color(0xFF7B7890),
      outline: const Color(0xFFE6DDF8),
      outlineVariant: const Color(0xFFF0EAFB),
      error: danger,
      onError: Colors.white,
      shadow: const Color(0x1F2A1B6A),
      scrim: const Color(0x1F2A1B6A),
    );

    final textTheme = Typography.material2021(
      colorScheme: colorScheme,
    ).black.apply(bodyColor: brandText, displayColor: brandText);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: pageBackground,
      textTheme: textTheme.copyWith(
        displaySmall: textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium: textTheme.titleMedium?.copyWith(
          color: mutedText,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: mutedText,
          height: 1.45,
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: brandText,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shadowColor: colorScheme.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFF0EAFB)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          backgroundColor: brandStart,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFAF7FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE6DDF8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE6DDF8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: brandStart, width: 1.4),
        ),
      ),
      extensions: const [
        CarebitColors(
          pageBackground: pageBackground,
          brandText: brandText,
          mutedText: mutedText,
          gradientStart: brandStart,
          gradientEnd: brandEnd,
          success: success,
          danger: danger,
          navInactive: Color(0xFF23212F),
          softPurple: Color(0xFFF6EEFF),
          softBlue: Color(0xFFE7ECFF),
          softGreen: Color(0xFFEFFFF8),
          softPink: Color(0xFFFFEFF2),
          softOrange: Color(0xFFFFF2E8),
          anomalyBackground: Color(0xFFFFF5F5),
          anomalyBorder: Color(0xFFF6D7D7),
          anomalyText: Color(0xFF5B3040),
          surfaceBorder: Color(0xFFF0EAFB),
          summaryLabel: Color(0xFF9A98A8),
          summaryValue: Color(0xFF28224A),
          vitalValueMuted: Color(0xFFB0AEBB),
          warningBackground: Color(0xFFFFF0C4),
          warningForeground: Color(0xFFF4B400),
          heartIcon: Color(0xFFE15772),
          oxygenIcon: Color(0xFF25A56A),
          burnIcon: Color(0xFFFF8A3D),
          stepsIcon: Color(0xFF4E7BEF),
          sleepIcon: Color(0xFF8A5CFF),
        ),
      ],
    );
  }
}

@immutable
class CarebitColors extends ThemeExtension<CarebitColors> {
  const CarebitColors({
    required this.pageBackground,
    required this.brandText,
    required this.mutedText,
    required this.gradientStart,
    required this.gradientEnd,
    required this.success,
    required this.danger,
    required this.navInactive,
    required this.softPurple,
    required this.softBlue,
    required this.softGreen,
    required this.softPink,
    required this.softOrange,
    required this.anomalyBackground,
    required this.anomalyBorder,
    required this.anomalyText,
    required this.surfaceBorder,
    required this.summaryLabel,
    required this.summaryValue,
    required this.vitalValueMuted,
    required this.warningBackground,
    required this.warningForeground,
    required this.heartIcon,
    required this.oxygenIcon,
    required this.burnIcon,
    required this.stepsIcon,
    required this.sleepIcon,
  });

  final Color pageBackground;
  final Color brandText;
  final Color mutedText;
  final Color gradientStart;
  final Color gradientEnd;
  final Color success;
  final Color danger;
  final Color navInactive;
  final Color softPurple;
  final Color softBlue;
  final Color softGreen;
  final Color softPink;
  final Color softOrange;
  final Color anomalyBackground;
  final Color anomalyBorder;
  final Color anomalyText;
  final Color surfaceBorder;
  final Color summaryLabel;
  final Color summaryValue;
  final Color vitalValueMuted;
  final Color warningBackground;
  final Color warningForeground;
  final Color heartIcon;
  final Color oxygenIcon;
  final Color burnIcon;
  final Color stepsIcon;
  final Color sleepIcon;

  @override
  CarebitColors copyWith({
    Color? pageBackground,
    Color? brandText,
    Color? mutedText,
    Color? gradientStart,
    Color? gradientEnd,
    Color? success,
    Color? danger,
    Color? navInactive,
    Color? softPurple,
    Color? softBlue,
    Color? softGreen,
    Color? softPink,
    Color? softOrange,
    Color? anomalyBackground,
    Color? anomalyBorder,
    Color? anomalyText,
    Color? surfaceBorder,
    Color? summaryLabel,
    Color? summaryValue,
    Color? vitalValueMuted,
    Color? warningBackground,
    Color? warningForeground,
    Color? heartIcon,
    Color? oxygenIcon,
    Color? burnIcon,
    Color? stepsIcon,
    Color? sleepIcon,
  }) {
    return CarebitColors(
      pageBackground: pageBackground ?? this.pageBackground,
      brandText: brandText ?? this.brandText,
      mutedText: mutedText ?? this.mutedText,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      navInactive: navInactive ?? this.navInactive,
      softPurple: softPurple ?? this.softPurple,
      softBlue: softBlue ?? this.softBlue,
      softGreen: softGreen ?? this.softGreen,
      softPink: softPink ?? this.softPink,
      softOrange: softOrange ?? this.softOrange,
      anomalyBackground: anomalyBackground ?? this.anomalyBackground,
      anomalyBorder: anomalyBorder ?? this.anomalyBorder,
      anomalyText: anomalyText ?? this.anomalyText,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      summaryLabel: summaryLabel ?? this.summaryLabel,
      summaryValue: summaryValue ?? this.summaryValue,
      vitalValueMuted: vitalValueMuted ?? this.vitalValueMuted,
      warningBackground: warningBackground ?? this.warningBackground,
      warningForeground: warningForeground ?? this.warningForeground,
      heartIcon: heartIcon ?? this.heartIcon,
      oxygenIcon: oxygenIcon ?? this.oxygenIcon,
      burnIcon: burnIcon ?? this.burnIcon,
      stepsIcon: stepsIcon ?? this.stepsIcon,
      sleepIcon: sleepIcon ?? this.sleepIcon,
    );
  }

  @override
  CarebitColors lerp(ThemeExtension<CarebitColors>? other, double t) {
    if (other is! CarebitColors) {
      return this;
    }

    return CarebitColors(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      brandText: Color.lerp(brandText, other.brandText, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      navInactive: Color.lerp(navInactive, other.navInactive, t)!,
      softPurple: Color.lerp(softPurple, other.softPurple, t)!,
      softBlue: Color.lerp(softBlue, other.softBlue, t)!,
      softGreen: Color.lerp(softGreen, other.softGreen, t)!,
      softPink: Color.lerp(softPink, other.softPink, t)!,
      softOrange: Color.lerp(softOrange, other.softOrange, t)!,
      anomalyBackground: Color.lerp(
        anomalyBackground,
        other.anomalyBackground,
        t,
      )!,
      anomalyBorder: Color.lerp(anomalyBorder, other.anomalyBorder, t)!,
      anomalyText: Color.lerp(anomalyText, other.anomalyText, t)!,
      surfaceBorder: Color.lerp(surfaceBorder, other.surfaceBorder, t)!,
      summaryLabel: Color.lerp(summaryLabel, other.summaryLabel, t)!,
      summaryValue: Color.lerp(summaryValue, other.summaryValue, t)!,
      vitalValueMuted: Color.lerp(vitalValueMuted, other.vitalValueMuted, t)!,
      warningBackground: Color.lerp(
        warningBackground,
        other.warningBackground,
        t,
      )!,
      warningForeground: Color.lerp(
        warningForeground,
        other.warningForeground,
        t,
      )!,
      heartIcon: Color.lerp(heartIcon, other.heartIcon, t)!,
      oxygenIcon: Color.lerp(oxygenIcon, other.oxygenIcon, t)!,
      burnIcon: Color.lerp(burnIcon, other.burnIcon, t)!,
      stepsIcon: Color.lerp(stepsIcon, other.stepsIcon, t)!,
      sleepIcon: Color.lerp(sleepIcon, other.sleepIcon, t)!,
    );
  }
}

extension CarebitThemeContext on BuildContext {
  CarebitColors get carebitColors => Theme.of(this).extension<CarebitColors>()!;
}
