import 'package:flutter/material.dart';

/// FloraX Daylight Kisan Accessible Color Tokens & Theme Extension
@immutable
class FloraXColors extends ThemeExtension<FloraXColors> {
  // Canvas & Surfaces
  final Color canvas;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color surfaceBright;

  // Borders & Outlines
  final Color borderDim;
  final Color borderHigh;
  final Color outline;
  final Color outlineVariant;

  // Bio-Agritech Pathology Roles
  final Color primaryGreen;
  final Color onPrimaryGreen;
  final Color primaryContainer;
  final Color bioCyan;
  final Color onBioCyan;
  final Color secondaryContainer;
  final Color amberCaution;
  final Color onAmberCaution;
  final Color crimsonAlert;
  final Color onCrimsonAlert;

  // Traffic Light Semantic Banners
  final Color bannerHealthyBg;
  final Color bannerHealthyText;
  final Color bannerCautionBg;
  final Color bannerCautionText;
  final Color bannerDangerBg;
  final Color bannerDangerText;

  // Text Hierarchy
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  const FloraXColors({
    required this.canvas,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.surfaceBright,
    required this.borderDim,
    required this.borderHigh,
    required this.outline,
    required this.outlineVariant,
    required this.primaryGreen,
    required this.onPrimaryGreen,
    required this.primaryContainer,
    required this.bioCyan,
    required this.onBioCyan,
    required this.secondaryContainer,
    required this.amberCaution,
    required this.onAmberCaution,
    required this.crimsonAlert,
    required this.onCrimsonAlert,
    required this.bannerHealthyBg,
    required this.bannerHealthyText,
    required this.bannerCautionBg,
    required this.bannerCautionText,
    required this.bannerDangerBg,
    required this.bannerDangerText,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  /// Daylight Kisan Design Token Values (Default accessible farmer palette)
  static const FloraXColors daylightKisan = FloraXColors(
    canvas: Color(0xFFF6F8F4), // Warm crisp off-white
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFAFCF8),
    surfaceContainer: Color(0xFFFFFFFF), // Pure white
    surfaceContainerHigh: Color(0xFFEDF2EA),
    surfaceContainerHighest: Color(0xFFE2E9DE),
    surfaceBright: Color(0xFFFFFFFF),
    borderDim: Color(0xFFDCE3D8), // Subtle 1.5px border
    borderHigh: Color(0xFFCBD5E1),
    outline: Color(0xFF6B7280),
    outlineVariant: Color(0xFFDCE3D8),
    primaryGreen: Color(0xFF146C38), // Deep Forest (>6:1 contrast)
    onPrimaryGreen: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDCFCE7),
    bioCyan: Color(0xFF0369A1),
    onBioCyan: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE0F2FE),
    amberCaution: Color(0xFFB45309), // Accessible Caution Amber
    onAmberCaution: Color(0xFFFFFFFF),
    crimsonAlert: Color(0xFFB91C1C), // Accessible Danger Crimson
    onCrimsonAlert: Color(0xFFFFFFFF),
    bannerHealthyBg: Color(0xFFDCFCE7),
    bannerHealthyText: Color(0xFF15803D),
    bannerCautionBg: Color(0xFFFEF3C7),
    bannerCautionText: Color(0xFFB45309),
    bannerDangerBg: Color(0xFFFEE2E2),
    bannerDangerText: Color(0xFFB91C1C),
    textPrimary: Color(0xFF111827), // Near-black for bright sunlight legibility
    textSecondary: Color(0xFF4B5563),
    textMuted: Color(0xFF6B7280),
  );

  @override
  FloraXColors copyWith({
    Color? canvas,
    Color? surfaceContainerLowest,
    Color? surfaceContainerLow,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? surfaceContainerHighest,
    Color? surfaceBright,
    Color? borderDim,
    Color? borderHigh,
    Color? outline,
    Color? outlineVariant,
    Color? primaryGreen,
    Color? onPrimaryGreen,
    Color? primaryContainer,
    Color? bioCyan,
    Color? onBioCyan,
    Color? secondaryContainer,
    Color? amberCaution,
    Color? onAmberCaution,
    Color? crimsonAlert,
    Color? onCrimsonAlert,
    Color? bannerHealthyBg,
    Color? bannerHealthyText,
    Color? bannerCautionBg,
    Color? bannerCautionText,
    Color? bannerDangerBg,
    Color? bannerDangerText,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
  }) {
    return FloraXColors(
      canvas: canvas ?? this.canvas,
      surfaceContainerLowest: surfaceContainerLowest ?? this.surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest ?? this.surfaceContainerHighest,
      surfaceBright: surfaceBright ?? this.surfaceBright,
      borderDim: borderDim ?? this.borderDim,
      borderHigh: borderHigh ?? this.borderHigh,
      outline: outline ?? this.outline,
      outlineVariant: outlineVariant ?? this.outlineVariant,
      primaryGreen: primaryGreen ?? this.primaryGreen,
      onPrimaryGreen: onPrimaryGreen ?? this.onPrimaryGreen,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      bioCyan: bioCyan ?? this.bioCyan,
      onBioCyan: onBioCyan ?? this.onBioCyan,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      amberCaution: amberCaution ?? this.amberCaution,
      onAmberCaution: onAmberCaution ?? this.onAmberCaution,
      crimsonAlert: crimsonAlert ?? this.crimsonAlert,
      onCrimsonAlert: onCrimsonAlert ?? this.onCrimsonAlert,
      bannerHealthyBg: bannerHealthyBg ?? this.bannerHealthyBg,
      bannerHealthyText: bannerHealthyText ?? this.bannerHealthyText,
      bannerCautionBg: bannerCautionBg ?? this.bannerCautionBg,
      bannerCautionText: bannerCautionText ?? this.bannerCautionText,
      bannerDangerBg: bannerDangerBg ?? this.bannerDangerBg,
      bannerDangerText: bannerDangerText ?? this.bannerDangerText,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  FloraXColors lerp(ThemeExtension<FloraXColors>? other, double t) {
    if (other is! FloraXColors) return this;
    return FloraXColors(
      canvas: Color.lerp(canvas, other.canvas, t) ?? canvas,
      surfaceContainerLowest: Color.lerp(surfaceContainerLowest, other.surfaceContainerLowest, t) ?? surfaceContainerLowest,
      surfaceContainerLow: Color.lerp(surfaceContainerLow, other.surfaceContainerLow, t) ?? surfaceContainerLow,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t) ?? surfaceContainer,
      surfaceContainerHigh: Color.lerp(surfaceContainerHigh, other.surfaceContainerHigh, t) ?? surfaceContainerHigh,
      surfaceContainerHighest: Color.lerp(surfaceContainerHighest, other.surfaceContainerHighest, t) ?? surfaceContainerHighest,
      surfaceBright: Color.lerp(surfaceBright, other.surfaceBright, t) ?? surfaceBright,
      borderDim: Color.lerp(borderDim, other.borderDim, t) ?? borderDim,
      borderHigh: Color.lerp(borderHigh, other.borderHigh, t) ?? borderHigh,
      outline: Color.lerp(outline, other.outline, t) ?? outline,
      outlineVariant: Color.lerp(outlineVariant, other.outlineVariant, t) ?? outlineVariant,
      primaryGreen: Color.lerp(primaryGreen, other.primaryGreen, t) ?? primaryGreen,
      onPrimaryGreen: Color.lerp(onPrimaryGreen, other.onPrimaryGreen, t) ?? onPrimaryGreen,
      primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t) ?? primaryContainer,
      bioCyan: Color.lerp(bioCyan, other.bioCyan, t) ?? bioCyan,
      onBioCyan: Color.lerp(onBioCyan, other.onBioCyan, t) ?? onBioCyan,
      secondaryContainer: Color.lerp(secondaryContainer, other.secondaryContainer, t) ?? secondaryContainer,
      amberCaution: Color.lerp(amberCaution, other.amberCaution, t) ?? amberCaution,
      onAmberCaution: Color.lerp(onAmberCaution, other.onAmberCaution, t) ?? onAmberCaution,
      crimsonAlert: Color.lerp(crimsonAlert, other.crimsonAlert, t) ?? crimsonAlert,
      onCrimsonAlert: Color.lerp(onCrimsonAlert, other.onCrimsonAlert, t) ?? onCrimsonAlert,
      bannerHealthyBg: Color.lerp(bannerHealthyBg, other.bannerHealthyBg, t) ?? bannerHealthyBg,
      bannerHealthyText: Color.lerp(bannerHealthyText, other.bannerHealthyText, t) ?? bannerHealthyText,
      bannerCautionBg: Color.lerp(bannerCautionBg, other.bannerCautionBg, t) ?? bannerCautionBg,
      bannerCautionText: Color.lerp(bannerCautionText, other.bannerCautionText, t) ?? bannerCautionText,
      bannerDangerBg: Color.lerp(bannerDangerBg, other.bannerDangerBg, t) ?? bannerDangerBg,
      bannerDangerText: Color.lerp(bannerDangerText, other.bannerDangerText, t) ?? bannerDangerText,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
    );
  }
}

