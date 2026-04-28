import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants.dart';

class AppTheme {
  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0D0D12);
  static const Color darkSurface = Color(0xFF1A1A24);
  static const Color darkSurfaceHighlight = Color(0xFF2A2A38);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFA0A0B0);

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF5F5F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceHighlight = Color(0xFFE5E5EA);
  static const Color lightTextPrimary = Color(0xFF1D1D1F);
  static const Color lightTextSecondary = Color(0xFF86868B);

  // Brand / Accent Colors
  static const Color accentNeonPurple = Color(0xFFB92ED6);
  static const Color accentElectricBlue = Color(0xFF00E5FF);
  static const Color errorColor = Color(0xFFFF3366);
  static const Color successColor = Color(0xFF34C759);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: accentNeonPurple,
      colorScheme: const ColorScheme.dark(
        primary: accentNeonPurple,
        secondary: accentElectricBlue,
        surface: darkSurface,
        error: errorColor,
      ),
      textTheme: _buildTextTheme(darkTextPrimary, darkTextSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: darkTextPrimary),
        titleTextStyle: GoogleFonts.poppins(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      cardTheme: CardThemeData(
        color: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: _buildInputDecorationTheme(darkSurface, darkTextSecondary),
      dividerTheme: const DividerThemeData(color: darkSurfaceHighlight, thickness: 1),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: accentNeonPurple,
      colorScheme: const ColorScheme.light(
        primary: accentNeonPurple,
        secondary: accentElectricBlue,
        surface: lightSurface,
        error: errorColor,
      ),
      textTheme: _buildTextTheme(lightTextPrimary, lightTextSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: lightTextPrimary),
        titleTextStyle: GoogleFonts.poppins(
          color: lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      cardTheme: CardThemeData(
        color: lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: _buildInputDecorationTheme(lightBackground, lightTextSecondary),
      dividerTheme: const DividerThemeData(color: lightSurfaceHighlight, thickness: 1),
    );
  }

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: GoogleFonts.poppins(
        color: primary,
        fontSize: 32,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.poppins(
        color: primary,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.poppins(
        color: primary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.inter(
        color: primary,
        fontSize: 16,
      ),
      bodyMedium: GoogleFonts.inter(
        color: secondary,
        fontSize: 14,
      ),
      labelLarge: GoogleFonts.inter(
        color: primary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentNeonPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingLarge, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        elevation: 0,
        textStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme(Color fillColor, Color labelColor) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        borderSide: const BorderSide(color: accentElectricBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        borderSide: const BorderSide(color: errorColor, width: 1),
      ),
      labelStyle: GoogleFonts.inter(color: labelColor),
      hintStyle: GoogleFonts.inter(color: labelColor.withAlpha(128)),
    );
  }
}

