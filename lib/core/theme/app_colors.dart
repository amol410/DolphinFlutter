import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF0A0F1E);
  static const Color surface = Color(0xFF111827);
  static const Color surface2 = Color(0xFF1A2235);
  static const Color border = Color(0x12FFFFFF);

  // Primary / Accent
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color accent = Color(0xFFA855F7);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Text
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF4B5563);

  // Note colors
  static const Color noteBlue = Color(0xFF3B82F6);
  static const Color noteGreen = Color(0xFF10B981);
  static const Color noteYellow = Color(0xFFF59E0B);
  static const Color notePink = Color(0xFFEC4899);
  static const Color notePurple = Color(0xFFA855F7);

  static Color noteColorFromString(String? color) {
    switch (color) {
      case 'blue':   return noteBlue;
      case 'green':  return noteGreen;
      case 'yellow': return noteYellow;
      case 'pink':   return notePink;
      case 'purple': return notePurple;
      default:       return textMuted;
    }
  }

  static const Gradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static List<Color> deckGradientFromString(String? color) {
    switch (color) {
      case 'blue':   return [Color(0xFF1E3A5F), Color(0xFF1E40AF)];
      case 'green':  return [Color(0xFF064E3B), Color(0xFF065F46)];
      case 'yellow': return [Color(0xFF78350F), Color(0xFF92400E)];
      case 'pink':   return [Color(0xFF831843), Color(0xFF9D174D)];
      case 'purple': return [Color(0xFF4C1D95), Color(0xFF6D28D9)];
      default:       return [Color(0xFF1A2235), Color(0xFF111827)];
    }
  }
}