/// Centralized FloraX Design System Theme Definitions
class FloraXTheme {
  // Daylight-First Outdoor Accessible Constants
  static const Color background = Color(0xFFF6F8F4); // Warm crisp off-white
  static const Color canvas = Color(0xFFF6F8F4);
  static const Color cardSurface = Color(0xFFFFFFFF); // Pure white card
  static const Color cardSurfaceLighter = Color(0xFFF0F4EE);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFAFCF8);
  static const Color surfaceContainer = Color(0xFFFFFFFF);
  static const Color surfaceContainerHigh = Color(0xFFEDF2EA);
  static const Color surfaceContainerHighest = Color(0xFFE2E9DE);

  // Deep Forest Green Action Color (>6:1 contrast with white)
  static const Color neonGreen = Color(0xFF146C38);
  static const Color primaryGreen = Color(0xFF146C38);

  // Semantic Alert Colors
  static const Color amberCaution = Color(0xFFB45309);
  static const Color crimsonAlert = Color(0xFFB91C1C);
  static const Color bioCyan = Color(0xFF0369A1);

  // Traffic Light Banner Presets (Color + Icon + Text)
  static const Color bannerHealthyBg = Color(0xFFDCFCE7);
  static const Color bannerHealthyText = Color(0xFF15803D);
  static const Color bannerCautionBg = Color(0xFFFEF3C7);
  static const Color bannerCautionText = Color(0xFFB45309);
  static const Color bannerDangerBg = Color(0xFFFEE2E2);
  static const Color bannerDangerText = Color(0xFFB91C1C);

  // Text Hierarchy (Near-Black for Outdoor Sunlight Visibility)
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF6B7280);

  // Outlines & Borders
  static const Color borderGreen = Color(0xFF146C38);
  static const Color borderDim = Color(0xFFDCE3D8); // 1.5px subtle border
  static const Color borderHigh = Color(0xFFCBD5E1);

  // Border Radii
  static const double radiusSm = 6.0;
  static const double radiusMd = 10.0;
  static const double radiusLg = 14.0;
  static const double radiusXl = 18.0;
  static const double radius2Xl = 24.0;
  static const double radiusFull = 9999.0;

  // Spacing Tokens
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;

  /// Typography scale with tabular numerals support
  static TextStyle tabularMetric({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textPrimary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: -0.01,
    );
  }

  /// Master Daylight Kisan Theme (Material 3)
  static ThemeData get daylightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      primaryColor: primaryGreen,
      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFDCFCE7),
        onPrimaryContainer: Color(0xFF146C38),
        secondary: bioCyan,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFE0F2FE),
        onSecondaryContainer: Color(0xFF0369A1),
        tertiary: amberCaution,
        onTertiary: Colors.white,
        error: crimsonAlert,
        onError: Colors.white,
        surface: cardSurface,
        onSurface: textPrimary,
        outline: borderHigh,
        outlineVariant: borderDim,
      ),
      extensions: const [FloraXColors.daylightKisan],
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: const BorderSide(color: borderDim, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderDim,
        thickness: 1.2,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: textMuted, fontSize: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: borderDim, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: borderDim, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: primaryGreen, width: 2.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(56, 56), // Minimum 56dp for farmer touch targets
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          minimumSize: const Size(56, 56),
          side: const BorderSide(color: borderDim, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  /// Backward-compatibility alias pointing to the default Daylight theme
  static ThemeData get darkTheme => daylightTheme;
}

/// Shorthand context extension for FloraX custom color access
extension FloraXThemeContext on BuildContext {
  FloraXColors get floraXColors =>
      Theme.of(this).extension<FloraXColors>() ?? FloraXColors.daylightKisan;
}
