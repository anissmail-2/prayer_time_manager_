import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskRecurrence {
  once,
  daily,
  weekly,
  monthly,
  yearly,
}

// Alias for backward compatibility
typedef RecurrenceType = TaskRecurrence;

enum TaskPriority {
  low,
  medium,
  high,
}

enum ItemType {
  task,       // Work to be done, goals to achieve
  activity,   // Things you do (exercise, hobbies)
  event,      // Happenings with specific times
  session,    // Work/study/focus blocks
  routine,    // Daily habits and rituals
  appointment,// Meetings with others
  reminder,   // Things to remember
}

enum PrayerName {
  fajr,
  sunrise,
  dhuhr,
  asr,
  maghrib,
  isha,
}

enum ScheduleType {
  absolute, // Specific time
  prayerRelative, // Before/after prayer
}

class Task {
  final String id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isCompleted;
  final TaskPriority priority;
  final ItemType itemType;
  
  // Schedule info
  final ScheduleType scheduleType;
  
  // For absolute time
  final DateTime? absoluteTime;
  final DateTime? endTime; // End time for time blocks
  
  // For prayer relative
  final PrayerName? relatedPrayer;
  final bool? isBeforePrayer; // true = before, false = after
  final int? minutesOffset; // minutes before/after prayer
  
  // For prayer relative end time
  final PrayerName? endRelatedPrayer;
  final bool? endIsBeforePrayer;
  final int? endMinutesOffset;
  
  // Recurrence
  final TaskRecurrence recurrence;
  final List<int>? weeklyDays; // 1-7 for Mon-Sun
  final DateTime? startDate; // Start date for recurring tasks
  final DateTime? endDate;
  
  // Advanced recurrence options
  final int? weeklyInterval; // Every X weeks (1, 2, 3, etc.)
  final List<int>? monthlyDates; // Specific dates in month (1-31)
  final String? monthlyPattern; // "first_monday", "last_friday", etc.
  
  // Completion tracking
  final List<DateTime> completedDates;
  
