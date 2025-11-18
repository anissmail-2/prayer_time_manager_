import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow_pro/core/services/prayer_time_service.dart';

void main() {
  group('PrayerTimeService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('should get prayer times for a specific date', () async {
      final date = DateTime(2024, 1, 1);
      final prayerTimes = await PrayerTimeService.getPrayerTimesForDate(date);

      expect(prayerTimes, isNotEmpty);
      expect(prayerTimes.containsKey('fajr'), true);
      expect(prayerTimes.containsKey('dhuhr'), true);
      expect(prayerTimes.containsKey('asr'), true);
      expect(prayerTimes.containsKey('maghrib'), true);
      expect(prayerTimes.containsKey('isha'), true);
    });

    test('should get current prayer name', () async {
      final currentPrayer = await PrayerTimeService.getCurrentPrayerName();

      expect(currentPrayer, isNotNull);
      expect(['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].contains(currentPrayer), true);
    });

    test('should get next prayer name', () async {
      final nextPrayer = await PrayerTimeService.getNextPrayerName();

      expect(nextPrayer, isNotNull);
      expect(['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].contains(nextPrayer), true);
    });

    test('should parse prayer-relative time format', () async {
      final date = DateTime.now();

      // Test "before" format
      final beforeTime = await PrayerTimeService.calculatePrayerRelativeTime(
        'dhuhr_before_15',
        date,
      );
      expect(beforeTime, isNotNull);

      // Test "after" format
      final afterTime = await PrayerTimeService.calculatePrayerRelativeTime(
        'maghrib_after_10',
        date,
      );
      expect(afterTime, isNotNull);
    });

    test('should validate prayer times format', () async {
      final date = DateTime.now();
      final prayerTimes = await PrayerTimeService.getPrayerTimesForDate(date);

      // Each prayer time should be in HH:MM format
      final timeRegex = RegExp(r'^\d{2}:\d{2}$');

      prayerTimes.forEach((prayer, time) {
        expect(timeRegex.hasMatch(time), true,
            reason: '$prayer time $time should be in HH:MM format');
      });
    });

    test('should calculate time between prayers', () async {
      final date = DateTime.now();
      final prayerTimes = await PrayerTimeService.getPrayerTimesForDate(date);

      // Fajr should be before Dhuhr
      final fajrTime = _parseTime(prayerTimes['fajr']!);
      final dhuhrTime = _parseTime(prayerTimes['dhuhr']!);

      expect(dhuhrTime.isAfter(fajrTime), true);
    });

    test('should handle different date inputs', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final tomorrow = today.add(const Duration(days: 1));

      final todayTimes = await PrayerTimeService.getPrayerTimesForDate(today);
      final yesterdayTimes = await PrayerTimeService.getPrayerTimesForDate(yesterday);
      final tomorrowTimes = await PrayerTimeService.getPrayerTimesForDate(tomorrow);

      expect(todayTimes, isNotEmpty);
      expect(yesterdayTimes, isNotEmpty);
      expect(tomorrowTimes, isNotEmpty);
    });

    test('should get time until next prayer', () async {
      final timeUntilNext = await PrayerTimeService.getTimeUntilNextPrayer();

      expect(timeUntilNext, isNotNull);
      expect(timeUntilNext!.isNegative, false);
    });

    test('should handle prayer-relative calculations for all prayers', () async {
      final date = DateTime.now();
      final prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

      for (final prayer in prayers) {
        final beforeTime = await PrayerTimeService.calculatePrayerRelativeTime(
          '${prayer}_before_15',
          date,
        );
        expect(beforeTime, isNotNull,
            reason: 'Should calculate time before $prayer');

        final afterTime = await PrayerTimeService.calculatePrayerRelativeTime(
          '${prayer}_after_10',
          date,
        );
        expect(afterTime, isNotNull,
            reason: 'Should calculate time after $prayer');
      }
    });
  });
}

// Helper function to parse time string to DateTime
DateTime _parseTime(String timeStr) {
  final parts = timeStr.split(':');
  final now = DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
}
