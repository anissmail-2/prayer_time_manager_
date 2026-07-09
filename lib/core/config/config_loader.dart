/// Configuration loader for app settings and API keys.
///
/// API keys are never stored in source code. Resolution order:
///   1. Runtime key saved by the user (Settings -> API Keys, backed by
///      [ApiConfigService] / SharedPreferences)
///   2. Compile-time value injected at build time via
///      `--dart-define=GEMINI_API_KEY=...` / `--dart-define=DEEPGRAM_API_KEY=...`
///   3. Empty string (the dependent feature stays disabled)
library;

import '../services/api_config_service.dart';

class ConfigLoader {
  // Compile-time keys injected via --dart-define (empty if not provided).
  static const String _envGeminiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _envDeepgramKey =
      String.fromEnvironment('DEEPGRAM_API_KEY');

  // Company domain configuration - easy to change
  static String get companyDomain => 'taskflow';
  static String get companyName => 'awkati';
  static String get packageName =>
      'com.$companyName.$companyDomain'; // com.awkati.taskflow

  // API Keys
  static String get geminiApiKey => ApiConfigService.hasGeminiKey
      ? ApiConfigService.geminiApiKey
      : _envGeminiKey;

  static String get deepgramApiKey => ApiConfigService.hasDeepgramKey
      ? ApiConfigService.deepgramApiKey
      : _envDeepgramKey;

  // Feature flags
  static bool get enableVoiceInput => true;
  static bool get enableFirebaseSync => false;

  // API Endpoints
  static String get prayerTimeApiBase => 'https://api.aladhan.com/v1';

  // Validation
  static bool get hasValidGeminiKey => geminiApiKey.isNotEmpty;

  static bool get hasValidDeepgramKey => deepgramApiKey.isNotEmpty;

  static void validateConfiguration() {
    if (!hasValidGeminiKey) {
      print('⚠️ WARNING: Gemini API key not configured. '
          'AI features will not work.');
      print('Set it in Settings -> API Keys, or build with '
          '--dart-define=GEMINI_API_KEY=<key>.');
    }
    if (!hasValidDeepgramKey && enableVoiceInput) {
      print('⚠️ WARNING: Deepgram API key not configured. '
          'Voice input will not work.');
      print('Set it in Settings -> API Keys, or build with '
          '--dart-define=DEEPGRAM_API_KEY=<key>.');
    }
  }
}
