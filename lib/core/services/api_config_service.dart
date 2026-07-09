import 'package:shared_preferences/shared_preferences.dart';

/// Runtime API key store.
///
/// Keys are entered by the user at runtime (Settings -> API Keys) and
/// persisted in SharedPreferences, with an in-memory cache so reads stay
/// synchronous for [ConfigLoader].
///
/// NOTE: SharedPreferences is plain, unencrypted on-device storage. It keeps
/// keys out of the source tree and out of the APK, but it is not hardened
/// against a rooted/compromised device.
class ApiConfigService {
  // SharedPreferences keys
  static const String _geminiPrefsKey = 'api_key_gemini';
  static const String _deepgramPrefsKey = 'api_key_deepgram';

  // Legacy keys written by the old SecureStorageWrapper implementation
  // (SharedPreferences entries with a 'secure_' prefix). Read once for
  // migration so previously saved keys are not lost.
  static const String _legacyGeminiPrefsKey = 'secure_gemini_api_key';
  static const String _legacyDeepgramPrefsKey = 'secure_deepgram_api_key';

  // In-memory cache
  static String _geminiKey = '';
  static String _deepgramKey = '';
  static bool _initialized = false;

  /// Loads stored keys into the in-memory cache.
  /// Must be called on app startup (see main.dart).
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _geminiKey = prefs.getString(_geminiPrefsKey) ??
          prefs.getString(_legacyGeminiPrefsKey) ??
          '';
      _deepgramKey = prefs.getString(_deepgramPrefsKey) ??
          prefs.getString(_legacyDeepgramPrefsKey) ??
          '';

      _initialized = true;
    } catch (e) {
      // App must still start without keys; AI/voice features simply stay
      // disabled until keys are provided.
      print('Error initializing API config: $e');
    }
  }

  /// Whether [initialize] has completed successfully.
  static bool get isInitialized => _initialized;

  /// Gemini API key set at runtime (empty string if not set).
  static String get geminiApiKey => _geminiKey;

  /// Deepgram API key set at runtime (empty string if not set).
  static String get deepgramApiKey => _deepgramKey;

  static bool get hasGeminiKey => _geminiKey.isNotEmpty;
  static bool get hasDeepgramKey => _deepgramKey.isNotEmpty;

  /// Stores the Gemini API key. Pass an empty string to clear it.
  static Future<void> setGeminiApiKey(String key) async {
    _geminiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    if (_geminiKey.isEmpty) {
      await prefs.remove(_geminiPrefsKey);
    } else {
      await prefs.setString(_geminiPrefsKey, _geminiKey);
    }
    await prefs.remove(_legacyGeminiPrefsKey);
  }

  /// Stores the Deepgram API key. Pass an empty string to clear it.
  static Future<void> setDeepgramApiKey(String key) async {
    _deepgramKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    if (_deepgramKey.isEmpty) {
      await prefs.remove(_deepgramPrefsKey);
    } else {
      await prefs.setString(_deepgramPrefsKey, _deepgramKey);
    }
    await prefs.remove(_legacyDeepgramPrefsKey);
  }

  /// Removes the stored Gemini API key so any --dart-define build-time key
  /// (or no key) takes effect again.
  static Future<void> removeGeminiApiKey() => setGeminiApiKey('');

  /// Removes the stored Deepgram API key so any --dart-define build-time key
  /// (or no key) takes effect again.
  static Future<void> removeDeepgramApiKey() => setDeepgramApiKey('');

  /// Clears all stored API keys (for logout/reset).
  static Future<void> clearAllKeys() async {
    _geminiKey = '';
    _deepgramKey = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_geminiPrefsKey);
    await prefs.remove(_deepgramPrefsKey);
    await prefs.remove(_legacyGeminiPrefsKey);
    await prefs.remove(_legacyDeepgramPrefsKey);
  }
}
