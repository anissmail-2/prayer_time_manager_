import 'package:flutter/material.dart';
import '../helpers/storage_helper.dart';
import '../helpers/analytics_helper.dart';

/// Service to manage app theme (dark/light mode)
class ThemeService {
  static const String _themeModeKey = 'theme_mode';

  /// Get current theme mode
  /// Returns system default if not set
  static Future<ThemeMode> getThemeMode() async {
    final value = await StorageHelper.getString(_themeModeKey);

    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  /// Set theme mode
  static Future<void> setThemeMode(ThemeMode mode) async {
    final value = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';

    await StorageHelper.saveString(_themeModeKey, value);

    // Log analytics
    await AnalyticsHelper.logEvent(
      name: 'theme_changed',
      parameters: {'mode': value},
    );
  }

  /// Check if dark mode is currently active
  /// Takes into account system theme when in system mode
  static bool isDarkMode(BuildContext context, ThemeMode themeMode) {
    if (themeMode == ThemeMode.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
    return themeMode == ThemeMode.dark;
  }

  /// Get theme mode display name
  static String getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }
}
