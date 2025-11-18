/// Debug configuration for troubleshooting
class DebugConfig {
  /// Enable verbose logging for debugging
  static const bool enableVerboseLogging = true;
  
  /// Force re-authentication on app start (for testing)
  static const bool forceReauth = false;
  
  /// Print all Firestore operations
  static const bool logFirestoreOps = true;
}