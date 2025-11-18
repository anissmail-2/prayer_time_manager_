import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/activity.dart';

class ActivityService {
  static const String _activitiesKey = 'activities';
  static const String _lastIdKey = 'activities_last_id';

  // Get all activities
  static Future<List<Activity>> getAllActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final activitiesJson = prefs.getStringList(_activitiesKey) ?? [];
    
    return activitiesJson
        .map((json) => Activity.fromJson(jsonDecode(json)))
        .toList();
  }

  // Get activities for a specific date
  static Future<List<Activity>> getActivitiesForDate(DateTime date) async {
    final allActivities = await getAllActivities();
    
    return allActivities
        .where((activity) => activity.isOnDate(date))
        .map((activity) => activity.recurrence != ActivityRecurrence.once 
            ? activity.getInstanceForDate(date) 
            : activity)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  // Get activities for a date range
  static Future<List<ActivityWithDate>> getActivitiesForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final allActivities = await getAllActivities();
    final List<ActivityWithDate> result = [];
    
    // Iterate through each day in the range
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      for (final activity in allActivities) {
        if (activity.isOnDate(currentDate)) {
          result.add(ActivityWithDate(
            activity: activity.recurrence != ActivityRecurrence.once 
                ? activity.getInstanceForDate(currentDate) 
                : activity,
            date: currentDate,
          ));
        }
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    result.sort((a, b) => a.activity.startTime.compareTo(b.activity.startTime));
    return result;
  }

  // Get activities for today
  static Future<List<Activity>> getTodayActivities() async {
    return getActivitiesForDate(DateTime.now());
  }

  // Get upcoming activities (next 7 days)
  static Future<List<ActivityWithDate>> getUpcomingActivities() async {
    final now = DateTime.now();
    final endDate = now.add(const Duration(days: 7));
    return getActivitiesForDateRange(now, endDate);
  }

  // Create a new activity
  static Future<Activity> createActivity({
    required String title,
    String? description,
    required ActivityType type,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
    List<String>? attendees,
    String? spaceId,
    ActivityRecurrence recurrence = ActivityRecurrence.once,
    List<int>? weeklyDays,
    DateTime? recurrenceEndDate,
    String? notes,
    Map<String, dynamic>? metadata,
    bool isAllDay = false,
    String? color,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Generate ID
    final lastId = prefs.getInt(_lastIdKey) ?? 0;
    final newId = lastId + 1;
    await prefs.setInt(_lastIdKey, newId);
    
    final activity = Activity(
      id: 'activity_$newId',
      title: title,
      description: description,
      type: type,
      startTime: startTime,
      endTime: endTime,
      location: location,
      attendees: attendees,
      spaceId: spaceId,
      recurrence: recurrence,
      weeklyDays: weeklyDays,
      recurrenceEndDate: recurrenceEndDate,
      notes: notes,
      metadata: metadata,
      createdAt: DateTime.now(),
      isAllDay: isAllDay,
      color: color,
    );
    
    // Save activity
    final activities = await getAllActivities();
    activities.add(activity);
    await _saveActivities(activities);
    
    return activity;
  }

  // Update an activity
  static Future<void> updateActivity(Activity activity) async {
    final activities = await getAllActivities();
    final index = activities.indexWhere((a) => a.id == activity.id);
    
    if (index != -1) {
      activities[index] = activity.copyWith(updatedAt: DateTime.now());
      await _saveActivities(activities);
    }
  }

  // Delete an activity
  static Future<void> deleteActivity(String activityId) async {
    final activities = await getAllActivities();
    activities.removeWhere((a) => a.id == activityId);
    await _saveActivities(activities);
  }

  // Delete multiple activities
  static Future<void> deleteActivities(List<String> activityIds) async {
    final activities = await getAllActivities();
    activities.removeWhere((a) => activityIds.contains(a.id));
    await _saveActivities(activities);
  }

  // Get activities by space
  static Future<List<Activity>> getActivitiesBySpace(String spaceId) async {
    final activities = await getAllActivities();
    return activities.where((a) => a.spaceId == spaceId).toList();
  }

  // Get activities by type
  static Future<List<Activity>> getActivitiesByType(ActivityType type) async {
    final activities = await getAllActivities();
    return activities.where((a) => a.type == type).toList();
  }

  // Check for conflicts
  static Future<List<Activity>> checkConflicts(
    DateTime startTime,
    DateTime endTime, {
    String? excludeActivityId,
  }) async {
    final date = DateTime(startTime.year, startTime.month, startTime.day);
    final activities = await getActivitiesForDate(date);
    
    return activities.where((activity) {
      if (activity.id == excludeActivityId) return false;
      
      // Check if times overlap
      return (activity.startTime.isBefore(endTime) && 
              activity.endTime.isAfter(startTime));
    }).toList();
  }

  // Get total activity time for a date
  static Future<Duration> getTotalActivityTime(DateTime date) async {
    final activities = await getActivitiesForDate(date);
    Duration total = Duration.zero;
    
    for (final activity in activities) {
      total += activity.duration;
    }
    
    return total;
  }

  // Search activities
  static Future<List<Activity>> searchActivities(String query) async {
    final activities = await getAllActivities();
    final lowercaseQuery = query.toLowerCase();
    
    return activities.where((activity) {
      return activity.title.toLowerCase().contains(lowercaseQuery) ||
             (activity.description?.toLowerCase().contains(lowercaseQuery) ?? false) ||
             (activity.location?.toLowerCase().contains(lowercaseQuery) ?? false) ||
             (activity.notes?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  // Get activities with attendees
  static Future<List<Activity>> getActivitiesWithAttendee(String attendee) async {
    final activities = await getAllActivities();
    return activities.where((a) => a.attendees.contains(attendee)).toList();
  }

  // Private helper to save activities
  static Future<void> _saveActivities(List<Activity> activities) async {
    final prefs = await SharedPreferences.getInstance();
    final activitiesJson = activities.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_activitiesKey, activitiesJson);
  }

  // Export activities to JSON
  static Future<String> exportActivitiesToJson() async {
    final activities = await getAllActivities();
    return jsonEncode(activities.map((a) => a.toJson()).toList());
  }

  // Import activities from JSON
  static Future<void> importActivitiesFromJson(String json) async {
    final List<dynamic> activitiesJson = jsonDecode(json);
    final activities = activitiesJson
        .map((json) => Activity.fromJson(json as Map<String, dynamic>))
        .toList();
    await _saveActivities(activities);
  }

  // Clear all activities
  static Future<void> clearAllActivities() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activitiesKey);
    await prefs.remove(_lastIdKey);
  }
}