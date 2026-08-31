import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- Classic Minimalist Palette ---
  // 1. Cream (Backgrounds & Soft Surfaces)
  static const Color cream = Color(0xFFFAF7F0);
  static const Color creamBg = Color(0xFFFAF7F0);
  static const Color creamSurface = Color(0xFFFFFDF9);
  static const Color creamCard = Colors.white;
  static const Color creamBorder = Color(0xFFE8E2D4);

  // 2. Sea Green (Primary Brand & Positive Accents)
  static const Color seaGreen = Color(0xFF0D7A68);
  static const Color seaGreenLight = Color(0xFF14B8A6);
  static const Color seaGreenDark = Color(0xFF095246);
  static const Color seaGreenTint = Color(0xFFE6F4F1);

  // 3. Charcoal (Typography, Outlines & Neutral Accents)
  static const Color charcoal = Color(0xFF1C1E21);
  static const Color charcoalMuted = Color(0xFF555B66);
  static const Color charcoalLight = Color(0xFF8A92A0);
  static const Color charcoalBorder = Color(0xFFD1D5DB);
  static const Color charcoalSurface = Color(0xFF2D3139);

  // Status & Warning Accents
  static const Color statusSafe = Color(0xFF0D7A68);     // Sea Green
  static const Color statusWarning = Color(0xFFD97706);  // Warm Amber
  static const Color statusDanger = Color(0xFFDC2626);   // Crimson

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: creamBg,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: seaGreen,
        onPrimary: Colors.white,
        secondary: charcoal,
        onSecondary: Colors.white,
        error: statusDanger,
        onError: Colors.white,
        surface: creamSurface,
        onSurface: charcoal,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: charcoal, letterSpacing: -0.5),
        titleLarge: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: charcoal, letterSpacing: -0.3),
        titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: charcoal),
        bodyLarge: GoogleFonts.inter(fontSize: 15, color: charcoal),
        bodyMedium: GoogleFonts.inter(fontSize: 13, color: charcoalMuted),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: creamBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: charcoal),
        titleTextStyle: TextStyle(
          color: charcoal,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: creamCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: creamBorder, width: 1.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seaGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: charcoal,
          side: const BorderSide(color: charcoalBorder, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: creamCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        labelStyle: const TextStyle(color: charcoalMuted, fontSize: 14),
        hintStyle: const TextStyle(color: charcoalLight, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: creamBorder, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: creamBorder, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: seaGreen, width: 1.6),
        ),
      ),
    );
  }
}
