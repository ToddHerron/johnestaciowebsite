import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- COLORS ---
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFDAD9D9);
  static const Color primaryOrange = Color(0xFFFF5E1A);
  static const Color darkGray = Color(0xFF282828);
  static const Color black = Color(0xFF000000);
  // Success color for confirmations / positive feedback
  static const Color successGreen = Color(0xFF2E7D32);
  // Accent used for inline highlight matches in titles
  static const Color highlightYellow = Color(0xFFFFEB3B); // Material Yellow 500

  // --- THEME DATA ---
  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: black,
      
      colorScheme: const ColorScheme.dark(
        primary: primaryOrange,
        secondary: lightGray,
        surface: darkGray,
        onPrimary: black,
        onSecondary: primaryOrange,
        onSurface: white,
        error: Colors.redAccent,
      ),

      cardTheme: const CardThemeData(
        color: darkGray,
        elevation: 0,
        margin: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),

      fontFamily: GoogleFonts.nunitoSans().fontFamily,

      textTheme: TextTheme(
        displayLarge: GoogleFonts.manrope(fontSize: 57, fontWeight: FontWeight.bold, color: primaryOrange),
        displayMedium: GoogleFonts.manrope(fontSize: 45, fontWeight: FontWeight.bold, color: primaryOrange),
        displaySmall: GoogleFonts.manrope(fontSize: 36, fontWeight: FontWeight.bold, color: white),
        headlineLarge: GoogleFonts.manrope(fontSize: 32, fontWeight: FontWeight.bold, color: white),
        headlineMedium: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.bold, color: white),
        headlineSmall: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w600, color: white),
        titleLarge: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w600, color: white),
        bodyLarge: GoogleFonts.nunitoSans(fontSize: 16, fontWeight: FontWeight.normal, color: lightGray),
        bodyMedium: GoogleFonts.nunitoSans(fontSize: 14, fontWeight: FontWeight.normal, color: lightGray),
        bodySmall: GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.normal, color: lightGray),
      ),

      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: darkGray,
        labelStyle: TextStyle(color: primaryOrange),
        hintStyle: TextStyle(color: lightGray),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          borderSide: BorderSide(color: primaryOrange),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          borderSide: BorderSide(color: darkGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          borderSide: BorderSide(color: primaryOrange, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          borderSide: BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          borderSide: BorderSide(color: Colors.redAccent, width: 2.0),
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryOrange,
          foregroundColor: black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
          side: const BorderSide(color: black),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.disabled)) return darkGray;
            return primaryOrange;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.disabled)) return lightGray;
            return black;
          }),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: black,
          foregroundColor: primaryOrange,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
          side: const BorderSide(color: primaryOrange),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ).copyWith(
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.disabled)) return lightGray;
            return primaryOrange;
          }),
          side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
             if (states.contains(WidgetState.disabled)) return const BorderSide(color: darkGray);
             return const BorderSide(color: primaryOrange);
          }),
        ),
      ),
    );
  }
}