import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow_pro/core/services/notification_service.dart';

/// Tests for NotificationService settings persistence (SharedPreferences
/// round-trip). The notification plugin itself is deliberately NOT tested —
/// on the host test platform NotificationService.initialize() is a no-op and
/// the settings API never touches the plugin.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NotificationService defaults', () {
    test('master toggle defaults to OFF (opt-in)', () async {
      expect(await NotificationService.isEnabled(), isFalse);
    });

    test('all per-prayer toggles default to ON', () async {
      for (final prayer in NotificationService.prayers) {
        expect(
          await NotificationService.isPrayerEnabled(prayer),
          isTrue,
          reason: '$prayer should default to enabled',
        );
      }
    });

    test('pre-reminder defaults to 15 minutes', () async {
      expect(
        await NotificationService.getPreReminderMinutes(),
        NotificationService.defaultPreReminderMinutes,
      );
      expect(NotificationService.defaultPreReminderMinutes, 15);
    });

    test('task reminders default to ON', () async {
      expect(await NotificationService.areTaskRemindersEnabled(), isTrue);
    });

    test('prayers list covers the 5 daily prayers', () {
      expect(
        NotificationService.prayers,
        ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'],
      );
    });
  });

  group('NotificationService persistence round-trip', () {
    test('master toggle persists', () async {
      await NotificationService.setEnabled(true);
      expect(await NotificationService.isEnabled(), isTrue);

      await NotificationService.setEnabled(false);
      expect(await NotificationService.isEnabled(), isFalse);
    });

    test('per-prayer toggles persist independently', () async {
      await NotificationService.setPrayerEnabled('Dhuhr', false);

      expect(await NotificationService.isPrayerEnabled('Dhuhr'), isFalse);
      // Other prayers remain at their default (enabled).
      expect(await NotificationService.isPrayerEnabled('Fajr'), isTrue);
      expect(await NotificationService.isPrayerEnabled('Asr'), isTrue);
      expect(await NotificationService.isPrayerEnabled('Maghrib'), isTrue);
      expect(await NotificationService.isPrayerEnabled('Isha'), isTrue);

      await NotificationService.setPrayerEnabled('Dhuhr', true);
      expect(await NotificationService.isPrayerEnabled('Dhuhr'), isTrue);
    });

    test('per-prayer toggle is case-insensitive', () async {
      await NotificationService.setPrayerEnabled('fajr', false);
      expect(await NotificationService.isPrayerEnabled('Fajr'), isFalse);
      expect(await NotificationService.isPrayerEnabled('FAJR'), isFalse);
    });

    test('pre-reminder minutes persist for all allowed options', () async {
      for (final minutes in NotificationService.preReminderOptions) {
        await NotificationService.setPreReminderMinutes(minutes);
        expect(
          await NotificationService.getPreReminderMinutes(),
          minutes,
          reason: '$minutes should round-trip',
        );
      }
    });

    test('invalid pre-reminder values fall back to the default', () async {
      await NotificationService.setPreReminderMinutes(7);
      expect(
        await NotificationService.getPreReminderMinutes(),
        NotificationService.defaultPreReminderMinutes,
      );
    });

    test('invalid stored pre-reminder value reads as the default', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_pre_reminder_minutes': 42,
      });
      expect(
        await NotificationService.getPreReminderMinutes(),
        NotificationService.defaultPreReminderMinutes,
      );
    });

    test('task reminders toggle persists', () async {
      await NotificationService.setTaskRemindersEnabled(false);
      expect(await NotificationService.areTaskRemindersEnabled(), isFalse);

      await NotificationService.setTaskRemindersEnabled(true);
      expect(await NotificationService.areTaskRemindersEnabled(), isTrue);
    });

    test('settings survive across getter calls (stored, not cached)', () async {
      await NotificationService.setEnabled(true);
      await NotificationService.setPrayerEnabled('Isha', false);
      await NotificationService.setPreReminderMinutes(30);
      await NotificationService.setTaskRemindersEnabled(false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notifications_enabled'), isTrue);
      expect(prefs.getBool('notifications_prayer_isha'), isFalse);
      expect(prefs.getInt('notifications_pre_reminder_minutes'), 30);
      expect(prefs.getBool('notifications_task_reminders'), isFalse);
    });
  });
}
