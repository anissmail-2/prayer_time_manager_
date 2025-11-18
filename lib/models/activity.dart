import 'package:flutter/material.dart';

enum ActivityType {
  meeting,
  appointment,
  classSession,
  event,
  breakTime,
  meal,
  exercise,
  commute,
  personal,
  work,
  other,
}

enum ActivityRecurrence {
  once,
  daily,
  weekly,
  monthly,
}

class Activity {
  final String id;
  final String title;
  final String? description;
  final ActivityType type;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final List<String> attendees;
  final String? spaceId;
  final ActivityRecurrence recurrence;
  final List<int>? weeklyDays; // 1-7 for Mon-Sun
  final DateTime? recurrenceEndDate;
  final String? notes;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isAllDay;
  final String? color; // Hex color for custom coloring

  Activity({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.startTime,
    required this.endTime,
    this.location,
    List<String>? attendees,
    this.spaceId,
    this.recurrence = ActivityRecurrence.once,
    this.weeklyDays,
    this.recurrenceEndDate,
    this.notes,
    Map<String, dynamic>? metadata,
    required this.createdAt,
    DateTime? updatedAt,
    this.isAllDay = false,
    this.color,
  }) : attendees = attendees ?? [],
       metadata = metadata ?? {},
       updatedAt = updatedAt ?? createdAt;

  Duration get duration => endTime.difference(startTime);

  bool isOnDate(DateTime date) {
    final activityDate = DateTime(startTime.year, startTime.month, startTime.day);
    final checkDate = DateTime(date.year, date.month, date.day);
    
    if (recurrence == ActivityRecurrence.once) {
      return activityDate == checkDate;
    }
    
    // Check if date is within recurrence range
    if (checkDate.isBefore(activityDate)) return false;
    if (recurrenceEndDate != null && checkDate.isAfter(recurrenceEndDate!)) return false;
    
    switch (recurrence) {
      case ActivityRecurrence.daily:
        return true;
        
      case ActivityRecurrence.weekly:
        if (weeklyDays != null && weeklyDays!.isNotEmpty) {
          return weeklyDays!.contains(checkDate.weekday);
        }
        // If no specific days, check if it's the same day of week
        return checkDate.weekday == startTime.weekday;
        
      case ActivityRecurrence.monthly:
        // Same day of month
        return checkDate.day == startTime.day;
        
      case ActivityRecurrence.once:
        return activityDate == checkDate;
    }
  }

  // Get activity instance for a specific date
  Activity getInstanceForDate(DateTime date) {
    if (!isOnDate(date)) {
      throw ArgumentError('Activity does not occur on this date');
    }
    
    final timeDiff = startTime.hour * 60 + startTime.minute;
    final durationMinutes = duration.inMinutes;
    
    final newStart = DateTime(
      date.year,
      date.month,
      date.day,
      startTime.hour,
      startTime.minute,
    );
    
    final newEnd = newStart.add(Duration(minutes: durationMinutes));
    
    return copyWith(
      startTime: newStart,
      endTime: newEnd,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.index,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location,
      'attendees': attendees,
      'spaceId': spaceId,
      'recurrence': recurrence.index,
      'weeklyDays': weeklyDays,
      'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
      'notes': notes,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isAllDay': isAllDay,
      'color': color,
    };
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: ActivityType.values[json['type']],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      location: json['location'],
      attendees: List<String>.from(json['attendees'] ?? []),
      spaceId: json['spaceId'],
      recurrence: ActivityRecurrence.values[json['recurrence'] ?? 0],
      weeklyDays: json['weeklyDays'] != null ? List<int>.from(json['weeklyDays']) : null,
      recurrenceEndDate: json['recurrenceEndDate'] != null ? DateTime.parse(json['recurrenceEndDate']) : null,
      notes: json['notes'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      isAllDay: json['isAllDay'] ?? false,
      color: json['color'],
    );
  }

  Activity copyWith({
    String? id,
    String? title,
    String? description,
    ActivityType? type,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    List<String>? attendees,
    String? spaceId,
    ActivityRecurrence? recurrence,
    List<int>? weeklyDays,
    DateTime? recurrenceEndDate,
    String? notes,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAllDay,
    String? color,
  }) {
    return Activity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      attendees: attendees ?? this.attendees,
      spaceId: spaceId ?? this.spaceId,
      recurrence: recurrence ?? this.recurrence,
      weeklyDays: weeklyDays ?? this.weeklyDays,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isAllDay: isAllDay ?? this.isAllDay,
      color: color ?? this.color,
    );
  }

  @override
  String toString() {
    return 'Activity(id: $id, title: $title, type: $type, start: $startTime, end: $endTime)';
  }
}

// Helper class for displaying activities in lists
class ActivityWithDate {
  final Activity activity;
  final DateTime date;

  ActivityWithDate({
    required this.activity,
    required this.date,
  });
}

// Extension for activity type display
extension ActivityTypeExtension on ActivityType {
  String get displayName {
    switch (this) {
      case ActivityType.meeting:
        return 'Meeting';
      case ActivityType.appointment:
        return 'Appointment';
      case ActivityType.classSession:
        return 'Class';
      case ActivityType.event:
        return 'Event';
      case ActivityType.breakTime:
        return 'Break';
      case ActivityType.meal:
        return 'Meal';
      case ActivityType.exercise:
        return 'Exercise';
      case ActivityType.commute:
        return 'Commute';
      case ActivityType.personal:
        return 'Personal';
      case ActivityType.work:
        return 'Work';
      case ActivityType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityType.meeting:
        return Icons.groups;
      case ActivityType.appointment:
        return Icons.calendar_today;
      case ActivityType.classSession:
        return Icons.school;
      case ActivityType.event:
        return Icons.event;
      case ActivityType.breakTime:
        return Icons.coffee;
      case ActivityType.meal:
        return Icons.restaurant;
      case ActivityType.exercise:
        return Icons.fitness_center;
      case ActivityType.commute:
        return Icons.directions_car;
      case ActivityType.personal:
        return Icons.person;
      case ActivityType.work:
        return Icons.work;
      case ActivityType.other:
        return Icons.more_horiz;
    }
  }

  Color get defaultColor {
    switch (this) {
      case ActivityType.meeting:
        return Colors.blue;
      case ActivityType.appointment:
        return Colors.purple;
      case ActivityType.classSession:
        return Colors.orange;
      case ActivityType.event:
        return Colors.pink;
      case ActivityType.breakTime:
        return Colors.brown;
      case ActivityType.meal:
        return Colors.green;
      case ActivityType.exercise:
        return Colors.red;
      case ActivityType.commute:
        return Colors.grey;
      case ActivityType.personal:
        return Colors.teal;
      case ActivityType.work:
        return Colors.indigo;
      case ActivityType.other:
        return Colors.blueGrey;
    }
  }
}