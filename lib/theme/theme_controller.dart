import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app-wide light/dark preference and persists it, mirroring the
/// web client's `next-themes` toggle in the user menu.
class ThemeController {
  ThemeController._();

  static const _kThemeMode = 'themeMode';

  static final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    mode.value = prefs.getString(_kThemeMode) == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  static Future<void> set(ThemeMode value) async {
    mode.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, value.name);
  }

  static void toggle() {
    set(mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
