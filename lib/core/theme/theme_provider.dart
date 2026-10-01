import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

const String _kThemePrefKey = 'app_theme_mode';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_kThemePrefKey);
      // DolphinCoder 2.0 uses the vibrant oceanic light theme.
      // If legacy 'dark' was stored from the older app version, migrate it to 'light'.
      if (modeStr == 'dark') {
        state = ThemeMode.light;
        AppColors.isDark = false;
        await prefs.setString(_kThemePrefKey, 'light');
      } else if (modeStr == 'light') {
        state = ThemeMode.light;
        AppColors.isDark = false;
      } else {
        state = ThemeMode.light;
        AppColors.isDark = false;
        await prefs.setString(_kThemePrefKey, 'light');
      }
    } catch (_) {
      state = ThemeMode.light;
      AppColors.isDark = false;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    AppColors.isDark = mode == ThemeMode.dark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemePrefKey, mode == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    final next = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(next);
  }
}
