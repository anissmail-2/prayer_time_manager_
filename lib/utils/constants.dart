/// App Constants
/// Central place for all app configuration
library;

class AppConstants {
  // App Information
  static const String appName = 'Prayer Time Manager';
  static const String appVersion = '1.0.0';
  
  // Location Settings
  static const String defaultCity = 'Abu Dhabi';
  static const String defaultCountry = 'UAE';
  
  // Prayer Calculation Method
  // 16 = Dubai method with tune parameters (0,1,-3,0,1,1,0,0,0)
  // This gives accurate times for Abu Dhabi matching official mosque timings
  static const int calculationMethod = 16;
  
  // Prayer Names
  static const List<String> prayerNames = [
    'Fajr',
    'Sunrise',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];
  
  // Notification Settings
  static const String notificationChannelId = 'prayer_time_channel';
  static const String notificationChannelName = 'Prayer Time Notifications';
  static const String notificationChannelDesc = 'Notifications for prayer times';
  
  // Storage Keys (for SharedPreferences when implemented)
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keySelectedCity = 'selected_city';
  static const String keySelectedCountry = 'selected_country';
  static const String keyCalculationMethod = 'calculation_method';
  static const String keyNotificationSound = 'notification_sound';
  
  // API Endpoints
  static const String aladhanApiBase = 'https://api.aladhan.com/v1';
  
  // Time Format
  static const String timeFormat24 = 'HH:mm';
  static const String timeFormat12 = 'hh:mm a';
  static const String dateFormat = 'dd-MM-yyyy';
  
  // Theme Colors (you can expand this)
  static const int primaryColorValue = 0xFF009688; // Teal
  
  // Asset Paths (for future use)
  static const String assetIconsPath = 'assets/icons/';
  static const String assetSoundsPath = 'assets/sounds/';
  static const String assetImagesPath = 'assets/images/';
}