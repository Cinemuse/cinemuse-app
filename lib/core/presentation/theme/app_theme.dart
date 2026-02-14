import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors extracted from index.css
  static const Color primary = Color(0xFF0f0518);
  static const Color secondary = Color(0xFF1a0b2e);
  static const Color glass = Color(0xF20f0518); // rgba(15, 5, 24, 0.95)
  
  static const Color accent = Color(0xFFd946ef); // Pink/Purple
  static const Color accentHover = Color(0xFFc026d3);
  static const Color accentGlow = Color(0x80d946ef); // rgba(217, 70, 239, 0.5)
  
  static const Color surface = Color(0xFF1a0b2e);
  static const Color border = Color(0x33d946ef); // rgba(217, 70, 239, 0.2)
  static const Color borderHover = Color(0x66d946ef); // rgba(217, 70, 239, 0.4)
  
  static const Color textWhite = Color(0xFFffffff);
  static const Color textSecondary = Color(0xFFe5e7eb); // Gray 200
  static const Color textMuted = Color(0xFF9ca3af); // Gray 400

  // Shadows
  static const List<BoxShadow> shadowNeon = [
    BoxShadow(
      color: accentGlow,
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> shadowNeonSm = [
    BoxShadow(
      color: accentGlow,
      blurRadius: 10,
      spreadRadius: 0,
    ),
  ];

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primary,
      primaryColor: primary,
      
      // Text Theme
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: textWhite,
        displayColor: textWhite,
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textWhite),
        titleTextStyle: TextStyle(
          color: textWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondary.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent),
        ),
        hintStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // ElevatedButton Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: textWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
          elevation: 5,
          shadowColor: accentGlow,
        ),
      ),

      // TextButton Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textWhite,
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: textWhite,
      ),
      
      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentHover,
        surface: surface,
        surfaceContainer: secondary,
        onSurface: textWhite,
        error: Colors.redAccent,
      ),
    );
  }
}
