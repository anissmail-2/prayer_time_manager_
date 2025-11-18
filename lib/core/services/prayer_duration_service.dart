import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/prayer_duration.dart';
import '../../models/task.dart';
import 'prayer_time_service.dart';
import 'todo_service.dart';

class PrayerDurationService {
  static const String _durationsKey = 'prayer_durations';
  static const String _dayOverridesKey = 'prayer_duration_day_overrides';
  
  // Default durations (can be customized by user)
  static final Map<PrayerName, PrayerDuration> _defaultDurations = {
    PrayerName.fajr: PrayerDuration(prayer: PrayerName.fajr, minutesBefore: 15, minutesAfter: 20),
    PrayerName.sunrise: PrayerDuration(prayer: PrayerName.sunrise, minutesBefore: 0, minutesAfter: 15),
    PrayerName.dhuhr: PrayerDuration(prayer: PrayerName.dhuhr, minutesBefore: 10, minutesAfter: 20),
    PrayerName.asr: PrayerDuration(prayer: PrayerName.asr, minutesBefore: 10, minutesAfter: 15),
    PrayerName.maghrib: PrayerDuration(prayer: PrayerName.maghrib, minutesBefore: 10, minutesAfter: 15),
    PrayerName.isha: PrayerDuration(prayer: PrayerName.isha, minutesBefore: 10, minutesAfter: 20),
  };
  
  // Get all prayer durations
  static Future<Map<PrayerName, PrayerDuration>> getAllDurations() async {
    final prefs = await SharedPreferences.getInstance();
    final durationsJson = prefs.getString(_durationsKey);
    
    if (durationsJson == null) {
      // Return defaults if not set
      return _defaultDurations;
    }
    
    final Map<String, dynamic> durationsMap = json.decode(durationsJson);
    final Map<PrayerName, PrayerDuration> result = {};
    
    durationsMap.forEach((key, value) {
      final prayerIndex = int.parse(key);
      result[PrayerName.values[prayerIndex]] = PrayerDuration.fromJson(value);
    });
    
    return result;
  }
  
  // Save all durations
  static Future<void> saveAllDurations(Map<PrayerName, PrayerDuration> durations) async {
    final prefs = await SharedPreferences.getInstance();
    
    final Map<String, dynamic> durationsMap = {};
    durations.forEach((prayer, duration) {
      durationsMap[prayer.index.toString()] = duration.toJson();
    });
    
    await prefs.setString(_durationsKey, json.encode(durationsMap));
  }
  
  // Update duration for a specific prayer
  static Future<void> updateDuration(PrayerDuration duration) async {
    final durations = await getAllDurations();
    durations[duration.prayer] = duration;
    await saveAllDurations(durations);
  }
  
  // Get day-specific override for a prayer
  static Future<PrayerDuration?> getDayOverride(PrayerName prayer, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final overridesJson = prefs.getString(_dayOverridesKey);
    
    if (overridesJson == null) return null;
    
    final Map<String, dynamic> overrides = json.decode(overridesJson);
    final dateKey = '${date.year}-${date.month}-${date.day}';
    
    if (overrides.containsKey(dateKey)) {
      final dayOverrides = overrides[dateKey] as Map<String, dynamic>;
      final prayerKey = prayer.index.toString();
      
      if (dayOverrides.containsKey(prayerKey)) {
        return PrayerDuration.fromJson(dayOverrides[prayerKey]);
      }
    }
    
    return null;
  }
  
  // Save day-specific override for a prayer
  static Future<void> saveDayOverride(PrayerName prayer, DateTime date, PrayerDuration duration) async {
    final prefs = await SharedPreferences.getInstance();
    final overridesJson = prefs.getString(_dayOverridesKey);
    
    Map<String, dynamic> overrides = {};
    if (overridesJson != null) {
      overrides = json.decode(overridesJson);
    }
    
    final dateKey = '${date.year}-${date.month}-${date.day}';
    final prayerKey = prayer.index.toString();
    
    if (!overrides.containsKey(dateKey)) {
      overrides[dateKey] = {};
    }
    
    overrides[dateKey][prayerKey] = duration.toJson();
    
    await prefs.setString(_dayOverridesKey, json.encode(overrides));
  }
  
  // Get duration for a specific prayer on a specific date (checks override first)
  static Future<PrayerDuration> getDurationForDate(PrayerName prayer, DateTime date) async {
    // Check for day-specific override first
    final override = await getDayOverride(prayer, date);
    if (override != null) {
      return override;
    }
    
    // Fall back to global setting
    final durations = await getAllDurations();
    return durations[prayer] ?? _defaultDurations[prayer]!;
  }
  
