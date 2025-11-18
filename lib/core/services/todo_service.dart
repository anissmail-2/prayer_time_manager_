import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/task.dart';
import 'gemini_task_assistant.dart';
import 'auth_service.dart';
import 'firestore_todo_service.dart';

class TodoService {
  static const String _tasksKey = 'tasks';
  
  // Get all tasks
  static Future<List<Task>> getAllTasks() async {
    // Use Firestore when logged in
    if (AuthService.isLoggedIn) {
      try {
        return await FirestoreTodoService.getAllTasks();
      } catch (e) {
        print('Error getting tasks from Firestore: $e');
        return [];
      }
    }
    
    // Only use local storage when not logged in
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getString(_tasksKey);
    
    if (tasksJson == null) {
      return [];
    }
    
    final List<dynamic> tasksList = json.decode(tasksJson);
    return tasksList.map((taskJson) => Task.fromJson(taskJson)).toList();
  }
  
  // Save all tasks
  static Future<void> _saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = json.encode(tasks.map((task) => task.toJson()).toList());
    await prefs.setString(_tasksKey, tasksJson);
  }
  
  // Add a new task
  static Future<void> addTask(Task task) async {
    if (AuthService.isLoggedIn) {
      // Use Firestore directly when logged in
      return FirestoreTodoService.addTask(task);
    }
    
    // Only use local storage when not logged in
    final tasks = await getAllTasks();
    tasks.add(task);
    await _saveTasks(tasks);
  }
  
  // Update a task
  static Future<void> updateTask(Task updatedTask) async {
    if (AuthService.isLoggedIn) {
      // Use Firestore directly when logged in
      return FirestoreTodoService.updateTask(updatedTask);
    }
    
    // Only use local storage when not logged in
    final tasks = await getAllTasks();
    final index = tasks.indexWhere((task) => task.id == updatedTask.id);
    
    if (index != -1) {
      tasks[index] = updatedTask;
      await _saveTasks(tasks);
    }
  }
  
  // Delete a task
  static Future<void> deleteTask(String taskId) async {
    if (AuthService.isLoggedIn) {
      // Use Firestore directly when logged in
      return FirestoreTodoService.deleteTask(taskId);
    }

    // Only use local storage when not logged in
    final tasks = await getAllTasks();
    tasks.removeWhere((task) => task.id == taskId);
    await _saveTasks(tasks);
  }

  // Duplicate a task
  static Future<Task> duplicateTask(Task originalTask) async {
    // Create a copy with a new ID and reset completion status
    final duplicatedTask = originalTask.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '${originalTask.title} (Copy)',
      isCompleted: false,
      completedDates: [],
      createdAt: DateTime.now(),
    );

    await addTask(duplicatedTask);
    return duplicatedTask;
  }

  // Mark task as completed for today
  static Future<void> markTaskCompleted(String taskId, DateTime date) async {
    final tasks = await getAllTasks();
    final index = tasks.indexWhere((task) => task.id == taskId);
    
    if (index != -1) {
      final task = tasks[index];
      final updatedCompletedDates = List<DateTime>.from(task.completedDates)..add(date);
      
      // If it's a one-time task, mark it as completed
      final isCompleted = task.recurrence == TaskRecurrence.once;
      
      tasks[index] = task.copyWith(
        completedDates: updatedCompletedDates,
        isCompleted: isCompleted,
      );
      
      await _saveTasks(tasks);
    }
  }
  
  // Unmark task completion for a date
  static Future<void> unmarkTaskCompleted(String taskId, DateTime date) async {
    final tasks = await getAllTasks();
    final index = tasks.indexWhere((task) => task.id == taskId);
    
    if (index != -1) {
      final task = tasks[index];
      final updatedCompletedDates = List<DateTime>.from(task.completedDates)
        ..removeWhere((d) => Task.isSameDay(d, date));
      
      tasks[index] = task.copyWith(
        completedDates: updatedCompletedDates,
        isCompleted: false,
      );
      
      await _saveTasks(tasks);
    }
  }
  
  // Toggle task completion status
  static Future<void> toggleTaskStatus(Task task) async {
    final today = DateTime.now();
    
    if (task.recurrence == TaskRecurrence.once) {
      // For one-time tasks, toggle the isCompleted status
      await updateTask(task.copyWith(isCompleted: !task.isCompleted));
    } else {
      // For recurring tasks, toggle completion for today
      if (task.isCompletedForDate(today)) {
        await unmarkTaskCompleted(task.id, today);
      } else {
        await markTaskCompleted(task.id, today);
      }
    }
  }
  
  // Get tasks for today
  static Future<List<Task>> getTasksForToday() async {
    final tasks = await getAllTasks();
    final today = DateTime.now();
    
    return tasks.where((task) {
      // Skip completed one-time tasks
      if (task.isCompleted && task.recurrence == TaskRecurrence.once) {
        return false;
      }
      
      // Check if end date has passed
      if (task.endDate != null && today.isAfter(task.endDate!)) {
        return false;
      }
      
      return task.shouldShowToday(today);
    }).toList();
  }
  
  // Get all tasks with calculated times for today
  static Future<List<TaskWithTime>> getAllTasksWithTimes(Map<String, String> prayerTimes) async {
    return getAllTasksWithTimesForDate(prayerTimes, DateTime.now());
  }
  
  // Get all tasks with calculated times for a specific date
  static Future<List<TaskWithTime>> getAllTasksWithTimesForDate(Map<String, String> prayerTimes, DateTime date) async {
    final tasks = await getAllTasks();
    final tasksWithTimes = <TaskWithTime>[];
    
    for (final task in tasks) {
      // Check if task should show on this date
      if (!_shouldTaskShowOnDate(task, date)) {
        continue;
      }
      
      final scheduledTime = _calculateTaskTime(task, prayerTimes, date);
      if (scheduledTime != null) {
        DateTime? endTime;
        
        // Calculate end time
        if (task.scheduleType == ScheduleType.absolute && task.endTime != null) {
          // For absolute time, use the end time with the given date
          endTime = DateTime(
            date.year,
            date.month,
            date.day,
            task.endTime!.hour,
            task.endTime!.minute,
          );
        } else if (task.scheduleType == ScheduleType.prayerRelative && 
                   task.endRelatedPrayer != null) {
          // Calculate prayer-relative end time
          endTime = _calculatePrayerRelativeEndTime(task, prayerTimes, date);
        }
        
        // If no end time specified, default to 30 minutes after start
        endTime ??= scheduledTime.add(const Duration(minutes: 30));
        
        tasksWithTimes.add(TaskWithTime(
          task: task, 
          scheduledTime: scheduledTime,
          endTime: endTime,
        ));
      }
    }
    
    // Sort by time
    tasksWithTimes.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    
    return tasksWithTimes;
  }
  
  // Check if task should show on a specific date
  static bool _shouldTaskShowOnDate(Task task, DateTime date) {
    // Skip completed one-time tasks
    if (task.isCompleted && task.recurrence == TaskRecurrence.once) {
      return false;
    }
    
    // Check if end date has passed
    if (task.endDate != null && date.isAfter(task.endDate!)) {
      return false;
    }
    
    // Get the effective start date
    final effectiveStartDate = task.startDate ?? task.createdAt;
    final startDateOnly = DateTime(effectiveStartDate.year, effectiveStartDate.month, effectiveStartDate.day);
    
    // Check if date is before the task's start date
    if (date.isBefore(startDateOnly)) {
      return false;
    }
    
    // Apply recurrence rules based on task recurrence type
    switch (task.recurrence) {
      case TaskRecurrence.once:
        // For one-time tasks, only show on start/creation date
        return Task.isSameDay(effectiveStartDate, date);
      
      case TaskRecurrence.daily:
        // Show every day after start date
        return true;
      
      case TaskRecurrence.weekly:
        // If weekly interval is specified, check if it's the right week
        if (task.weeklyInterval != null && task.weeklyInterval! > 1) {
          final weeksDiff = date.difference(startDateOnly).inDays ~/ 7;
          if (weeksDiff % task.weeklyInterval! != 0) {
            return false;
          }
        }
        
        // Check if date's day of week matches any selected weekly days
        if (task.weeklyDays != null && task.weeklyDays!.isNotEmpty) {
          return task.weeklyDays!.contains(date.weekday);
        }
        // If no specific days selected, show on same weekday as start date
        return date.weekday == effectiveStartDate.weekday;
      
      case TaskRecurrence.monthly:
        // Check for specific monthly dates
        if (task.monthlyDates != null && task.monthlyDates!.isNotEmpty) {
          return task.monthlyDates!.contains(date.day);
        }
        // Default: Show on same day of month as start date
        return date.day == effectiveStartDate.day;
      
      case TaskRecurrence.yearly:
        // Show on same month and day as start date
        return date.month == effectiveStartDate.month && date.day == effectiveStartDate.day;
    }
  }
  
  // Get upcoming tasks with calculated times
  static Future<List<TaskWithTime>> getUpcomingTasksWithTimes(Map<String, String> prayerTimes) async {
    final tasks = await getTasksForToday();
    final today = DateTime.now();
    final tasksWithTimes = <TaskWithTime>[];
    
    for (final task in tasks) {
      final scheduledTime = _calculateTaskTime(task, prayerTimes, today);
      if (scheduledTime != null) {
        DateTime? endTime;
        
        // Calculate end time
        if (task.scheduleType == ScheduleType.absolute && task.endTime != null) {
          // For absolute time, use the end time with today's date
          endTime = DateTime(
            today.year,
            today.month,
            today.day,
            task.endTime!.hour,
            task.endTime!.minute,
          );
        } else if (task.scheduleType == ScheduleType.prayerRelative && 
                   task.endRelatedPrayer != null) {
          // Calculate prayer-relative end time
          endTime = _calculatePrayerRelativeEndTime(task, prayerTimes, today);
        }
        
        // If no end time specified, default to 30 minutes after start
        endTime ??= scheduledTime.add(const Duration(minutes: 30));
        
        tasksWithTimes.add(TaskWithTime(
          task: task, 
          scheduledTime: scheduledTime,
          endTime: endTime,
        ));
      }
    }
    
    // Sort by time
    tasksWithTimes.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    
    return tasksWithTimes;
  }
  
  // Calculate actual time for a task
  static DateTime? _calculatePrayerRelativeTime(Task task, Map<String, String> prayerTimes, DateTime date) {
    return _calculateTaskTime(task, prayerTimes, date);
  }
  
  // Calculate prayer-relative end time
  static DateTime? _calculatePrayerRelativeEndTime(Task task, Map<String, String> prayerTimes, DateTime date) {
    if (task.endRelatedPrayer == null) return null;
    
    // Get prayer time for end
    final prayerKey = task.endRelatedPrayer.toString().split('.').last;
    final prayerTimeStr = prayerTimes[prayerKey.substring(0, 1).toUpperCase() + prayerKey.substring(1)];
    
    if (prayerTimeStr != null) {
      // Parse prayer time (format: "HH:mm")
      final parts = prayerTimeStr.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        
        if (hour != null && minute != null) {
          var prayerTime = DateTime(date.year, date.month, date.day, hour, minute);
          
          // Apply offset
          final offset = task.endMinutesOffset ?? 0;
          if (task.endIsBeforePrayer == true) {
            prayerTime = prayerTime.subtract(Duration(minutes: offset));
          } else {
            prayerTime = prayerTime.add(Duration(minutes: offset));
          }
          
          return prayerTime;
        }
      }
    }
    
    return null;
  }
  
  // Public method to calculate task time (for use in timeline)
  static Future<DateTime?> calculateTaskTime(Task task, Map<String, String> prayerTimes, DateTime date) async {
    return _calculateTaskTime(task, prayerTimes, date);
  }
  
  static DateTime? _calculateTaskTime(Task task, Map<String, String> prayerTimes, DateTime date) {
    if (task.scheduleType == ScheduleType.absolute && task.absoluteTime != null) {
      // For absolute time, use the time portion with today's date
      return DateTime(
        date.year,
        date.month,
        date.day,
        task.absoluteTime!.hour,
        task.absoluteTime!.minute,
      );
    } else if (task.scheduleType == ScheduleType.prayerRelative && 
               task.relatedPrayer != null && 
               prayerTimes.isNotEmpty) {
      // Get prayer time
      final prayerKey = task.relatedPrayer.toString().split('.').last;
      final prayerTimeStr = prayerTimes[prayerKey.substring(0, 1).toUpperCase() + prayerKey.substring(1)];
      
      if (prayerTimeStr != null) {
        // Parse prayer time (format: "HH:mm")
        final parts = prayerTimeStr.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          
          if (hour != null && minute != null) {
            var prayerTime = DateTime(date.year, date.month, date.day, hour, minute);
            
            // Apply offset
            final offset = task.minutesOffset ?? 0;
            if (task.isBeforePrayer == true) {
              prayerTime = prayerTime.subtract(Duration(minutes: offset));
            } else {
              prayerTime = prayerTime.add(Duration(minutes: offset));
            }
            
            return prayerTime;
          }
        }
      }
    }
    
    return null;
  }
  
  // Create task from suggestion
  static Future<void> createTaskFromSuggestion(TaskSuggestion suggestion) async {
    final now = DateTime.now();
    DateTime? absoluteTime;
    DateTime? endTime;
    
    // Determine the base date for the task
    DateTime baseDate = now;
    if (suggestion.taskDate != null) {
      if (suggestion.taskDate!.toLowerCase() == 'tomorrow') {
        baseDate = now.add(const Duration(days: 1));
      } else if (suggestion.taskDate!.toLowerCase() != 'today') {
        // Try to parse specific date if provided
        final parsed = DateTime.tryParse(suggestion.taskDate!);
        if (parsed != null) {
          baseDate = parsed;
        }
      }
    }
    
    if (suggestion.scheduleType == 'absolute' && suggestion.absoluteTime != null) {
      final parts = suggestion.absoluteTime!.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          absoluteTime = DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
        }
      }
    }
    
    // Parse end time if provided
    if (suggestion.endTime != null) {
      final parts = suggestion.endTime!.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          endTime = DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
        }
      }
    }
    
    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: suggestion.title,
      description: suggestion.description,
      createdAt: now,
      priority: suggestion.priority,
      scheduleType: suggestion.scheduleType == 'prayerRelative' 
          ? ScheduleType.prayerRelative 
          : ScheduleType.absolute,
      absoluteTime: absoluteTime,
      endTime: endTime, // Add end time
      relatedPrayer: suggestion.relatedPrayer != null 
          ? PrayerName.values.firstWhere(
              (p) => p.toString().split('.').last == suggestion.relatedPrayer,
              orElse: () => PrayerName.fajr,
            )
          : null,
      isBeforePrayer: suggestion.isBeforePrayer,
      minutesOffset: suggestion.minutesOffset,
      recurrence: _parseRecurrenceType(suggestion.recurrenceType),
      weeklyDays: suggestion.weeklyDays,
      endDate: suggestion.endDate != null 
          ? DateTime.tryParse(suggestion.endDate!)
          : null,
    );
    
    await addTask(task);
  }
  
  static TaskRecurrence _parseRecurrenceType(String? type) {
    switch (type?.toLowerCase()) {
      case 'daily':
        return TaskRecurrence.daily;
      case 'weekly':
        return TaskRecurrence.weekly;
      case 'monthly':
        return TaskRecurrence.monthly;
      default:
        return TaskRecurrence.once;
    }
  }
}

// Helper class to hold task with calculated time
class TaskWithTime {
  final Task task;
  final DateTime scheduledTime;
  final DateTime? endTime;
  
  TaskWithTime({
    required this.task, 
    required this.scheduledTime,
    this.endTime,
  });
}