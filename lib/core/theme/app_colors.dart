import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static bool isDark = false;

  // ── Dynamic theme-aware tokens ────────────────────────────────────────
  // These switch automatically based on isDark so every screen gets
  // correct colours without per-screen context helpers.

  // Backgrounds & Surfaces
  static Color get background => const Color(0xFFF8FAFC);
  static Color get surface => const Color(0xFFFFFFFF);
  static Color get surfaceContainerLowest => const Color(0xFFFFFFFF);
  static Color get surfaceContainerLow => const Color(0xFFF1F5F9);
  static Color get surfaceContainer => const Color(0xFFE2E8F0);
  static Color get surfaceContainerHigh => const Color(0xFFCBD5E1);
  static Color get surfaceContainerHighest => const Color(0xFF94A3B8);

  // Surface aliases for backward compatibility
  static Color get surface2 => const Color(0xFFF1F5F9);
  static Color get border => const Color(0xFFE2E8F0);

  // Primary & Ocean Accents
  static Color get primary => const Color(0xFF0284C7);
  static Color get primaryContainer => const Color(0xFFE0F2FE);
  static Color get onPrimary => const Color(0xFFFFFFFF);
  static Color get primaryLight => const Color(0xFF38BDF8);

  // Dedicated Button Colors
  static Color get buttonPrimary => const Color(0xFF0284C7);
  static Color get buttonOnPrimary => const Color(0xFFFFFFFF);

  // Secondary Accents (Cyan / Sky Blue)
  static Color get secondary => const Color(0xFF06B6D4);
  static Color get secondaryContainer => const Color(0xFFE0F2FE);
  static Color get onSecondaryContainer => const Color(0xFF0284C7);
  static Color get secondaryFixed => const Color(0xFFE0F2FE);
  static Color get secondaryFixedDim => const Color(0xFF38BDF8);
  static Color get onSecondaryFixed => const Color(0xFF0284C7);

  // Tertiary Accents (Lavender / Purple)
  static Color get tertiary => const Color(0xFF0284C7);
  static const Color tertiaryContainer = Color(0xFFE0F2FE);
  static Color get tertiaryFixed => const Color(0xFFE0F2FE);
  static const Color tertiaryFixedDim = Color(0xFFBAE6FD);
  static Color get onTertiaryFixed => const Color(0xFF0284C7);

  // Semantic (same in both themes)
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color onErrorContainer = Color(0xFFB91C1C);

  // Text Hierarchy
  static Color get onSurface => const Color(0xFF1E293B);
  static Color get textPrimary => const Color(0xFF1E293B);
  static Color get onSurfaceVariant => const Color(0xFF64748B);
  static Color get textSecondary => const Color(0xFF64748B);
  static Color get outline => const Color(0xFFCBD5E1);
  static Color get outlineVariant => const Color(0xFFE2E8F0);
  static Color get textMuted => const Color(0xFF94A3B8);

  // Accent & note colors (same in both themes)
  static const Color accent = Color(0xFF00658D);
  static const Color noteBlue = Color(0xFF00658D);
  static const Color noteGreen = Color(0xFF059669);
  static const Color noteYellow = Color(0xFFD97706);
  static const Color notePink = Color(0xFFDB2777);
  static const Color notePurple = Color(0xFF7C3AED);

  // Pitch Black AMOLED tokens (kept for direct access)
  static const Color pitchBlackBackground = Color(0xFF000000);
  static const Color pitchBlackSurface = Color(0xFF111116);
  static const Color pitchBlackSurface2 = Color(0xFF1A1A24);
  static const Color pitchBlackBorder = Color(0x22FFFFFF);
  static const Color pitchBlackTextPrimary = Color(0xFFFFFFFF);
  static const Color pitchBlackTextSecondary = Color(0xFFA1A1AA);
  static const Color pitchBlackTextMuted = Color(0xFF71717A);

  static const Color amoledBackground = pitchBlackBackground;
  static const Color amoledSurface = pitchBlackSurface;
  static const Color amoledSurface2 = pitchBlackSurface2;
  static const Color amoledBorder = pitchBlackBorder;

  static const Color lightBackground = Color(0xFFF7F9FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  static Color noteColorFromString(String? color) {
    switch (color) {
      case 'blue':   return noteBlue;
      case 'green':  return noteGreen;
      case 'yellow': return noteYellow;
      case 'pink':   return notePink;
      case 'purple': return notePurple;
      default:       return secondary;
    }
  }

  static Gradient get primaryGradient => const LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static Gradient get cyanGradient => LinearGradient(
    colors: isDark
        ? [const Color(0xFF38BDF8), const Color(0xFF0284C7)]
        : [const Color(0xFF3DBEFF), const Color(0xFF00658D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<Color> deckGradientFromString(String? color) {
    switch (color) {
      case 'blue':   return [const Color(0xFFC6E7FF), const Color(0xFF83CFFF)];
      case 'green':  return [const Color(0xFFD1FAE5), const Color(0xFFA7F3D0)];
      case 'yellow': return [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)];
      case 'pink':   return [const Color(0xFFFCE7F3), const Color(0xFFFBCFE8)];
      case 'purple': return [const Color(0xFFEDE9FE), const Color(0xFFDDD6FE)];
      default:       return [const Color(0xFFECEEF1), const Color(0xFFE0E3E6)];
    }
  }

  // Dynamic Theme-aware helpers (still available for explicit context usage)
  static Color backgroundOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? pitchBlackBackground : const Color(0xFFF7F9FC);

  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? pitchBlackSurface : const Color(0xFFFFFFFF);

  static Color surface2Of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? pitchBlackSurface2 : const Color(0xFFF2F4F7);

  static Color borderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? pitchBlackBorder : const Color(0xFFE6E8EB);

  static Color textPrimaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? pitchBlackTextPrimary : const Color(0xFF191C1E);

  static Color textSecondaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? pitchBlackTextSecondary : const Color(0xFF46464B);

  static Color textMutedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? pitchBlackTextMuted : const Color(0xFF77777B);

  static Color primaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? pitchBlackTextPrimary : const Color(0xFF000000);

  static Color onPrimaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? pitchBlackBackground : const Color(0xFFFFFFFF);

  static Color buttonPrimaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF252538) : const Color(0xFF000000);

  static Color buttonOnPrimaryOf(BuildContext context) => const Color(0xFFFFFFFF);
}