  // Get prayer time blocks for a specific date
  static Future<List<PrayerTimeBlock>> getPrayerBlocksForDate(DateTime date) async {
    final prayerTimes = await PrayerTimeService.getPrayerTimes();
    final blocks = <PrayerTimeBlock>[];
    
    for (final prayer in PrayerName.values) {
      final prayerKey = prayer.toString().split('.').last;
      final prayerTimeStr = prayerTimes[prayerKey.substring(0, 1).toUpperCase() + prayerKey.substring(1)];
      
      if (prayerTimeStr != null && prayerTimeStr != 'N/A') {
        // Parse prayer time
        final parts = prayerTimeStr.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          
          if (hour != null && minute != null) {
            final actualPrayerTime = DateTime(date.year, date.month, date.day, hour, minute);
            // Use getDurationForDate to check for day-specific overrides
            final duration = await getDurationForDate(prayer, date);
            
            final startTime = actualPrayerTime.subtract(Duration(minutes: duration.minutesBefore));
            final endTime = actualPrayerTime.add(Duration(minutes: duration.minutesAfter));
            
            blocks.add(PrayerTimeBlock(
              prayer: prayer,
              startTime: startTime,
              endTime: endTime,
              actualPrayerTime: actualPrayerTime,
            ));
          }
        }
      }
    }
    
    return blocks;
  }
  
  // Get prayer time blocks for today
  static Future<List<PrayerTimeBlock>> getTodayPrayerBlocks() async {
    return getPrayerBlocksForDate(DateTime.now());
  }
  
  // Calculate total prayer time for today
  static Future<Duration> getTotalPrayerTime() async {
    final blocks = await getTodayPrayerBlocks();
    Duration total = Duration.zero;
    
    for (final block in blocks) {
      total += block.duration;
    }
    
    return total;
  }
  
  // Get free time slots between prayer blocks and tasks
  static Future<List<FreeTimeSlot>> getFreeTimes(List<TaskWithTime> tasks) async {
    final prayerBlocks = await getTodayPrayerBlocks();
    final freeSlots = <FreeTimeSlot>[];
    final today = DateTime.now();
    
    // Create a list of all time blocks (prayers and tasks)
    final allBlocks = <TimeBlock>[];
    
    // Add prayer blocks
    for (final prayer in prayerBlocks) {
      allBlocks.add(TimeBlock(
        startTime: prayer.startTime,
        endTime: prayer.endTime,
        type: TimeBlockType.prayer,
        title: prayer.prayer.toString().split('.').last,
      ));
    }
    
    // Add task blocks (assuming tasks take 30 minutes by default)
    for (final taskWithTime in tasks) {
      allBlocks.add(TimeBlock(
        startTime: taskWithTime.scheduledTime,
        endTime: taskWithTime.scheduledTime.add(const Duration(minutes: 30)),
        type: TimeBlockType.task,
        title: taskWithTime.task.title,
      ));
    }
    
    // Sort blocks by start time
    allBlocks.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    // Find free slots between blocks
    DateTime currentTime = DateTime(today.year, today.month, today.day, 5, 0); // Start from 5 AM
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59); // End at 11:59 PM
    
    for (final block in allBlocks) {
      if (block.startTime.isAfter(currentTime)) {
        // There's a gap between current time and next block
        final duration = block.startTime.difference(currentTime);
        if (duration.inMinutes >= 15) { // Only show slots of 15 minutes or more
          freeSlots.add(FreeTimeSlot(
            startTime: currentTime,
            endTime: block.startTime,
            duration: duration,
          ));
        }
      }
      currentTime = block.endTime;
    }
    
    // Check for free time after last block
    if (currentTime.isBefore(endOfDay)) {
      final duration = endOfDay.difference(currentTime);
      if (duration.inMinutes >= 15) {
        freeSlots.add(FreeTimeSlot(
          startTime: currentTime,
          endTime: endOfDay,
          duration: duration,
        ));
      }
    }
    
    return freeSlots;
  }
}

// Helper classes
enum TimeBlockType { prayer, task, free }

class TimeBlock {
  final DateTime startTime;
  final DateTime endTime;
  final TimeBlockType type;
  final String title;
  
  TimeBlock({
    required this.startTime,
    required this.endTime,
    required this.type,
    required this.title,
  });
}

class FreeTimeSlot {
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  
  FreeTimeSlot({
    required this.startTime,
    required this.endTime,
    required this.duration,
  });
}