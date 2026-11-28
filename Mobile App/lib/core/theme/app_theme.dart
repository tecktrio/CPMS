import 'package:flutter/material.dart';

class AppTheme {
  // Brand Dark Green & Emerald palette
  static const Color darkGreen = Color(0xFF14532D);        // Rich, elegant dark green (buttons, active states)
  static const Color brandGreen = Color(0xFF15803D);       // Medium dark green
  static const Color brandGreenDark = Color(0xFF14532D);   // Primary dark green
  static const Color brandGreenLight = Color(0xFF22C55E);  // Vibrant emerald green
  static const Color brandGreenBg = Color(0xFFF0FDF4);     // Soft pastel green background
  static const Color brandGreenBorder = Color(0xFFBBF7D0); // Subtle green border

  // Legacy compatibility aliases
  static const Color primaryTeal = Color(0xFF14532D);
  static const Color primaryLight = Color(0xFF15803D);
  static const Color accentGreen = Color(0xFF15803D);
  static const Color accentCyan = Color(0xFF15803D);
  static const Color coldBlue = Color(0xFF0284C7);
  static const Color coldSurface = Color(0xFFF0FDF4);
  static const Color alertAmber = Color(0xFFD97706);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color successGreen = Color(0xFF15803D);

  static const Color workspaceCanvas = Color(0xFFF5F8F6);
  static const Color workspaceBorder = Color(0xFFDFE8E2);

  static const Color adminCanvas = Color(0xFFF2F6F5);
  static const Color adminInk = Color(0xFF163E37);
  static const Color adminTint = Color(0xFFDAE8E2);
  static const Color adminPeople = Color(0xFF6844B3);
  static const Color adminPeopleTint = Color(0xFFEFE9F8);

  static const Color adminStorage = Color(0xFF057B67);
  static const Color adminStorageTint = Color(0xFFE3F3EE);
  static const Color adminItems = Color(0xFF2264AA);
  static const Color adminItemsTint = Color(0xFFE7F0FA);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkGreen,
        primary: darkGreen,
        secondary: brandGreen,
        surface: Colors.white,
        error: dangerRed,
      ),
      scaffoldBackgroundColor: workspaceCanvas,
      dividerTheme: const DividerThemeData(color: workspaceBorder, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        constraints: const BoxConstraints(maxWidth: 520),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF182921),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: StadiumBorder(), // Oval / Pill shaped
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: workspaceBorder),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(
          color: Color(0xFF68766E),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: Color(0xFF0F172A), width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: dangerRed),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(), // Fully oval / stadium pill shape
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkGreen,
          side: const BorderSide(color: darkGreen, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          shape: const StadiumBorder(), // Fully oval / stadium pill shape
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

