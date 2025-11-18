import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'secure_storage_wrapper.dart';

/// Service for managing API keys and sensitive configuration
/// This centralizes all API key access and provides secure storage
class ApiConfigService {
  
  // Storage keys
  static const _geminiKeyStorage = 'gemini_api_key';
  static const _deepgramKeyStorage = 'deepgram_api_key';
  static const _firebaseKeyStorage = 'firebase_api_key';
  
  // Cache for loaded keys
  static String? _geminiKey;
  static String? _deepgramKey;
  static String? _firebaseKey;
  static String? _firebaseProjectId;
  
  /// Initialize API configuration
  /// Must be called on app startup
  static Future<void> initialize() async {
    try {
      // Load environment variables
      await dotenv.load(fileName: ".env");
      
      // Load or migrate API keys
      await _loadOrMigrateKeys();
    } catch (e) {
      print('Error initializing API config: $e');
      // App should handle this gracefully
    }
  }
  
  /// Load keys from secure storage or migrate from .env
  static Future<void> _loadOrMigrateKeys() async {
    // Try to load from secure storage first
    _geminiKey = await SecureStorageWrapper.read(key: _geminiKeyStorage);
    _deepgramKey = await SecureStorageWrapper.read(key: _deepgramKeyStorage);
    _firebaseKey = await SecureStorageWrapper.read(key: _firebaseKeyStorage);
    
    // If not in secure storage, migrate from .env
    if (_geminiKey == null) {
      _geminiKey = dotenv.env['GEMINI_API_KEY'];
      if (_geminiKey != null) {
        await SecureStorageWrapper.write(key: _geminiKeyStorage, value: _geminiKey);
      }
    }
    
    if (_deepgramKey == null) {
      _deepgramKey = dotenv.env['DEEPGRAM_API_KEY'];
      if (_deepgramKey != null) {
        await SecureStorageWrapper.write(key: _deepgramKeyStorage, value: _deepgramKey);
      }
    }
    
    if (_firebaseKey == null) {
      _firebaseKey = dotenv.env['FIREBASE_API_KEY'];
      if (_firebaseKey != null) {
        await SecureStorageWrapper.write(key: _firebaseKeyStorage, value: _firebaseKey);
      }
    }
    
    // Firebase project ID (not sensitive, can stay in .env)
    _firebaseProjectId = dotenv.env['FIREBASE_PROJECT_ID'];
  }
  
  /// Get Gemini API key
  static String? get geminiApiKey => _geminiKey;
  
  /// Get Deepgram API key
  static String? get deepgramApiKey => _deepgramKey;
  
  /// Get Firebase API key
  static String? get firebaseApiKey => _firebaseKey;
  
  /// Get Firebase project ID
  static String? get firebaseProjectId => _firebaseProjectId;
  
  /// Update an API key (for future settings screen)
  static Future<void> updateApiKey(String keyType, String newKey) async {
    switch (keyType) {
      case 'gemini':
        _geminiKey = newKey;
        await SecureStorageWrapper.write(key: _geminiKeyStorage, value: newKey);
        break;
      case 'deepgram':
        _deepgramKey = newKey;
        await SecureStorageWrapper.write(key: _deepgramKeyStorage, value: newKey);
        break;
      case 'firebase':
        _firebaseKey = newKey;
        await SecureStorageWrapper.write(key: _firebaseKeyStorage, value: newKey);
        break;
    }
  }
  
  /// Clear all stored API keys (for logout/reset)
  static Future<void> clearAllKeys() async {
    await SecureStorageWrapper.deleteAll();
    _geminiKey = null;
    _deepgramKey = null;
    _firebaseKey = null;
  }
  
  /// Check if all required keys are available
  static bool get hasRequiredKeys {
    return _geminiKey != null && _geminiKey!.isNotEmpty;
  }
}