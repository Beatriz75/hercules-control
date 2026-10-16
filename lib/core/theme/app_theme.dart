import 'package:flutter/material.dart';

/// Brand palette "Fuerza y control".
abstract final class BrandColors {
  static const navy = Color(0xFF0E2A47);
  static const navyDeep = Color(0xFF081B30);
  static const navyLight = Color(0xFF173A5B);
  static const gold = Color(0xFFC9A227);
  static const goldLight = Color(0xFFE3C15A);
  static const signalBlue = Color(0xFF2897FF);
  static const background = Color(0xFFF3F6FA);
  static const border = Color(0xFFD9E2EC);
  static const error = Color(0xFFC0392B);
  static const success = Color(0xFF1E8E5A);
  static const warning = Color(0xFFD98E04);

  /// Muted text on navy surfaces.
  static const onNavyMuted = Color(0xFFB9C7D5);
}

class AppTheme {
  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: BrandColors.navy,
          brightness: Brightness.light,
        ).copyWith(
          primary: BrandColors.navy,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFDCE6F2),
          onPrimaryContainer: BrandColors.navyDeep,
          secondary: BrandColors.gold,
          onSecondary: BrandColors.navy,
          secondaryContainer: const Color(0xFFF6EBC8),
          onSecondaryContainer: BrandColors.navyDeep,
          tertiary: BrandColors.signalBlue,
          onTertiary: Colors.white,
          surface: Colors.white,
          onSurface: BrandColors.navyDeep,
          outline: const Color(0xFF9AAABB),
          outlineVariant: BrandColors.border,
          error: BrandColors.error,
          onError: Colors.white,
        );

    final roundedField = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: BrandColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: BrandColors.background,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w800,
          color: BrandColors.navy,
        ),
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w700,
          color: BrandColors.navy,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w700,
          color: BrandColors.navy,
        ),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: BrandColors.navy,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: BrandColors.border),
        ),
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: BrandColors.border),
      // Primary CTAs: gold with navy text (readable contrast).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BrandColors.gold,
          foregroundColor: BrandColors.navy,
          disabledBackgroundColor: BrandColors.border,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandColors.navy,
          side: const BorderSide(color: BrandColors.border),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: BrandColors.signalBlue),
      ),
      chipTheme: ChipThemeData(
        selectedColor: BrandColors.goldLight.withValues(alpha: 0.45),
        side: const BorderSide(color: BrandColors.border),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? BrandColors.goldLight.withValues(alpha: 0.45)
                : Colors.white,
          ),
          foregroundColor: const WidgetStatePropertyAll(BrandColors.navy),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BrandColors.navy,
        linearTrackColor: BrandColors.border,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: BrandColors.navyDeep,
        contentTextStyle: TextStyle(color: Colors.white),
        actionTextColor: BrandColors.goldLight,
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: roundedField,
        enabledBorder: roundedField,
        focusedBorder: roundedField.copyWith(
          borderSide: const BorderSide(
            color: BrandColors.signalBlue,
            width: 1.6,
          ),
        ),
        errorBorder: roundedField.copyWith(
          borderSide: const BorderSide(color: BrandColors.error),
        ),
        focusedErrorBorder: roundedField.copyWith(
          borderSide: const BorderSide(color: BrandColors.error, width: 1.6),
        ),
      ),
    );
  }
}
