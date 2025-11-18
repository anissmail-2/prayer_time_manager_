import '../helpers/storage_helper.dart';
import '../helpers/analytics_helper.dart';

/// Service for managing user preferences and app modes
class UserPreferencesService {
  // Storage keys
  static const _prayerModeKey = 'prayer_mode_enabled';
  static const _onboardingCompletedKey = 'onboarding_completed';
  static const _userDisplayNameKey = 'user_display_name';
  static const _appModeKey = 'app_mode'; // 'prayer' or 'productivity'

  /// Check if prayer mode is enabled
  /// Default: true (for existing users)
  static Future<bool> isPrayerModeEnabled() async {
    final value = await StorageHelper.getString(_prayerModeKey);
    // Default to true for backward compatibility
    return value != 'false';
  }

  /// Enable or disable prayer mode
  static Future<void> setPrayerMode(bool enabled) async {
    await StorageHelper.saveString(_prayerModeKey, enabled.toString());
    await AnalyticsHelper.logEvent(
      name: 'prayer_mode_changed',
      parameters: {'enabled': enabled},
    );
  }

  /// Get app mode ('prayer' or 'productivity')
  static Future<String> getAppMode() async {
    if (await isPrayerModeEnabled()) {
      return 'prayer';
    } else {
      return 'productivity';
    }
  }

  /// Set app mode
  static Future<void> setAppMode(String mode) async {
    final isPrayerMode = mode == 'prayer';
    await setPrayerMode(isPrayerMode);
    await AnalyticsHelper.logEvent(
      name: 'app_mode_selected',
      parameters: {'mode': mode},
    );
  }

  /// Check if onboarding has been completed
  static Future<bool> isOnboardingCompleted() async {
    final value = await StorageHelper.getString(_onboardingCompletedKey);
    return value == 'true';
  }

  /// Mark onboarding as completed
  static Future<void> completeOnboarding() async {
    await StorageHelper.saveString(_onboardingCompletedKey, 'true');
    await AnalyticsHelper.logEvent(name: 'onboarding_completed');
  }

  /// Reset onboarding (for testing)
  static Future<void> resetOnboarding() async {
    await StorageHelper.saveString(_onboardingCompletedKey, 'false');
  }

  /// Get user display name
  static Future<String?> getUserDisplayName() async {
    return await StorageHelper.getString(_userDisplayNameKey);
  }

  /// Set user display name
  static Future<void> setUserDisplayName(String name) async {
    await StorageHelper.saveString(_userDisplayNameKey, name);
  }

  /// Get app title based on mode
  static Future<String> getAppTitle() async {
    final prayerMode = await isPrayerModeEnabled();
    return prayerMode ? 'TaskFlow Pro' : 'TaskFlow';
  }

  /// Get app subtitle based on mode
  static Future<String> getAppSubtitle() async {
    final prayerMode = await isPrayerModeEnabled();
    return prayerMode
        ? 'Prayer-Aware Task Management'
        : 'Smart Productivity App';
  }

  /// Get welcome message based on mode
  static Future<String> getWelcomeMessage() async {
    final prayerMode = await isPrayerModeEnabled();
    return prayerMode
        ? 'Manage your tasks with prayer times'
        : 'Stay productive and organized';
  }

  /// Clear all preferences (use with caution)
  static Future<void> clearAllPreferences() async {
    await StorageHelper.saveString(_prayerModeKey, 'false');
    await StorageHelper.saveString(_onboardingCompletedKey, 'false');
    await StorageHelper.saveString(_userDisplayNameKey, '');
  }
}
