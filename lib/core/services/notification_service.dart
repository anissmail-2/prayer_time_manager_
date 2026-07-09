import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../models/task.dart';
import '../helpers/permission_helper.dart';
import 'prayer_time_service.dart';
import 'todo_service.dart';

/// Local notification service for prayer times and task reminders.
///
/// Follows the app's static service pattern (no instances, no state
/// management libraries). All user preferences are persisted in
/// SharedPreferences and exposed through typed getters/setters so the
/// settings UI and tests never touch raw keys.
///
/// Scheduling model:
/// - The app has NO background fetch, so notifications are refreshed every
///   time the app opens: `main.dart` calls [initialize] followed by
///   [rescheduleAll] (fire-and-forget, guarded so a notification failure can
///   never block startup).
/// - Each refresh is idempotent: stable notification ids are used per
///   prayer/type and the relevant pending notifications are cancelled before
///   rescheduling.
/// - Tomorrow's Fajr is also scheduled so the morning notification exists
///   even if the app is not opened overnight.
///
/// Exact-alarm choice: notifications are scheduled with
/// [AndroidScheduleMode.inexactAllowWhileIdle]. This deliberately avoids the
/// SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM permissions (which Android 12+
/// restricts and app stores audit) at the cost of ~1 minute of delivery
/// inexactness — acceptable for prayer times and task reminders.
class NotificationService {
  NotificationService._();

  // ---------------------------------------------------------------------
  // Plugin + channels
  // ---------------------------------------------------------------------

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Whether the current platform supports local notifications in this app.
  /// The feature is Android-only for now (matching voice input).
  static bool get _isSupported => !kIsWeb && Platform.isAndroid;

  /// Visible for tests / debugging.
  static bool get isInitialized => _initialized;

  static const String _prayerChannelId = 'prayer_times';
  static const String _taskChannelId = 'task_reminders';

  // ---------------------------------------------------------------------
  // Notification id scheme (stable ids => idempotent rescheduling)
  // ---------------------------------------------------------------------

  /// The 5 notifiable prayers, in canonical order. Keys match the
  /// capitalized names returned by [PrayerTimeService.getPrayerTimes].
  static const List<String> prayers = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  static const int _prayerMainBase = 1000; // 1000..1004 today's prayers
  static const int _prayerPreBase = 1100; // 1100..1104 today's pre-reminders
  static const int _tomorrowFajrMainId = 1200;
  static const int _tomorrowFajrPreId = 1201;
  static const int _taskIdBase = 100000; // 100000..624287 task reminders

  static int _taskNotificationId(String taskId) =>
      _taskIdBase + (taskId.hashCode & 0x7FFFF);

  // ---------------------------------------------------------------------
  // Settings keys + defaults
  // ---------------------------------------------------------------------

  static const String _enabledKey = 'notifications_enabled';
  static const String _prayerToggleKeyPrefix = 'notifications_prayer_';
  static const String _preReminderMinutesKey =
      'notifications_pre_reminder_minutes';
  static const String _taskRemindersKey = 'notifications_task_reminders';

  /// Allowed pre-reminder values (minutes before the prayer; 0 = off).
  static const List<int> preReminderOptions = [0, 5, 10, 15, 30];
  static const int defaultPreReminderMinutes = 15;

  // ---------------------------------------------------------------------
  // Settings (SharedPreferences) — typed getters/setters
  // ---------------------------------------------------------------------

