/// Local App Configuration - DO NOT COMMIT THIS FILE
/// Add this file to .gitignore
library;

class AppConfig {
  // Company domain - change this to your actual domain when ready for Play Store
  static const String companyDomain = 'taskflow';
  static const String companyName = 'awkati';
  
  // Full package name
  static String get packageName => 'com.$companyName.$companyDomain'; // com.awkati.taskflow
  
  // ACTUAL API Keys - Keep these secret!
  static const String geminiApiKey = 'AIzaSyDuW4ld6jnO3SPocwJbUK1xTI3oMZs7lVI';
  static const String deepgramApiKey = '17cf7c16bb088ca96a3ce9e0170b8c78d0f3d3a5';
  
  // Firebase Configuration
  static const String firebaseProjectId = 'YOUR_FIREBASE_PROJECT_ID';
  
  // Feature Flags
  static const bool enableVoiceInput = true;
  static const bool enableFirebaseSync = false;
  
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