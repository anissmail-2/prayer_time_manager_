import '../models/task.dart';

class PrayerDuration {
  final PrayerName prayer;
  final int minutesBefore; // Minutes before actual prayer time to start
  final int minutesAfter;  // Minutes after actual prayer time to end
  
  PrayerDuration({
    required this.prayer,
    required this.minutesBefore,
    required this.minutesAfter,
  });
  
  // Total duration in minutes
  int get totalDuration => minutesBefore + minutesAfter;
  
  Map<String, dynamic> toJson() {
    return {
      'prayer': prayer.index,
      'minutesBefore': minutesBefore,
      'minutesAfter': minutesAfter,
    };
  }
  
  factory PrayerDuration.fromJson(Map<String, dynamic> json) {
    return PrayerDuration(
      prayer: PrayerName.values[json['prayer']],
      minutesBefore: json['minutesBefore'],
      minutesAfter: json['minutesAfter'],
    );
  }
  
  PrayerDuration copyWith({
    PrayerName? prayer,
    int? minutesBefore,
    int? minutesAfter,
  }) {
    return PrayerDuration(
      prayer: prayer ?? this.prayer,
      minutesBefore: minutesBefore ?? this.minutesBefore,
      minutesAfter: minutesAfter ?? this.minutesAfter,
    );
  }
}

// Class to represent a prayer time block in the schedule
class PrayerTimeBlock {
  final PrayerName prayer;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime actualPrayerTime;
  
  PrayerTimeBlock({
    required this.prayer,
    required this.startTime,
    required this.endTime,
    required this.actualPrayerTime,
  });
  
  Duration get duration => endTime.difference(startTime);
  
  bool overlapsWithTime(DateTime time) {
    return time.isAfter(startTime) && time.isBefore(endTime);
  }
  
  bool overlapsWithRange(DateTime start, DateTime end) {
    return startTime.isBefore(end) && endTime.isAfter(start);
  }
}