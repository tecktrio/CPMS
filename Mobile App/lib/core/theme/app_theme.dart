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
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
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
          side: const BorderSide(color: Color(0xFFE5E5E5)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(
          color: Color(0xFFCBD5E1),
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

