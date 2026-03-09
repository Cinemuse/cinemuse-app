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
  
  static const Color favorites = Color(0xFFef4444); // Red 500
  static const Color favoritesGlow = Color(0x80ef4444);
  static const Color watchlist = Color(0xFFeab308); // Yellow 500
  static const Color watchlistGlow = Color(0x80eab308);
  
  static const Color star = Color(0xFFffc107); // Amber 500
  static const Color starGlow = Color(0x80ffc107);
  
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

  static double getResponsiveHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 16;
    return width * 0.05;
  }
}

class DesktopTypography {
  static TextStyle heroTitle = GoogleFonts.outfit(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    height: 1.1,
    color: AppTheme.textWhite,
  );

  static TextStyle sectionHeader = GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppTheme.textWhite,
  );

  static TextStyle bentoHeader = GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppTheme.textWhite,
    letterSpacing: 1.1,
  );

  static TextStyle subtitle = GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppTheme.textWhite,
  );

  static TextStyle bodyPrimary = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppTheme.textSecondary,
    height: 1.6,
  );

  static TextStyle bodySecondary = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppTheme.textSecondary,
  );

  static TextStyle captionMeta = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w400, // Reduced from 500 for better secondary feel
    color: AppTheme.textMuted,
    letterSpacing: 0.2,
  );
}
