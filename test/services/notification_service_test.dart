import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow_pro/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Settings', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('should enable and disable prayer notifications', () async {
      // Default should be enabled
      expect(await NotificationService.isPrayerNotificationsEnabled(), true);

      // Disable
      await NotificationService.setPrayerNotificationsEnabled(false);
      expect(await NotificationService.isPrayerNotificationsEnabled(), false);

      // Enable
      await NotificationService.setPrayerNotificationsEnabled(true);
      expect(await NotificationService.isPrayerNotificationsEnabled(), true);
    });

    test('should enable and disable task notifications', () async {
      // Default should be enabled
      expect(await NotificationService.isTaskNotificationsEnabled(), true);

      // Disable
      await NotificationService.setTaskNotificationsEnabled(false);
      expect(await NotificationService.isTaskNotificationsEnabled(), false);

      // Enable
      await NotificationService.setTaskNotificationsEnabled(true);
      expect(await NotificationService.isTaskNotificationsEnabled(), true);
    });

    test('should set and get prayer notification minutes', () async {
      // Default should be 15
      expect(await NotificationService.getPrayerNotificationMinutes(), 15);

      // Set to 30
      await NotificationService.setPrayerNotificationMinutes(30);
      expect(await NotificationService.getPrayerNotificationMinutes(), 30);

      // Set to 5
      await NotificationService.setPrayerNotificationMinutes(5);
      expect(await NotificationService.getPrayerNotificationMinutes(), 5);
    });

    test('should handle invalid prayer notification minutes', () async {
      // Set valid value first
      await NotificationService.setPrayerNotificationMinutes(15);

      // Set invalid string (should fall back to default)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('prayer_notification_minutes', 'invalid');

      expect(await NotificationService.getPrayerNotificationMinutes(), 15);
    });

    test('should persist settings across restarts', () async {
      // Set custom values
      await NotificationService.setPrayerNotificationsEnabled(false);
      await NotificationService.setTaskNotificationsEnabled(false);
      await NotificationService.setPrayerNotificationMinutes(20);

      // Simulate app restart by creating new SharedPreferences instance
      final prefs = await SharedPreferences.getInstance();
      final prayerEnabled = prefs.getString('prayer_notifications_enabled');
      final taskEnabled = prefs.getString('task_notifications_enabled');
      final minutes = prefs.getString('prayer_notification_minutes');

      expect(prayerEnabled, 'false');
      expect(taskEnabled, 'false');
      expect(minutes, '20');
    });

    test('should handle missing settings gracefully', () async {
      // Clear all settings
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Should return defaults
      expect(await NotificationService.isPrayerNotificationsEnabled(), true);
      expect(await NotificationService.isTaskNotificationsEnabled(), true);
      expect(await NotificationService.getPrayerNotificationMinutes(), 15);
    });
  });

  group('NotificationService Initialization', () {
    test('should initialize without errors', () async {
      expect(() => NotificationService.initialize(), returnsNormally);
    });

    test('should handle multiple initialization calls', () async {
      await NotificationService.initialize();
      await NotificationService.initialize();
      await NotificationService.initialize();
      // Should not throw error
    });
  });
}
