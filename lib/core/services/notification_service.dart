import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../helpers/storage_helper.dart';
import '../helpers/analytics_helper.dart';
import 'prayer_time_service.dart';
import '../../models/task.dart';
import '../../models/enhanced_task.dart';

/// Service for managing local notifications
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize timezone database
      tz.initializeTimeZones();

      // Set local timezone (Abu Dhabi / UAE)
      tz.setLocalLocation(tz.getLocation('Asia/Dubai'));

      // Android initialization settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Combined initialization settings
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize plugin
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _initialized = true;

      if (kDebugMode) {
        print('✅ Notification service initialized');
      }

      // Request permissions
      await requestPermissions();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize notifications: $e');
      }
    }
  }

  /// Request notification permissions
  static Future<bool> requestPermissions() async {
    try {
      // Android 13+ requires runtime permission
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? granted = await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }

      // iOS permissions
      final DarwinFlutterLocalNotificationsPlugin? iosImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              DarwinFlutterLocalNotificationsPlugin>();

      if (iosImplementation != null) {
        final bool? granted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to request notification permissions: $e');
      }
      return false;
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('📲 Notification tapped: ${response.payload}');
    }

    // Analytics
    AnalyticsHelper.logEvent(
      name: 'notification_tapped',
      parameters: {'payload': response.payload ?? 'none'},
    );

    // TODO: Navigate to relevant screen based on payload
  }

  /// Schedule prayer time notifications for today
  static Future<void> schedulePrayerNotifications() async {
    if (!_initialized) await initialize();

    try {
      final enabled = await isPrayerNotificationsEnabled();
      if (!enabled) return;

      final prayerTimes = await PrayerTimeService.getPrayerTimesForDate(
        DateTime.now(),
      );

      final prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
      final minutesBefore = await getPrayerNotificationMinutes();

      for (final prayer in prayers) {
        final timeStr = prayerTimes[prayer];
        if (timeStr == null) continue;

        final prayerTime = _parseTimeString(timeStr);
        if (prayerTime == null) continue;

        // Schedule notification X minutes before prayer
        final notificationTime = prayerTime.subtract(
          Duration(minutes: minutesBefore),
        );

        if (notificationTime.isAfter(DateTime.now())) {
          await _scheduleNotification(
            id: _getPrayerNotificationId(prayer),
            title: '🕌 ${_capitalizePrayer(prayer)} Prayer Time',
            body: 'Prayer time in $minutesBefore minutes at ${_formatTime(prayerTime)}',
            scheduledTime: notificationTime,
            payload: 'prayer_$prayer',
          );
        }
      }

      if (kDebugMode) {
        print('✅ Prayer notifications scheduled');
      }

      await AnalyticsHelper.logEvent(name: 'prayer_notifications_scheduled');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to schedule prayer notifications: $e');
      }
    }
  }

  /// Schedule task reminder notification
  static Future<void> scheduleTaskReminder({
    required Task task,
    DateTime? reminderTime,
  }) async {
    if (!_initialized) await initialize();

    try {
      final enabled = await isTaskNotificationsEnabled();
      if (!enabled) return;

      final time = reminderTime ?? _getDefaultTaskReminderTime(task);
      if (time == null || time.isBefore(DateTime.now())) return;

      await _scheduleNotification(
        id: _getTaskNotificationId(task.id),
        title: '✅ Task Reminder: ${task.title}',
        body: task.description ?? 'You have a task scheduled',
        scheduledTime: time,
        payload: 'task_${task.id}',
      );

      if (kDebugMode) {
        print('✅ Task reminder scheduled for ${task.title}');
      }

      await AnalyticsHelper.logEvent(
        name: 'task_notification_scheduled',
        parameters: {'task_id': task.id},
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to schedule task reminder: $e');
      }
    }
  }

  /// Cancel task reminder notification
  static Future<void> cancelTaskReminder(String taskId) async {
    try {
      await _notifications.cancel(_getTaskNotificationId(taskId));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to cancel task reminder: $e');
      }
    }
  }

  /// Cancel all prayer notifications
  static Future<void> cancelPrayerNotifications() async {
    try {
      final prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
      for (final prayer in prayers) {
        await _notifications.cancel(_getPrayerNotificationId(prayer));
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to cancel prayer notifications: $e');
      }
    }
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      if (kDebugMode) {
        print('✅ All notifications canceled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to cancel all notifications: $e');
      }
    }
  }

  /// Show immediate notification (for testing)
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'general',
        'General Notifications',
        channelDescription: 'General app notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to show notification: $e');
      }
    }
  }

  // ========== Private Helper Methods ==========

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'scheduled',
        'Scheduled Notifications',
        channelDescription: 'Prayer times and task reminders',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to schedule notification: $e');
      }
    }
  }

  static int _getPrayerNotificationId(String prayer) {
    final prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    return 1000 + prayers.indexOf(prayer);
  }

  static int _getTaskNotificationId(String taskId) {
    return 2000 + (taskId.hashCode % 10000);
  }

  static DateTime? _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final now = DateTime.now();
      return DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    } catch (e) {
      return null;
    }
  }

  static String _capitalizePrayer(String prayer) {
    return prayer[0].toUpperCase() + prayer.substring(1);
  }

  static String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  static DateTime? _getDefaultTaskReminderTime(Task task) {
    if (task.scheduleType == ScheduleType.absolute && task.absoluteTime != null) {
      // Remind 15 minutes before task
      return task.absoluteTime!.subtract(const Duration(minutes: 15));
    }
    // For prayer-relative tasks, we'd need to calculate actual time first
    return null;
  }

  // ========== Settings Methods ==========

  static const _prayerNotificationsKey = 'prayer_notifications_enabled';
  static const _taskNotificationsKey = 'task_notifications_enabled';
  static const _prayerNotificationMinutesKey = 'prayer_notification_minutes';

  static Future<bool> isPrayerNotificationsEnabled() async {
    final value = await StorageHelper.getString(_prayerNotificationsKey);
    return value != 'false'; // Default to true
  }

  static Future<void> setPrayerNotificationsEnabled(bool enabled) async {
    await StorageHelper.saveString(_prayerNotificationsKey, enabled.toString());
    if (enabled) {
      await schedulePrayerNotifications();
    } else {
      await cancelPrayerNotifications();
    }
  }

  static Future<bool> isTaskNotificationsEnabled() async {
    final value = await StorageHelper.getString(_taskNotificationsKey);
    return value != 'false'; // Default to true
  }

  static Future<void> setTaskNotificationsEnabled(bool enabled) async {
    await StorageHelper.saveString(_taskNotificationsKey, enabled.toString());
  }

  static Future<int> getPrayerNotificationMinutes() async {
    final value = await StorageHelper.getString(_prayerNotificationMinutesKey);
    return int.tryParse(value ?? '15') ?? 15;
  }

  static Future<void> setPrayerNotificationMinutes(int minutes) async {
    await StorageHelper.saveString(_prayerNotificationMinutesKey, minutes.toString());
    // Reschedule with new timing
    await schedulePrayerNotifications();
  }
}
