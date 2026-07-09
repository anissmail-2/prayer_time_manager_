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

  // Whether a compile-time (--dart-define) key exists, used as the fallback
  // when no runtime key is stored. Exposed so the API keys screen can show
  // a "Using build-time key" state without duplicating this logic.
  static bool get hasBuildTimeGeminiKey => _envGeminiKey.isNotEmpty;

  static bool get hasBuildTimeDeepgramKey => _envDeepgramKey.isNotEmpty;

  // Validation
  static bool get hasValidGeminiKey => geminiApiKey.isNotEmpty;

  static bool get hasValidDeepgramKey => deepgramApiKey.isNotEmpty;
}
