/// App Configuration
/// 
/// IMPORTANT: Never commit real API keys to version control!
/// 
/// For development:
/// 1. Copy this file to app_config.local.dart
/// 2. Add real keys to the local file
/// 3. Add app_config.local.dart to .gitignore
/// 
/// For production:
/// Use environment variables or secure key management service
library;

class AppConfig {
  // Company domain - change this to your actual domain when ready for Play Store
  static const String companyDomain = 'taskflow';
  static const String companyName = 'awkati';
  
  // Full package name
  static String get packageName => 'com.$companyName.$companyDomain'; // com.awkati.taskflow
  
  // API Keys - REPLACE WITH YOUR OWN KEYS
  // These are placeholder keys that won't work
  static const String geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';
  static const String deepgramApiKey = 'YOUR_DEEPGRAM_API_KEY_HERE';
  
  // Firebase Configuration (if needed)
  static const String firebaseProjectId = 'YOUR_FIREBASE_PROJECT_ID';
  
  // Feature Flags
  static const bool enableVoiceInput = true;
  static const bool enableFirebaseSync = false; // Disabled until fully implemented
  
  // API Endpoints
  static const String prayerTimeApiBase = 'https://api.aladhan.com/v1';
  
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
    }
    if (!hasValidDeepgramKey && enableVoiceInput) {
      print('⚠️ WARNING: Deepgram API key not configured. Voice input will not work.');
    }
  }
}