/// Configuration loader that handles local and default configs
/// 
/// IMPORTANT: For development, use app_config.local.dart
/// For production, replace values in app_config.dart
library;

// Import local config if available, otherwise use default
// ignore_for_file: uri_does_not_exist, unused_import
import 'app_config.local.dart' if (dart.library.html) 'app_config.dart' as config;

class ConfigLoader {
  // Company domain configuration - easy to change
  static String get companyDomain => config.AppConfig.companyDomain;
  static String get companyName => config.AppConfig.companyName;
  static String get packageName => config.AppConfig.packageName;
  
  // API Keys
  static String get geminiApiKey => config.AppConfig.geminiApiKey;
  static String get deepgramApiKey => config.AppConfig.deepgramApiKey;
  
  // Feature flags
  static bool get enableVoiceInput => config.AppConfig.enableVoiceInput;
  static bool get enableFirebaseSync => config.AppConfig.enableFirebaseSync;
  
  // API Endpoints
  static String get prayerTimeApiBase => config.AppConfig.prayerTimeApiBase;
  
  // Validation
  static bool get hasValidGeminiKey => 
      geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE' && 
      geminiApiKey.isNotEmpty;
  
  static bool get hasValidDeepgramKey => 
      deepgramApiKey != 'YOUR_DEEPGRAM_API_KEY_HERE' && 
      deepgramApiKey.isNotEmpty;
  
  static void validateConfiguration() {
    if (!hasValidGeminiKey) {
      print('⚠️ WARNING: Gemini API key not configured. AI features will not work.');
      print('Please create lib/core/config/app_config.local.dart with your API keys.');
    }
    if (!hasValidDeepgramKey && enableVoiceInput) {
      print('⚠️ WARNING: Deepgram API key not configured. Voice input will not work.');
      print('Please create lib/core/config/app_config.local.dart with your API keys.');
    }
  }
}