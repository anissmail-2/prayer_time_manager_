import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow_pro/core/helpers/storage_helper.dart';
import 'package:taskflow_pro/core/services/prayer_duration_service.dart';
import 'package:taskflow_pro/core/services/prayer_time_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, int> adjustments({int fajr = 0, int isha = 0}) => {
        'fajr': fajr,
        'sunrise': 0,
        'dhuhr': 0,
        'asr': 0,
        'maghrib': 0,
        'isha': isha,
      };

  group('Adjustment application', () {
    test('applies configured offsets to raw timings', () {
      final raw = {'Fajr': '05:30', 'Dhuhr': '12:30'};
      final adjusted = PrayerTimeService.applyAdjustmentsToTimings(raw, adjustments(fajr: 5));

      expect(adjusted['Fajr'], equals('05:35'));
      expect(adjusted['Dhuhr'], equals('12:30'));
      // Input map must not be mutated
      expect(raw['Fajr'], equals('05:30'));
    });

    test('is NOT idempotent — applying twice doubles the offset (why the cache must stay raw)', () {
      final raw = {'Fajr': '05:30'};
      final once = PrayerTimeService.applyAdjustmentsToTimings(raw, adjustments(fajr: 5));
      final twice = PrayerTimeService.applyAdjustmentsToTimings(once, adjustments(fajr: 5));

      expect(once['Fajr'], equals('05:35'));
      expect(twice['Fajr'], equals('05:40')); // double application = bug the raw-cache convention prevents
    });

    test('handles midnight wrap-around in both directions', () {
      final forward = PrayerTimeService.applyAdjustmentsToTimings({'Isha': '23:55'}, adjustments(isha: 10));
      expect(forward['Isha'], equals('00:05'));

      final backward = PrayerTimeService.applyAdjustmentsToTimings({'Fajr': '00:05'}, adjustments(fajr: -10));
      expect(backward['Fajr'], equals('23:55'));
    });

    test('leaves unparseable values unchanged', () {
      final adjusted = PrayerTimeService.applyAdjustmentsToTimings({'Fajr': 'N/A'}, adjustments(fajr: 5));
      expect(adjusted['Fajr'], equals('N/A'));
    });
  });

  group('Cache date validation (StorageHelper)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Map<String, dynamic> prayerData(String gregorianDate) => {
          'timings': {'Fajr': '05:30', 'Dhuhr': '12:30'},
          'date': {
            'gregorian': {'date': gregorianDate}
          },
          'meta': {'timezone': 'Asia/Dubai'},
        };

    test('formatDateKey produces DD-MM-YYYY', () {
      expect(StorageHelper.formatDateKey(DateTime(2026, 7, 9)), equals('09-07-2026'));
      expect(StorageHelper.formatDateKey(DateTime(2026, 11, 25)), equals('25-11-2026'));
    });

    test('normalizeDateKey handles canonical, legacy toString, and garbage formats', () {
      expect(StorageHelper.normalizeDateKey('09-07-2026'), equals('09-07-2026'));
      // Legacy: DateTime.toString() used to be stored by the local-calc path
      expect(StorageHelper.normalizeDateKey(DateTime(2026, 7, 9).toString()), equals('09-07-2026'));
      expect(StorageHelper.normalizeDateKey('not a date'), isNull);
      expect(StorageHelper.normalizeDateKey(null), isNull);
    });

    test('cache saved for today is valid for today', () async {
      final today = DateTime.now();
      await StorageHelper.savePrayerTimes(prayerData(StorageHelper.formatDateKey(today)));

      expect(await StorageHelper.isCachedDataForToday(), isTrue);
      expect(await StorageHelper.isCachedDataForDate(today), isTrue);
    });

    test('stale cache (yesterday) is NOT valid for today', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await StorageHelper.savePrayerTimes(prayerData(StorageHelper.formatDateKey(yesterday)));

      expect(await StorageHelper.isCachedDataForToday(), isFalse);
      expect(await StorageHelper.isCachedDataForDate(yesterday), isTrue);
    });

    test('legacy DateTime.toString() cached date is normalized and validated', () async {
      final today = DateTime.now();
      await StorageHelper.savePrayerTimes(prayerData(DateTime(today.year, today.month, today.day).toString()));

      expect(await StorageHelper.isCachedDataForToday(), isTrue);
    });

    test('per-date cache round trip', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final key = StorageHelper.formatDateKey(tomorrow);
      await StorageHelper.savePrayerTimesForDate(key, prayerData(key));

      final cached = await StorageHelper.getCachedPrayerTimesForDate(key);
      expect(cached, isNotNull);
      expect(cached!['timings']['Fajr'], equals('05:30'));

      // Different date has no entry
      final other = StorageHelper.formatDateKey(DateTime.now().add(const Duration(days: 2)));
      expect(await StorageHelper.getCachedPrayerTimesForDate(other), isNull);
    });

    test('savePrayerTimes also populates the per-date cache', () async {
      final today = DateTime.now();
      final key = StorageHelper.formatDateKey(today);
      await StorageHelper.savePrayerTimes(prayerData(key));

      final cached = await StorageHelper.getCachedPrayerTimesForDate(key);
      expect(cached, isNotNull);
      expect(cached!['timings']['Dhuhr'], equals('12:30'));
    });

    test('old per-date entries are pruned on save', () async {
      final prefs = await SharedPreferences.getInstance();
      final oldDate = DateTime.now().subtract(const Duration(days: 40));
      final oldKey = StorageHelper.formatDateKey(oldDate);
      await prefs.setString('cached_prayer_times_$oldKey', json.encode(prayerData(oldKey)));

      // Saving a fresh entry triggers pruning of the 40-day-old one
      final todayKey = StorageHelper.formatDateKey(DateTime.now());
      await StorageHelper.savePrayerTimesForDate(todayKey, prayerData(todayKey));

      expect(await StorageHelper.getCachedPrayerTimesForDate(oldKey), isNull);
      expect(await StorageHelper.getCachedPrayerTimesForDate(todayKey), isNotNull);
    });

    test('clearCache removes legacy and per-date entries', () async {
      final key = StorageHelper.formatDateKey(DateTime.now());
      await StorageHelper.savePrayerTimes(prayerData(key));
      await StorageHelper.clearCache();

      expect(await StorageHelper.getCachedPrayerTimes(), isNull);
      expect(await StorageHelper.getCachedPrayerTimesForDate(key), isNull);
      expect(await StorageHelper.isCachedDataForToday(), isFalse);
    });
  });

  group('Raw caching + single adjustment application (local calculation, no network)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'location_settings': json.encode({
          'useGPS': false,
          'customCity': 'Abu Dhabi',
          'customCountry': 'United Arab Emirates',
          'latitude': 24.4539,
          'longitude': 54.3773,
          // Unknown timezone string -> service assumes it matches the device
          // timezone, so the offline local Adhan calculation path is used
          // deterministically (no HTTP in tests).
          'timezone': 'Test/Unknown',
          'calculationMethod': 16,
          'prayerAdjustments': {
            'fajr': 5,
            'sunrise': 0,
            'dhuhr': 0,
            'asr': 0,
            'maghrib': 0,
            'isha': 0,
          },
        }),
      });
    });

    test('cache stores RAW timings; returned timings have adjustments applied once', () async {
      final result = await PrayerTimeService.getTodayPrayerTimes();
      expect(result['success'], isTrue);

      final cached = await StorageHelper.getCachedPrayerTimes();
      expect(cached, isNotNull);

      final rawFajr = cached!['timings']['Fajr'] as String;
      final returnedFajr = result['timings']['Fajr'] as String;

      // Returned value = raw cached value + 5 minutes (applied exactly once)
      final expected = PrayerTimeService.applyAdjustmentsToTimings(
        {'Fajr': rawFajr},
        adjustments(fajr: 5),
      )['Fajr'];
      expect(returnedFajr, equals(expected));
      expect(returnedFajr, isNot(equals(rawFajr)));
    });

    test('repeated reads never accumulate adjustments (no double application)', () async {
      final first = await PrayerTimeService.getTodayPrayerTimes();
      final second = await PrayerTimeService.getTodayPrayerTimes();
      final third = await PrayerTimeService.getTodayPrayerTimes();

      expect(first['success'], isTrue);
      expect(second['timings']['Fajr'], equals(first['timings']['Fajr']));
      expect(third['timings']['Fajr'], equals(first['timings']['Fajr']));
    });

    test('local calculation caches a date-validated entry for today', () async {
      await PrayerTimeService.getTodayPrayerTimes();
      expect(await StorageHelper.isCachedDataForToday(), isTrue);
    });

    test('getPrayerTimesForDate caches per-date raw timings offline', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final key = StorageHelper.formatDateKey(tomorrow);

      final result = await PrayerTimeService.getPrayerTimesForDate(key);
      expect(result['success'], isTrue);

      final cached = await StorageHelper.getCachedPrayerTimesForDate(key);
      expect(cached, isNotNull);
      // Cached is raw; result has the +5 fajr adjustment applied
      expect(result['timings']['Fajr'], isNot(equals(cached!['timings']['Fajr'])));
    });
  });

  group('Free slot computation (overlapping blocks)', () {
    final day = DateTime(2026, 7, 9);
    final dayStart = DateTime(2026, 7, 9, 5, 0);
    final dayEnd = DateTime(2026, 7, 9, 23, 59);

    TimeBlock block(int startH, int startM, int endH, int endM) => TimeBlock(
          startTime: DateTime(day.year, day.month, day.day, startH, startM),
          endTime: DateTime(day.year, day.month, day.day, endH, endM),
          type: TimeBlockType.task,
          title: 'block',
        );

    test('no blocks -> single free slot covering the day', () {
      final slots = PrayerDurationService.computeFreeSlots([], dayStart, dayEnd);
      expect(slots.length, equals(1));
      expect(slots.first.startTime, equals(dayStart));
      expect(slots.first.endTime, equals(dayEnd));
    });

    test('block nested inside a previous block does not create phantom slots', () {
      // Outer block 10:00-12:00, nested block 10:30-11:00.
      // Bug: currentTime = nested.endTime moved BACKWARDS to 11:00,
      // producing a phantom 11:00-23:59 slot overlapping the outer block.
      final slots = PrayerDurationService.computeFreeSlots(
        [block(10, 0, 12, 0), block(10, 30, 11, 0)],
        dayStart,
        dayEnd,
      );

      expect(slots.length, equals(2));
      expect(slots[0].startTime, equals(dayStart));
      expect(slots[0].endTime, equals(DateTime(2026, 7, 9, 10, 0)));
      expect(slots[1].startTime, equals(DateTime(2026, 7, 9, 12, 0)));
      expect(slots[1].endTime, equals(dayEnd));

      // No slot may start inside the outer 10:00-12:00 block
      for (final slot in slots) {
        final startsInsideOuter = slot.startTime.isAfter(DateTime(2026, 7, 9, 10, 0)) &&
            slot.startTime.isBefore(DateTime(2026, 7, 9, 12, 0));
        expect(startsInsideOuter, isFalse);
      }
    });

    test('partially overlapping blocks merge correctly', () {
      final slots = PrayerDurationService.computeFreeSlots(
        [block(10, 0, 11, 0), block(10, 30, 11, 30)],
        dayStart,
        dayEnd,
      );

      expect(slots.length, equals(2));
      expect(slots[0].endTime, equals(DateTime(2026, 7, 9, 10, 0)));
      expect(slots[1].startTime, equals(DateTime(2026, 7, 9, 11, 30)));
    });

    test('gaps shorter than 15 minutes are not reported', () {
      final slots = PrayerDurationService.computeFreeSlots(
        [block(10, 0, 11, 0), block(11, 10, 12, 0)],
        dayStart,
        dayEnd,
      );

      // Only the 5:00-10:00 and 12:00-23:59 slots; the 10-minute gap is skipped
      expect(slots.length, equals(2));
      expect(slots[0].endTime, equals(DateTime(2026, 7, 9, 10, 0)));
      expect(slots[1].startTime, equals(DateTime(2026, 7, 9, 12, 0)));
    });

    test('unsorted input is handled', () {
      final slots = PrayerDurationService.computeFreeSlots(
        [block(15, 0, 16, 0), block(8, 0, 9, 0)],
        dayStart,
        dayEnd,
      );

      expect(slots.length, equals(3));
      expect(slots[0].startTime, equals(dayStart));
      expect(slots[1].startTime, equals(DateTime(2026, 7, 9, 9, 0)));
      expect(slots[2].startTime, equals(DateTime(2026, 7, 9, 16, 0)));
    });
  });
}
