import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fruit-Safe market palette.
class AppColors {
  const AppColors._();

  static const Color harvestPureGreen = Color(0xFF025E37);
  static const Color nAtlasAmber = Color(0xFFD97706);
  static const Color eNoseCyan = Color(0xFF0891B2);
  static const Color darkSlate = Color(0xFF0F172A);
  static const Color marketStone = Color(0xFFF8FAFC);
  static const Color statusVerdant = Color(0xFF059669);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusDanger = Color(0xFFDC2626);

  static Color forStatus(String status) {
    switch (status) {
      case 'Safe':
        return statusVerdant;
      case 'Warning':
        return statusWarning;
      case 'Danger':
        return statusDanger;
      default:
        return darkSlate;
    }
  }
}

class AppTheme {
  const AppTheme._();

  static const double minTouchTarget = 56;

  static ThemeData light() {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.harvestPureGreen,
      onPrimary: Colors.white,
      secondary: AppColors.nAtlasAmber,
      onSecondary: Colors.white,
      tertiary: AppColors.eNoseCyan,
      onTertiary: Colors.white,
      error: AppColors.statusDanger,
      onError: Colors.white,
      surface: AppColors.marketStone,
      onSurface: AppColors.darkSlate,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme().apply(
      bodyColor: AppColors.darkSlate,
      displayColor: AppColors.darkSlate,
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.marketStone,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.harvestPureGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(minTouchTarget),
          tapTargetSize: MaterialTapTargetSize.padded,
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(minTouchTarget),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        labelStyle: textTheme.labelLarge,
        side: BorderSide(color: AppColors.harvestPureGreen.withValues(alpha: 0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.darkSlate.withValues(alpha: 0.08)),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.harvestPureGreen,
        thumbColor: AppColors.harvestPureGreen,
        inactiveTrackColor: Color(0xFFD1D5DB),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.harvestPureGreen;
          }
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.harvestPureGreen.withValues(alpha: 0.45);
          }
          return const Color(0xFFCBD5E1);
        }),
      ),
    );
  }
}
