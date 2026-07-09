import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow_pro/models/activity.dart';
import 'package:taskflow_pro/models/task.dart';

Task buildTask({
  TaskRecurrence recurrence = TaskRecurrence.once,
  ScheduleType scheduleType = ScheduleType.absolute,
  DateTime? createdAt,
  DateTime? absoluteTime,
  DateTime? startDate,
  DateTime? endDate,
  List<int>? weeklyDays,
  int? weeklyInterval,
  List<int>? monthlyDates,
  String? monthlyPattern,
  PrayerName? relatedPrayer,
  bool isCompleted = false,
}) {
  return Task(
    id: 't1',
    title: 'Test task',
    createdAt: createdAt ?? DateTime(2026, 1, 1, 9, 30),
    scheduleType: scheduleType,
    recurrence: recurrence,
    absoluteTime: absoluteTime,
    startDate: startDate,
    endDate: endDate,
    weeklyDays: weeklyDays,
    weeklyInterval: weeklyInterval,
    monthlyDates: monthlyDates,
    monthlyPattern: monthlyPattern,
    relatedPrayer: relatedPrayer,
    isCompleted: isCompleted,
  );
}

void main() {
  group('shouldShowOnDate - once', () {
    test('shows only on absoluteTime date when absolute', () {
      final task = buildTask(
        absoluteTime: DateTime(2026, 3, 10, 14, 0),
      );
      expect(task.shouldShowOnDate(DateTime(2026, 3, 10)), isTrue);
      expect(task.shouldShowOnDate(DateTime(2026, 3, 10, 23, 59)), isTrue);
      expect(task.shouldShowOnDate(DateTime(2026, 3, 9)), isFalse);
      expect(task.shouldShowOnDate(DateTime(2026, 3, 11)), isFalse);
    });

    test('once + prayer-relative shows only on startDate (not every day)', () {
      final task = buildTask(
        scheduleType: ScheduleType.prayerRelative,
        relatedPrayer: PrayerName.dhuhr,
        startDate: DateTime(2026, 3, 15),
      );
      expect(task.shouldShowOnDate(DateTime(2026, 3, 15)), isTrue);
      expect(task.shouldShowOnDate(DateTime(2026, 3, 16)), isFalse);
      expect(task.shouldShowOnDate(DateTime(2026, 3, 14)), isFalse);
    });

    test('once + prayer-relative without startDate falls back to createdAt', () {
      final task = buildTask(
        scheduleType: ScheduleType.prayerRelative,
        relatedPrayer: PrayerName.fajr,
        createdAt: DateTime(2026, 2, 5, 18, 45),
      );
      expect(task.shouldShowOnDate(DateTime(2026, 2, 5)), isTrue);
      expect(task.shouldShowOnDate(DateTime(2026, 2, 6)), isFalse);
    });

    test('absoluteTime takes precedence over startDate', () {
      final task = buildTask(
        absoluteTime: DateTime(2026, 4, 2, 8, 0),
        startDate: DateTime(2026, 4, 1),
      );
      expect(task.shouldShowOnDate(DateTime(2026, 4, 2)), isTrue);
      expect(task.shouldShowOnDate(DateTime(2026, 4, 1)), isFalse);
    });
  });

  group('shouldShowOnDate - daily', () {
    test('shows every day from startDate, endDate INCLUSIVE', () {
      final task = buildTask(
        recurrence: TaskRecurrence.daily,
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 10),
      );
      expect(task.shouldShowOnDate(DateTime(2026, 4, 30)), isFalse);
      expect(task.shouldShowOnDate(DateTime(2026, 5, 1)), isTrue);
      expect(task.shouldShowOnDate(DateTime(2026, 5, 5)), isTrue);
      // Final day must still show, even with a wall-clock time-of-day
      // later than the (midnight) endDate.
      expect(task.shouldShowOnDate(DateTime(2026, 5, 10, 18, 30)), isTrue);
      expect(task.shouldShowOnDate(DateTime(2026, 5, 11)), isFalse);
    });
  });

  group('shouldShowOnDate - weekly', () {
    test('honors weeklyDays', () {
      final task = buildTask(
        recurrence: TaskRecurrence.weekly,
        startDate: DateTime(2026, 6, 1), // A Monday
        weeklyDays: [DateTime.monday, DateTime.thursday],
      );
      expect(task.shouldShowOnDate(DateTime(2026, 6, 1)), isTrue); // Mon
      expect(task.shouldShowOnDate(DateTime(2026, 6, 4)), isTrue); // Thu
      expect(task.shouldShowOnDate(DateTime(2026, 6, 3)), isFalse); // Wed
      expect(task.shouldShowOnDate(DateTime(2026, 6, 8)), isTrue); // next Mon
    });

    test('falls back to startDate weekday when weeklyDays is empty', () {
      final task = buildTask(
        recurrence: TaskRecurrence.weekly,
        startDate: DateTime(2026, 6, 3), // A Wednesday
        weeklyDays: [],
      );
      expect(task.shouldShowOnDate(DateTime(2026, 6, 3)), isTrue);
      expect(task.shouldShowOnDate(DateTime(2026, 6, 10)), isTrue);
      expect(task.shouldShowOnDate(DateTime(2026, 6, 4)), isFalse);
    });

    test('honors weeklyInterval (every 2 weeks anchored on startDate)', () {
      final task = buildTask(
        recurrence: TaskRecurrence.weekly,
        startDate: DateTime(2026, 6, 1), // A Monday
        weeklyDays: [DateTime.monday],
        weeklyInterval: 2,
      );
      expect(task.shouldShowOnDate(DateTime(2026, 6, 1)), isTrue); // week 0
      expect(task.shouldShowOnDate(DateTime(2026, 6, 8)), isFalse); // week 1
      expect(task.shouldShowOnDate(DateTime(2026, 6, 15)), isTrue); // week 2
      expect(task.shouldShowOnDate(DateTime(2026, 6, 22)), isFalse); // week 3
      expect(task.shouldShowOnDate(DateTime(2026, 6, 29)), isTrue); // week 4
    });

    test('does not show before startDate', () {
      final task = buildTask(
        recurrence: TaskRecurrence.weekly,
        startDate: DateTime(2026, 6, 8), // A Monday
        weeklyDays: [DateTime.monday],
      );
      expect(task.shouldShowOnDate(DateTime(2026, 6, 1)), isFalse);
      expect(task.shouldShowOnDate(DateTime(2026, 6, 8)), isTrue);
    });
  });

  group('shouldShowOnDate - monthly', () {
    test('uses monthlyDates when provided', () {
      final task = buildTask(
        recurrence: TaskRecurrence.monthly,
        startDate: DateTime(2026, 1, 1),
        monthlyDates: [1, 15],
      );
      expect(task.shouldShowOnDate(DateTime(2026, 2, 1)), isTrue);
      expect(task.shouldShowOnDate(DateTime(2026, 2, 15)), isTrue);
      expect(task.shouldShowOnDate(DateTime(2026, 2, 16)), isFalse);
    });

    test('clamps day-31 start to last day of shorter months', () {
      final task = buildTask(
        recurrence: TaskRecurrence.monthly,
        startDate: DateTime(2026, 1, 31),
      );
      expect(task.shouldShowOnDate(DateTime(2026, 1, 31)), isTrue);
      // 2026 is not a leap year: Feb has 28 days
      expect(task.shouldShowOnDate(DateTime(2026, 2, 28)), isTrue);
      expect(task.shouldShowOnDate(DateTime(2026, 2, 27)), isFalse);
      expect(task.shouldShowOnDate(DateTime(2026, 3, 31)), isTrue);
      expect(task.shouldShowOnDate(DateTime(2026, 4, 30)), isTrue); // April
      expect(task.shouldShowOnDate(DateTime(2026, 4, 29)), isFalse);
    });

    test('clamps monthlyDates entries in shorter months', () {
      final task = buildTask(
        recurrence: TaskRecurrence.monthly,
        startDate: DateTime(2026, 1, 1),
        monthlyDates: [31],
      );
      expect(task.shouldShowOnDate(DateTime(2026, 4, 30)), isTrue);
      expect(task.shouldShowOnDate(DateTime(2026, 4, 29)), isFalse);
    });

    test('supports monthlyPattern like "first_monday" and "last_friday"', () {
      final firstMonday = buildTask(
        recurrence: TaskRecurrence.monthly,
        startDate: DateTime(2026, 1, 1),
        monthlyPattern: 'first_monday',
      );
      // June 2026: first Monday is June 1
      expect(firstMonday.shouldShowOnDate(DateTime(2026, 6, 1)), isTrue);
      expect(firstMonday.shouldShowOnDate(DateTime(2026, 6, 8)), isFalse);
      expect(firstMonday.shouldShowOnDate(DateTime(2026, 6, 2)), isFalse);

      final lastFriday = buildTask(
        recurrence: TaskRecurrence.monthly,
        startDate: DateTime(2026, 1, 1),
        monthlyPattern: 'last_friday',
      );
      // June 2026: last Friday is June 26
      expect(lastFriday.shouldShowOnDate(DateTime(2026, 6, 26)), isTrue);
      expect(lastFriday.shouldShowOnDate(DateTime(2026, 6, 19)), isFalse);
    });
  });

  group('shouldShowOnDate - yearly', () {
    test('shows on same month/day as startDate', () {
      final task = buildTask(
        recurrence: TaskRecurrence.yearly,
        startDate: DateTime(2026, 7, 4),
      );
      expect(task.shouldShowOnDate(DateTime(2026, 7, 4)), isTrue);
      expect(task.shouldShowOnDate(DateTime(2027, 7, 4)), isTrue);
      expect(task.shouldShowOnDate(DateTime(2027, 7, 5)), isFalse);
      expect(task.shouldShowOnDate(DateTime(2025, 7, 4)), isFalse); // before start
    });

    test('clamps Feb 29 anniversaries in non-leap years', () {
      final task = buildTask(
        recurrence: TaskRecurrence.yearly,
        startDate: DateTime(2024, 2, 29),
      );
      expect(task.shouldShowOnDate(DateTime(2024, 2, 29)), isTrue);
      expect(task.shouldShowOnDate(DateTime(2025, 2, 28)), isTrue);
      expect(task.shouldShowOnDate(DateTime(2028, 2, 29)), isTrue);
    });
  });

  group('shouldShowToday delegate', () {
    test('shouldShowToday() delegates to shouldShowOnDate(now)', () {
      final task = buildTask(recurrence: TaskRecurrence.daily,
          startDate: DateTime(2020, 1, 1));
      expect(task.shouldShowToday(), isTrue);
      expect(task.shouldShowToday(DateTime(2019, 12, 31)), isFalse);
    });
  });

  group('Activity recurrence', () {
    test('monthly activity clamps to last day of shorter months', () {
      final activity = Activity(
        id: 'a1',
        title: 'Pay rent',
        type: ActivityType.personal,
        startTime: DateTime(2026, 1, 31, 10, 0),
        endTime: DateTime(2026, 1, 31, 10, 30),
        recurrence: ActivityRecurrence.monthly,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(activity.isOnDate(DateTime(2026, 2, 28)), isTrue);
      expect(activity.isOnDate(DateTime(2026, 2, 27)), isFalse);
      expect(activity.isOnDate(DateTime(2026, 3, 31)), isTrue);
      expect(activity.isOnDate(DateTime(2026, 4, 30)), isTrue);
    });
  });
}
