import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primary = Color(0xFF0f0518);
  static const Color secondary = Color(0xFF1a0b2e);
  static const Color glass = Color(0xF20f0518); // rgba(15, 5, 24, 0.95)

  static const Color accent = Color(0xFFd946ef); // Pink/Purple
  static const Color accentHover = Color(0xFFc026d3);
  static const Color accentGlow = Color(0x40d946ef); // rgba(217, 70, 239, 0.25)
  static Color get accentHoverBg => accent.withValues(alpha: 0.1);

  static const Color favorites = Color(0xFFef4444); // Red 500
  static const Color watchlist = Color(0xFFeab308); // Yellow 500

  static const Color star = Color(0xFFffc107); // Amber 500

  static const Color success = Color(0xFF22c55e); // Green 500
  static const Color info = Color(0xFF3b82f6); // Blue 500
  static const Color error = Colors.redAccent;

  static const Color surface = secondary;
  static const Color border = Color(0x33d946ef); // rgba(217, 70, 239, 0.2)

  static const Color textWhite = Color(0xFFffffff);
  static const Color textSecondary = Color(0xFFe5e7eb); // Gray 200
  static const Color textMuted = Color(0xFF9ca3af); // Gray 400

  static const Color surfaceOverlay = Color(
    0x8C000000,
  ); // 55% black for frosted HUDs
  static const Color borderSubtle = Color(
    0x26FFFFFF,
  ); // 15% white for glass borders

  // Stream Metadata Badge Tokens
  static const Color badgeHdr = Color(0xFFf97316); // Orange 500
  static const Color badgeResolution = Color(0xFF3b82f6); // Blue 500
  static const Color badgeSize = Color(0xFF06b6d4); // Cyan 500
  static const Color badgeAudio = Color(0xFF8b5cf6); // Purple 500
  static const Color badgeFlag = Color(0xFFf59e0b); // Amber 500

  // Standard Border Radii
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(4));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(8));
  static const BorderRadius radius12 = BorderRadius.all(Radius.circular(12));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(16));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(20));
  static const BorderRadius radiusFull = BorderRadius.all(Radius.circular(999));

  // Focus & Navigation Constants
  static const Color focusRing = Color(0xFFffffff);
  static const List<BoxShadow> shadowFocusGlow = [
    BoxShadow(color: Color(0x33ffffff), blurRadius: 12, spreadRadius: 1),
  ];

  // Shadows
  static const List<BoxShadow> shadowNeonSm = [
    BoxShadow(color: accentGlow, blurRadius: 8, spreadRadius: 0),
  ];

  /// Standard card drop shadow. Used by MediaCard, BackdropCard.
  static const List<BoxShadow> shadowCard = [
    BoxShadow(
      color: Color(0x80000000), // black 50%
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  /// Accent glow under CTA buttons (Play, Resume).
  static const List<BoxShadow> shadowAccentGlow = [
    BoxShadow(
      color: Color(0x66d946ef), // accent 40%
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ];

  /// Subtle decorative glow for icons/badges.
  static const List<BoxShadow> shadowSubtleGlow = [
    BoxShadow(
      color: Color(0x05FFFFFF), // white 2%
      blurRadius: 16,
    ),
  ];

  /// Hand cursor on everything clickable, arrow when disabled. Flutter's
  /// desktop default is the arrow (native style); the app uses the hand
  /// everywhere, like its cards (REV-246).
  static const WidgetStateMouseCursor clickCursor =
      WidgetStateMouseCursor.clickable;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primary,
      primaryColor: primary,

      // Text Theme
      textTheme: ThemeData.dark().textTheme.apply(
        fontFamily: 'Outfit',
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
        fillColor: secondary.withValues(alpha: 0.5),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      // Focus & Hover
      focusColor: accentHoverBg,
      hoverColor: accentHoverBg,

      // ElevatedButton Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          mouseCursor: clickCursor,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return accentHover;
            }
            return accent;
          }),
          foregroundColor: const WidgetStatePropertyAll(textWhite),
          side: const WidgetStatePropertyAll(BorderSide.none),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) return 4;
            if (states.contains(WidgetState.hovered)) return 4;
            return 2;
          }),
          shadowColor: const WidgetStatePropertyAll(accentGlow),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return accent.withValues(alpha: 0.12);
            }
            return null;
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),

      // OutlinedButton Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          mouseCursor: clickCursor,
          foregroundColor: const WidgetStatePropertyAll(textWhite),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused) ||
                states.contains(WidgetState.hovered)) {
              return BorderSide(
                color: accent.withValues(alpha: 0.5),
                width: 1.5,
              );
            }
            return BorderSide(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            );
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return accentHoverBg;
            }
            if (states.contains(WidgetState.hovered)) {
              return accent.withValues(alpha: 0.08);
            }
            return Colors.transparent;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return accent.withValues(alpha: 0.12);
            }
            return null;
          }),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(accentGlow),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),

      // TextButton Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textWhite,
          textStyle: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
          ),
        ).copyWith(mouseCursor: clickCursor),
      ),
      filledButtonTheme: const FilledButtonThemeData(
        style: ButtonStyle(mouseCursor: clickCursor),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(mouseCursor: clickCursor),
      ),
      popupMenuTheme: const PopupMenuThemeData(mouseCursor: clickCursor),

      // Icon Theme
      iconTheme: const IconThemeData(color: textWhite),

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentHover,
        surface: surface,
        surfaceContainer: secondary,
        onSurface: textWhite,
        error: error,
      ),
    );
  }

  static double getResponsiveHorizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < Breakpoints.compact) return 16;
    return width * 0.05;
  }

  /// Layout offset for overlapping the hero section with downstream content rails.
  /// On mobile, content overlaps slightly (-24px), whereas desktop/TV uses a deeper overlap (-60px).
  /// If offline banner or similar top spacing exists, offset is 0.
  static double getHeroContentOverlap({
    required bool isMobile,
    bool isOffline = false,
  }) {
    if (isOffline) return 0.0;
    return isMobile ? -24.0 : -60.0;
  }

  static TextStyle monoStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Fira Code',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle get taglineStyle {
    return const TextStyle(
      fontFamily: 'Lora',
      color: accent,
      fontStyle: FontStyle.italic,
      fontSize: 18,
      fontWeight: FontWeight.w500,
    );
  }
}

class DesktopTypography {
  static const heroTitle = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 48,
    fontWeight: FontWeight.w900,
    height: 1.1,
    color: AppTheme.textWhite,
  );

  static const sectionHeader = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppTheme.textWhite,
  );

  static const bentoHeader = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppTheme.textWhite,
    letterSpacing: 1.1,
  );

  static const subtitle = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppTheme.textWhite,
  );

  static const bodyPrimary = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppTheme.textSecondary,
    height: 1.6,
  );

  static const bodySecondary = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppTheme.textSecondary,
  );

  static const captionMeta = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 16,
    fontWeight: FontWeight.w400, // Reduced from 500 for better secondary feel
    color: AppTheme.textMuted,
    letterSpacing: 0.2,
  );
}
