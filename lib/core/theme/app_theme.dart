import 'package:flutter/material.dart';

/// Centralized Design System Tokens for KisanSetu
/// Extracted from `_stitch_incoming/agrisage_organics/DESIGN.md` & visual specifications.
class AppTheme {
  AppTheme._();

  // ===========================================================================
  // 1. PRIMARY & BRAND COLOR TOKENS
  // ===========================================================================

  /// Deep Forest Green (Primary Brand & High-Contrast Typography)
  static const Color forestGreen = Color(0xFF155724);
  static const Color primaryGreen = Color(0xFF166534);
  static const Color deepForest = Color(0xFF214623);
  static const Color primaryAction = Color(0xFF385E38);

  /// Vibrant Botanical Foliage Green
  static const Color leafGreen = Color(0xFF4CAF50);
  static const Color surfaceTint = Color(0xFF416740);

  /// Secondary & Accent Herb/Pistachio Tones
  static const Color pistachioContainer = Color(0xFFD2EAC3);
  static const Color pistachioPill = Color(0xFFCBE2BC);
  static const Color onSecondaryContainer = Color(0xFF566A4B);
  static const Color secondary = Color(0xFF3E6439);

  /// Agronomic Clinical Alert Tokens
  static const Color alertRed = Color(0xFFDC2626);
  static const Color errorRed = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color harvestGold = Color(0xFFF59E0B);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color onWarningContainer = Color(0xFF92400E);

  static const Color abioticTeal = Color(0xFF0D9488);
  static const Color abioticContainer = Color(0xFFCCFBF1);
  static const Color onAbioticContainer = Color(0xFF115E59);

  // ===========================================================================
  // 2. CLEAN LIGHT-NEUTRAL SURFACES (Daylight Kisan Outdoor Ergonomics)
  // ===========================================================================

  /// Foundational ambient canvas tint (soft sage/mint wash, replacing harsh whites)
  static const Color background = Color(0xFFF2FCEE);
  static const Color neutralCanvas = Color(0xFFEBF5E7);

  /// Surface containers
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEDF7E8);
  static const Color surfaceContainer = Color(0xFFE7F1E3);
  static const Color surfaceContainerHigh = Color(0xFFE1EBDD);
  static const Color surfaceContainerHighest = Color(0xFFDBE5D8);

  /// Typography on neutral surfaces
  static const Color onSurface = Color(0xFF151E15);
  static const Color textDarkForest = Color(0xFF1F3624);
  static const Color onSurfaceVariant = Color(0xFF424940);
  static const Color textMuted = Color(0xFF5E735F);

  /// Low-contrast outlines and dividers
  static const Color outline = Color(0xFF72796F);
  static const Color outlineVariant = Color(0xFFC2C8BD);
  static const Color borderDim = Color(0x261F3624);

  // ===========================================================================
  // 3. GEOMETRIC RADII
  // ===========================================================================

  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 9999.0;

  // ===========================================================================
  // 4. SOFT AMBIENT DIFFUSE SHADOWS
  // ===========================================================================

  static const List<BoxShadow> softCardShadow = [
    BoxShadow(
      color: Color(0x0F263E2B),
      blurRadius: 16.0,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> floatingActionShadow = [
    BoxShadow(
      color: Color(0x33214623),
      blurRadius: 20.0,
      offset: Offset(0, 8),
      spreadRadius: -4,
    ),
  ];

  // ===========================================================================
  // 5. PRODUCTION THEMEDATA (Daylight Kisan Theme)
  // ===========================================================================

  static ThemeData get daylightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primaryGreen,
        onPrimary: Colors.white,
        primaryContainer: primaryAction,
        onPrimaryContainer: Color(0xFFABD6A6),
        secondary: secondary,
        onSecondary: Colors.white,
        secondaryContainer: pistachioContainer,
        onSecondaryContainer: onSecondaryContainer,
        error: errorRed,
        onError: Colors.white,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
      ),
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: surface,
      dividerColor: outlineVariant,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: forestGreen),
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -0.5,
          height: 1.25,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -0.3,
          height: 1.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: onSurface,
          height: 1.35,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: onSurface,
          height: 1.35,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: onSurface,
          height: 1.4,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: onSurface,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: onSurfaceVariant,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textMuted,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: onSurfaceVariant,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textMuted,
          letterSpacing: 0.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAction,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textDarkForest,
          minimumSize: const Size(64, 44),
          side: const BorderSide(color: borderDim, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        hintStyle: const TextStyle(
          color: outline,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: alertRed, width: 1.2),
        ),
      ),
    );
  }
}
