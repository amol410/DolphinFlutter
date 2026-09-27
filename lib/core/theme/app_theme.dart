import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData.light();
    return base.copyWith(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF7F9FC),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF000000),
        secondary: Color(0xFF00658D),
        surface: Color(0xFFFFFFFF),
        error: Color(0xFFBA1A1A),
        onPrimary: Color(0xFFFFFFFF),
        onSurface: Color(0xFF191C1E),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF191C1E),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF191C1E)),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 30, fontWeight: FontWeight.w800, color: const Color(0xFF191C1E), letterSpacing: -0.8,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 26, fontWeight: FontWeight.w700, color: const Color(0xFF191C1E), letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF191C1E),
        ),
        headlineSmall: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF191C1E),
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF191C1E),
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF191C1E),
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF191C1E),
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF46464B),
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF46464B),
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF191C1E),
        ),
        labelMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF46464B),
        ),
        labelSmall: GoogleFonts.plusJakartaSans(
          fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF46464B),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE6E8EB),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1B1B1F),
        contentTextStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF2F4F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: const BorderSide(color: Color(0xFF000000), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1.5),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF46464B)),
        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF77777B)),
        errorStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFFBA1A1A)),
        prefixIconColor: const Color(0xFF46464B),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF2F4F7),
        selectedColor: const Color(0xFF000000),
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
        side: BorderSide.none,
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF000000),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFFFFFF),
        secondary: Color(0xFF38BDF8),
        surface: Color(0xFF111116),
        error: Color(0xFFEF4444),
        onPrimary: Color(0xFF000000),
        onSurface: Color(0xFFF4F4F5),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFF4F4F5),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFF4F4F5)),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 30, fontWeight: FontWeight.w800, color: const Color(0xFFF4F4F5), letterSpacing: -0.8,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 26, fontWeight: FontWeight.w700, color: const Color(0xFFF4F4F5), letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFFF4F4F5),
        ),
        headlineSmall: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFFF4F4F5),
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFFF4F4F5),
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFFF4F4F5),
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFFF4F4F5),
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFFA1A1AA),
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFFA1A1AA),
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFFF4F4F5),
        ),
        labelMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFA1A1AA),
        ),
        labelSmall: GoogleFonts.plusJakartaSans(
          fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFA1A1AA),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF111116),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x22FFFFFF), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x22FFFFFF),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF22222E),
        contentTextStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A24),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: const BorderSide(color: Color(0x22FFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: const BorderSide(color: Color(0x22FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: const BorderSide(color: Color(0xFFFFFFFF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFFA1A1AA)),
        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF71717A)),
        errorStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFFEF4444)),
        prefixIconColor: const Color(0xFFA1A1AA),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1A1A24),
        selectedColor: const Color(0xFFFFFFFF),
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
          side: const BorderSide(color: Color(0x22FFFFFF), width: 1),
        ),
      ),
    );
  }

  // Alias pitchBlack for backward compatibility
  static ThemeData get pitchBlack => dark;
}
