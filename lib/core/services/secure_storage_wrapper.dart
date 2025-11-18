import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper for secure storage that falls back to SharedPreferences on Linux
/// This is a development workaround for Linux desktop builds
class SecureStorageWrapper {
  static const _prefix = 'secure_';

  static Future<void> write({required String key, required String? value}) async {
    // Temporarily use SharedPreferences for all platforms
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove('$_prefix$key');
    } else {
      await prefs.setString('$_prefix$key', value);
    }
  }

  static Future<String?> read({required String key}) async {
    // Temporarily use SharedPreferences for all platforms
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$key');
  }

  static Future<void> delete({required String key}) async {
    // Temporarily use SharedPreferences for all platforms
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }

  static Future<void> deleteAll() async {
    // Temporarily use SharedPreferences for all platforms
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}