  // Time estimation
  final int? estimatedMinutes;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
    this.updatedAt,
    this.isCompleted = false,
    this.priority = TaskPriority.medium,
    this.itemType = ItemType.task,
    required this.scheduleType,
    this.absoluteTime,
    this.endTime,
    this.relatedPrayer,
    this.isBeforePrayer,
    this.minutesOffset,
    this.endRelatedPrayer,
    this.endIsBeforePrayer,
    this.endMinutesOffset,
    required this.recurrence,
    this.weeklyDays,
    this.startDate,
    this.endDate,
    this.weeklyInterval,
    this.monthlyDates,
    this.monthlyPattern,
    List<DateTime>? completedDates,
    this.estimatedMinutes,
  }) : completedDates = completedDates ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String() ?? createdAt.toIso8601String(),
      'isCompleted': isCompleted,
      'priority': priority.index,
      'itemType': itemType.index,
      'scheduleType': scheduleType.index,
      'absoluteTime': absoluteTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'relatedPrayer': relatedPrayer?.index,
      'isBeforePrayer': isBeforePrayer,
      'minutesOffset': minutesOffset,
      'endRelatedPrayer': endRelatedPrayer?.index,
      'endIsBeforePrayer': endIsBeforePrayer,
      'endMinutesOffset': endMinutesOffset,
      'recurrence': recurrence.index,
      'weeklyDays': weeklyDays,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'weeklyInterval': weeklyInterval,
      'monthlyDates': monthlyDates,
      'monthlyPattern': monthlyPattern,
      'completedDates': completedDates.map((d) => d.toIso8601String()).toList(),
      'estimatedMinutes': estimatedMinutes,
    };
  }

  // Helper method to parse dates from either String or Timestamp
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.parse(value);
    } else if (value is DateTime) {
      return value;
    }
    return null;
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']),
      isCompleted: json['isCompleted'] ?? false,
      priority: TaskPriority.values[json['priority'] ?? TaskPriority.medium.index],
      itemType: ItemType.values[json['itemType'] ?? ItemType.task.index],
      scheduleType: ScheduleType.values[json['scheduleType']],
      absoluteTime: _parseDateTime(json['absoluteTime']),
      endTime: _parseDateTime(json['endTime']),
      relatedPrayer: json['relatedPrayer'] != null 
          ? PrayerName.values[json['relatedPrayer']] 
          : null,
      isBeforePrayer: json['isBeforePrayer'],
      minutesOffset: json['minutesOffset'],
      endRelatedPrayer: json['endRelatedPrayer'] != null 
          ? PrayerName.values[json['endRelatedPrayer']] 
          : null,
      endIsBeforePrayer: json['endIsBeforePrayer'],
      endMinutesOffset: json['endMinutesOffset'],
      recurrence: TaskRecurrence.values[json['recurrence'] ?? json['recurrenceType'] ?? 0],
      weeklyDays: json['weeklyDays'] != null 
          ? List<int>.from(json['weeklyDays']) 
          : null,
      startDate: _parseDateTime(json['startDate']),
      endDate: _parseDateTime(json['endDate']),
      weeklyInterval: json['weeklyInterval'],
      monthlyDates: json['monthlyDates'] != null 
          ? List<int>.from(json['monthlyDates']) 
          : null,
      monthlyPattern: json['monthlyPattern'],
      completedDates: (json['completedDates'] as List<dynamic>?)
          ?.map((d) => _parseDateTime(d))
          .where((d) => d != null)
          .cast<DateTime>()
          .toList() ?? [],
      estimatedMinutes: json['estimatedMinutes'],
    );
  }

  // Empty constructor for cases where task is not found
  factory Task.empty() {
    return Task(
      id: '',
      title: '',
      createdAt: DateTime.now(),
      scheduleType: ScheduleType.absolute,
      recurrence: TaskRecurrence.once,
      priority: TaskPriority.medium,
    );
  }
  
  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isCompleted,
    TaskPriority? priority,
    ItemType? itemType,
    ScheduleType? scheduleType,
    DateTime? absoluteTime,
    DateTime? endTime,
    PrayerName? relatedPrayer,
    bool? isBeforePrayer,
    int? minutesOffset,
    PrayerName? endRelatedPrayer,
    bool? endIsBeforePrayer,
    int? endMinutesOffset,
    TaskRecurrence? recurrence,
    List<int>? weeklyDays,
    DateTime? startDate,
    DateTime? endDate,
    int? weeklyInterval,
    List<int>? monthlyDates,
    String? monthlyPattern,
    List<DateTime>? completedDates,
    int? estimatedMinutes,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      itemType: itemType ?? this.itemType,
      scheduleType: scheduleType ?? this.scheduleType,
      absoluteTime: absoluteTime ?? this.absoluteTime,
      endTime: endTime ?? this.endTime,
      relatedPrayer: relatedPrayer ?? this.relatedPrayer,
      isBeforePrayer: isBeforePrayer ?? this.isBeforePrayer,
      minutesOffset: minutesOffset ?? this.minutesOffset,
      endRelatedPrayer: endRelatedPrayer ?? this.endRelatedPrayer,
      endIsBeforePrayer: endIsBeforePrayer ?? this.endIsBeforePrayer,
      endMinutesOffset: endMinutesOffset ?? this.endMinutesOffset,
      recurrence: recurrence ?? this.recurrence,
      weeklyDays: weeklyDays ?? this.weeklyDays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      weeklyInterval: weeklyInterval ?? this.weeklyInterval,
      monthlyDates: monthlyDates ?? this.monthlyDates,
      monthlyPattern: monthlyPattern ?? this.monthlyPattern,
      completedDates: completedDates ?? this.completedDates,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    );
  }


  // Check if task should show today (thin delegate to shouldShowOnDate)
  bool shouldShowToday([DateTime? date]) {
    return shouldShowOnDate(date ?? DateTime.now());
  }

  /// Authoritative recurrence check: should this task appear on [date]?
  /// All comparisons are date-only (time of day is ignored) and
  /// [endDate] is INCLUSIVE — a task still shows on its final day.
  bool shouldShowOnDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);

    // End date is inclusive (date-only comparison)
    if (endDate != null) {
      final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (day.isAfter(end)) return false;
    }

    // Effective start date (date-only)
    final effectiveStart = startDate ?? createdAt;
    final start = DateTime(
      effectiveStart.year,
      effectiveStart.month,
      effectiveStart.day,
    );

    switch (recurrence) {
      case TaskRecurrence.once:
        // One-time tasks show on exactly one day:
        // absoluteTime's date, else startDate's date, else createdAt's date.
        // (This also covers once + prayer-relative tasks.)
        final anchor = absoluteTime ?? startDate ?? createdAt;
        return isSameDay(anchor, day);

      case TaskRecurrence.daily:
        return !day.isBefore(start);

      case TaskRecurrence.weekly:
        if (day.isBefore(start)) return false;
        // Honor weeklyInterval (every N weeks), anchored on the week
        // containing the start date (weeks begin on Monday).
        final interval = weeklyInterval ?? 1;
        if (interval > 1) {
          final startWeek = start.subtract(Duration(days: start.weekday - 1));
          final weeksDiff = day.difference(startWeek).inDays ~/ 7;
          if (weeksDiff % interval != 0) return false;
        }
        if (weeklyDays != null && weeklyDays!.isNotEmpty) {
          return weeklyDays!.contains(day.weekday);
        }
        // Fall back to the start date's weekday
        return day.weekday == start.weekday;

      case TaskRecurrence.monthly:
        if (day.isBefore(start)) return false;
        final lastDayOfMonth = DateTime(day.year, day.month + 1, 0).day;
        // Specific dates in the month (clamped to short months)
        if (monthlyDates != null && monthlyDates!.isNotEmpty) {
          return monthlyDates!
              .any((d) => (d > lastDayOfMonth ? lastDayOfMonth : d) == day.day);
        }
        // Pattern like "first_monday" / "last friday"
        if (monthlyPattern != null && monthlyPattern!.isNotEmpty) {
          return _matchesMonthlyPattern(day);
        }
        // Default: same day of month as start date, clamped so a task on
        // the 31st still shows on the last day of shorter months.
        final target =
            start.day > lastDayOfMonth ? lastDayOfMonth : start.day;
        return day.day == target;

      case TaskRecurrence.yearly:
        if (day.isBefore(start)) return false;
        if (day.month != start.month) return false;
        // Clamp for Feb 29 anniversaries in non-leap years
        final lastDayOfMonth = DateTime(day.year, start.month + 1, 0).day;
        final target =
            start.day > lastDayOfMonth ? lastDayOfMonth : start.day;
        return day.day == target;
    }
  }

  /// Matches patterns like "first_monday", "second tuesday", "last_friday".
  bool _matchesMonthlyPattern(DateTime day) {
    final parts =
        monthlyPattern!.toLowerCase().trim().split(RegExp(r'[_\s]+'));
    if (parts.length != 2) return false;

    const weekdayNames = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    final weekday = weekdayNames[parts[1]];
    if (weekday == null || day.weekday != weekday) return false;

    if (parts[0] == 'last') {
      final lastDayOfMonth = DateTime(day.year, day.month + 1, 0).day;
      return day.day > lastDayOfMonth - 7;
    }

    const ordinals = {
      'first': 1,
      'second': 2,
      'third': 3,
      'fourth': 4,
      'fifth': 5,
    };
    final ordinal = ordinals[parts[0]];
    if (ordinal == null) return false;
    return ((day.day - 1) ~/ 7) + 1 == ordinal;
  }

  // Check if task is completed for a specific date
  bool isCompletedForDate(DateTime date) {
    return completedDates.any((d) => isSameDay(d, date));
  }
  
  // Check if task is completed today
  bool isCompletedToday() {
    final today = DateTime.now();
    return isCompletedForDate(today);
  }
  
  // Get display time as DateTime (returns null if no time set)
  DateTime? getDisplayTime(Map<String, String>? prayerTimes) {
    if (scheduleType == ScheduleType.absolute && absoluteTime != null) {
      return absoluteTime;
    } else if (scheduleType == ScheduleType.prayerRelative && 
               relatedPrayer != null && 
               prayerTimes != null) {
      // Calculate prayer relative time
      final today = DateTime.now();
      final prayerKey = relatedPrayer.toString().split('.').last;
      final prayerTimeStr = prayerTimes[prayerKey.substring(0, 1).toUpperCase() + prayerKey.substring(1)];
      
      if (prayerTimeStr != null) {
        final parts = prayerTimeStr.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour != null && minute != null) {
            var prayerTime = DateTime(today.year, today.month, today.day, hour, minute);
            final offset = minutesOffset ?? 0;
            
            if (isBeforePrayer == true) {
              return prayerTime.subtract(Duration(minutes: offset));
            } else {
              return prayerTime.add(Duration(minutes: offset));
            }
          }
        }
      }
    }
    return null;
  }
  
  // Get display time as formatted string
  String getDisplayTimeString(Map<String, String>? prayerTimes) {
    final time = getDisplayTime(prayerTimes);
    if (time != null) {
      return DateFormat('h:mm a').format(time);
    }
    
    if (scheduleType == ScheduleType.prayerRelative && relatedPrayer != null) {
      final prayerKey = relatedPrayer.toString().split('.').last;
      final offset = minutesOffset ?? 0;
      final beforeAfter = isBeforePrayer == true ? 'before' : 'after';
      return '$offset min $beforeAfter $prayerKey';
    }
    
    return 'No time set';
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}