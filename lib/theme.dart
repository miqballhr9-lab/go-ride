import 'package:flutter/material.dart';

/// MIK ke rang (MIK LEDGER ke logo se): navy, hara, peela, laal.
class AppColors {
  static const brand = Color(0xFF43B649); // MIK green
  static const dark = Color(0xFF1E3A5F); // MIK navy
  static const ink = Color(0xFF1C272C);
  static const surface = Color(0xFFEEF1F2);
  static const muted = Color(0xFF5D6B72);
  static const warning = Color(0xFFF5BD4F); // MIK yellow
  static const danger = Color(0xFFD94141); // MIK red
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.dark,
    primary: AppColors.dark,
    secondary: AppColors.brand,
    error: AppColors.danger,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.dark,
      elevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      // Navy button, safed likhai: parhne mein saaf.
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.dark,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.dark,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    // Chips, switch aur progress bhi logo ke rangon mein.
    chipTheme: ChipThemeData(
      selectedColor: AppColors.brand.withValues(alpha: 0.3),
      checkmarkColor: AppColors.dark,
      side: const BorderSide(color: Color(0xFFC9D2D6)),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.brand : AppColors.surface),
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.muted),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.dark),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );
}