  /// Master toggle. Default OFF: notifications are strictly opt-in.
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  /// Per-prayer toggle. Defaults to ON (all prayers notify once the master
  /// toggle is enabled). [prayer] is one of [prayers] (case-insensitive).
  static Future<bool> isPrayerEnabled(String prayer) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prayerToggleKeyPrefix + prayer.toLowerCase()) ??
        true;
  }

  static Future<void> setPrayerEnabled(String prayer, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prayerToggleKeyPrefix + prayer.toLowerCase(), value);
  }

  /// Minutes before each prayer for the pre-reminder ("Dhuhr in 15
  /// minutes"). 0 disables the pre-reminder. Default 15.
  static Future<int> getPreReminderMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_preReminderMinutesKey);
    if (value == null || !preReminderOptions.contains(value)) {
      return defaultPreReminderMinutes;
    }
    return value;
  }

  static Future<void> setPreReminderMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _preReminderMinutesKey,
      preReminderOptions.contains(minutes)
          ? minutes
          : defaultPreReminderMinutes,
    );
  }

  /// Task reminders toggle. Default ON (once the master toggle is enabled).
  static Future<bool> areTaskRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_taskRemindersKey) ?? true;
  }

  static Future<void> setTaskRemindersEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_taskRemindersKey, value);
  }

  // ---------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------

  /// Initialize the plugin, notification channels, and the timezone
  /// database. Safe to call on unsupported platforms (no-op) and safe to
  /// call more than once.
  static Future<void> initialize() async {
    if (_initialized || !_isSupported) return;

    // Timezone database + local location (needed for zonedSchedule).
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      // Fall back to the timezone package default; scheduling still works
      // but may be offset if the device isn't in that zone.
      debugPrint('NotificationService: could not resolve local timezone: $e');
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    // Create channels up front so users can manage them in system settings.
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _prayerChannelId,
          'Prayer Times',
          description: 'Notifications when it is time for prayer',
          importance: Importance.high,
        ),
      );
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _taskChannelId,
          'Task Reminders',
          description: 'Reminders for scheduled tasks',
          importance: Importance.defaultImportance,
        ),
      );
    }

    _initialized = true;
  }

  /// Request the runtime notification permission (Android 13+).
  ///
  /// Goes through [PermissionHelper] — the app's single permission entry
  /// point. No exact-alarm permission is requested: see the class docs for
  /// why inexact scheduling is used instead.
  static Future<bool> requestPermission() async {
    return PermissionHelper.requestNotificationPermission();
  }

  // ---------------------------------------------------------------------
  // Scheduling
  // ---------------------------------------------------------------------

  static const NotificationDetails _prayerDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _prayerChannelId,
      'Prayer Times',
      channelDescription: 'Notifications when it is time for prayer',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static const NotificationDetails _taskDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _taskChannelId,
      'Task Reminders',
      channelDescription: 'Reminders for scheduled tasks',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  static tz.TZDateTime _zoned(DateTime local) =>
      tz.TZDateTime.from(local, tz.local);

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required NotificationDetails details,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _zoned(when),
      notificationDetails: details,
      // Inexact by design: avoids SCHEDULE_EXACT_ALARM on Android 12+.
      // Prayer times tolerate ~1 minute of inexactness.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Parse a 'HH:mm' prayer time string onto [date]. Returns null if the
  /// string is malformed.
  static DateTime? _parseTimeOnDate(String? hhmm, DateTime date) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());
    if (hour == null || minute == null) return null;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Schedule notifications for each enabled prayer still in the future
  /// today (plus tomorrow's Fajr), cancelling any previously scheduled
  /// prayer notifications first so the operation is idempotent.
  static Future<void> schedulePrayerNotificationsForToday() async {
    if (!_initialized) return;

    // Cancel all prayer-range ids (stable ids => full idempotency even if
    // toggles changed since the last schedule).
    for (var i = 0; i < prayers.length; i++) {
      await _plugin.cancel(id: _prayerMainBase + i);
      await _plugin.cancel(id: _prayerPreBase + i);
    }
    await _plugin.cancel(id: _tomorrowFajrMainId);
    await _plugin.cancel(id: _tomorrowFajrPreId);

    if (!await isEnabled()) return;

    final now = DateTime.now();
    final preMinutes = await getPreReminderMinutes();

    final todayTimes = await PrayerTimeService.getPrayerTimes();
    for (var i = 0; i < prayers.length; i++) {
      final prayer = prayers[i];
      if (!await isPrayerEnabled(prayer)) continue;

      final prayerTime = _parseTimeOnDate(todayTimes[prayer], now);
      if (prayerTime == null) continue;

      await _schedulePrayerPair(
        prayer: prayer,
        prayerTime: prayerTime,
        now: now,
        preMinutes: preMinutes,
        mainId: _prayerMainBase + i,
        preId: _prayerPreBase + i,
      );
    }

    // Also schedule tomorrow's Fajr so the morning notification exists even
    // if the app isn't opened overnight.
    if (await isPrayerEnabled('Fajr')) {
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowTimes =
          await PrayerTimeService.getPrayerTimes(date: tomorrow);
      final fajrTime = _parseTimeOnDate(tomorrowTimes['Fajr'], tomorrow);
      if (fajrTime != null) {
        await _schedulePrayerPair(
          prayer: 'Fajr',
          prayerTime: fajrTime,
          now: now,
          preMinutes: preMinutes,
          mainId: _tomorrowFajrMainId,
          preId: _tomorrowFajrPreId,
        );
      }
    }
  }

  static Future<void> _schedulePrayerPair({
    required String prayer,
    required DateTime prayerTime,
    required DateTime now,
    required int preMinutes,
    required int mainId,
    required int preId,
  }) async {
    final timeLabel =
        '${prayerTime.hour.toString().padLeft(2, '0')}:${prayerTime.minute.toString().padLeft(2, '0')}';

    if (prayerTime.isAfter(now)) {
      await _schedule(
        id: mainId,
        title: 'Time for $prayer',
        body: '$prayer — $timeLabel',
        when: prayerTime,
        details: _prayerDetails,
      );
    }

    if (preMinutes > 0) {
      final preTime = prayerTime.subtract(Duration(minutes: preMinutes));
      if (preTime.isAfter(now)) {
        await _schedule(
          id: preId,
          title: '$prayer in $preMinutes minutes',
          body: '$prayer is at $timeLabel',
          when: preTime,
          details: _prayerDetails,
        );
      }
    }
  }

  /// Schedule reminders for today's incomplete tasks that resolve to a
  /// concrete time still in the future. Previously scheduled task reminders
  /// are cancelled first (idempotent refresh).
  static Future<void> scheduleTaskRemindersForToday() async {
    if (!_initialized) return;

    // Cancel every pending notification in the task-id range. Ids derive
    // from task-id hashes, so enumerate pending requests instead of
    // recomputing ids for tasks that may have been deleted/completed.
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id >= _taskIdBase) {
        await _plugin.cancel(id: request.id);
      }
    }

    if (!await isEnabled() || !await areTaskRemindersEnabled()) return;

    final now = DateTime.now();
    final prayerTimes = await PrayerTimeService.getPrayerTimes();
    final tasks = await TodoService.getTasksForToday();

    for (final Task task in tasks) {
      if (task.isCompleted || task.isCompletedForDate(now)) continue;

      final scheduledTime =
          await TodoService.calculateTaskTime(task, prayerTimes, now);
      if (scheduledTime == null || !scheduledTime.isAfter(now)) continue;

      final timeLabel =
          '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}';
      await _schedule(
        id: _taskNotificationId(task.id),
        title: 'Task: ${task.title}',
        body: 'Scheduled at $timeLabel',
        when: scheduledTime,
        details: _taskDetails,
      );
    }
  }

  /// Refresh everything: prayer notifications and task reminders.
  ///
  /// This is the app's daily refresh mechanism — there is no background
  /// fetch, so main.dart calls this (fire-and-forget) on every launch and
  /// the settings screen calls it after every settings change. Never
  /// throws; failures are logged so callers can safely ignore the future.
  static Future<void> rescheduleAll() async {
    if (!_initialized) return;
    try {
      if (!await isEnabled()) {
        // Master toggle off: clear everything we scheduled.
        await _plugin.cancelAllPendingNotifications();
        return;
      }
      await schedulePrayerNotificationsForToday();
      await scheduleTaskRemindersForToday();
    } catch (e) {
      debugPrint('NotificationService.rescheduleAll failed: $e');
    }
  }
}
