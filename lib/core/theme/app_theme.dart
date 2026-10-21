import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// ThemeData light & dark — PRD §4.7, design-system.md §11.
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.warmIvory,
        colorScheme: const ColorScheme.light(
          primary: AppColors.deepTeal,
          onPrimary: AppColors.white,
          secondary: AppColors.oceanTeal,
          onSecondary: AppColors.white,
          tertiary: AppColors.softApricot,
          surface: AppColors.white,
          onSurface: AppColors.ink,
          error: AppColors.error,
          onError: AppColors.white,
          outline: AppColors.borderNeutral,
        ),
        textTheme: GoogleFonts.dmSansTextTheme().apply(
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.warmIvory,
          foregroundColor: AppColors.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.m,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            borderSide: const BorderSide(color: AppColors.borderNeutral),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            borderSide: const BorderSide(color: AppColors.borderNeutral),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            borderSide:
                const BorderSide(color: AppColors.deepTeal, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
        ),
        dividerColor: AppColors.borderNeutral,
        splashFactory: InkSparkle.splashFactory,
      );

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgDark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryDark,
          onPrimary: AppColors.white,
          secondary: AppColors.oceanTeal,
          onSecondary: AppColors.white,
          tertiary: AppColors.softApricot,
          surface: AppColors.surfaceDark,
          onSurface: AppColors.inkDark,
          error: AppColors.error,
          onError: AppColors.white,
          outline: AppColors.borderDark,
        ),
        textTheme: GoogleFonts.dmSansTextTheme(
          ThemeData.dark().textTheme,
        ).apply(
          bodyColor: AppColors.inkDark,
          displayColor: AppColors.inkDark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bgDark,
          foregroundColor: AppColors.inkDark,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceDark,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.m,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            borderSide: const BorderSide(color: AppColors.borderDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            borderSide: const BorderSide(color: AppColors.borderDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            borderSide:
                const BorderSide(color: AppColors.primaryDark, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
        ),
        dividerColor: AppColors.borderDark,
        splashFactory: InkSparkle.splashFactory,
      );
}
