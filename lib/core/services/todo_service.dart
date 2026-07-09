import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/task.dart';
import 'gemini_task_assistant.dart';
import 'auth_service.dart';
import 'firestore_todo_service.dart';

class TodoService {
  static const String _tasksKey = 'tasks';
  static const String _deletedTasksKey = 'deleted_task_ids';
  static const Duration _tombstoneRetention = Duration(days: 30);

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
    // Defensive belt: if the caller built a Task without updatedAt, stamp
    // it here so last-write-wins sync never treats this edit as stale
    // (toJson falls back to createdAt when updatedAt is null).
    final task = updatedTask.updatedAt == null
        ? updatedTask.copyWith(updatedAt: DateTime.now())
        : updatedTask;

    if (AuthService.isLoggedIn) {
      // Use Firestore directly when logged in
      return FirestoreTodoService.updateTask(task);
    }

    // Only use local storage when not logged in
    final tasks = await getAllTasks();
    final index = tasks.indexWhere((t) => t.id == task.id);

    if (index != -1) {
      tasks[index] = task;
      await _saveTasks(tasks);
    }
  }
  
  // Delete a task
  static Future<void> deleteTask(String taskId) async {
    // Record a tombstone so sync propagates the deletion
    // instead of resurrecting the task.
    await recordTaskDeletion(taskId);

    if (AuthService.isLoggedIn) {
      // Use Firestore directly when logged in
      return FirestoreTodoService.deleteTask(taskId);
    }

    // Only use local storage when not logged in
    final tasks = await getAllTasks();
    tasks.removeWhere((task) => task.id == taskId);
    await _saveTasks(tasks);
  }

  // Route a single-task save to the right backend
  static Future<void> _saveUpdatedTask(Task updatedTask, List<Task> tasks, int index) async {
    if (AuthService.isLoggedIn) {
      await FirestoreTodoService.updateTask(updatedTask);
    } else {
      tasks[index] = updatedTask;
      await _saveTasks(tasks);
    }
  }

  // Mark task as completed for a date.
  // For one-time tasks this keeps BOTH completion signals in sync
  // (isCompleted flag + completedDates entry) so UIs that check either
  // one agree. Returns the updated task, or null if not found.
  static Future<Task?> markTaskCompleted(String taskId, DateTime date) async {
    final tasks = await getAllTasks();
    final index = tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) return null;

    final task = tasks[index];
    // Deduplicate: don't add a second entry for a date that is
    // already marked completed.
    final updatedCompletedDates = List<DateTime>.from(task.completedDates);
    if (!task.isCompletedForDate(date)) {
      updatedCompletedDates.add(date);
    }

    // If it's a one-time task, mark it as completed
    final isCompleted = task.recurrence == TaskRecurrence.once;

    final updatedTask = task.copyWith(
      completedDates: updatedCompletedDates,
      isCompleted: isCompleted,
    );

    await _saveUpdatedTask(updatedTask, tasks, index);
    return updatedTask;
  }

  // Unmark task completion for a date.
  // For one-time tasks this clears BOTH completion signals: isCompleted
  // and ALL completedDates entries (a once task has a single logical
  // completion, so no stale per-date entry may survive).
  // Returns the updated task, or null if the task was not found.
  static Future<Task?> unmarkTaskCompleted(String taskId, DateTime date) async {
    final tasks = await getAllTasks();
    final index = tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) return null;

    final task = tasks[index];
    final updatedCompletedDates = task.recurrence == TaskRecurrence.once
        ? <DateTime>[]
        : (List<DateTime>.from(task.completedDates)
          ..removeWhere((d) => Task.isSameDay(d, date)));

    final updatedTask = task.copyWith(
      completedDates: updatedCompletedDates,
      isCompleted: false,
    );

    await _saveUpdatedTask(updatedTask, tasks, index);
    return updatedTask;
  }

  // Toggle task completion status.
  // Delegates to markTaskCompleted/unmarkTaskCompleted so one-time tasks
  // keep isCompleted and completedDates consistent (previously the toggle
  // only flipped isCompleted, leaving a stale completedDates entry that
  // made un-completing from the Timeline a visual no-op).
  // Returns the updated task, or null if the task was not found.
  static Future<Task?> toggleTaskStatus(Task task) async {
    final today = DateTime.now();

    if (task.recurrence == TaskRecurrence.once) {
      final isDone = task.isCompleted || task.isCompletedForDate(today);
      return isDone
          ? unmarkTaskCompleted(task.id, today)
          : markTaskCompleted(task.id, today);
    }

    // For recurring tasks, toggle completion for today
    if (task.isCompletedForDate(today)) {
      return unmarkTaskCompleted(task.id, today);
    } else {
      return markTaskCompleted(task.id, today);
    }
  }

  // ---- Deletion tombstones (used by sync to propagate deletions) ----

  /// Record that a task was deleted (id -> deletion time).
  static Future<void> recordTaskDeletion(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final tombstones = _decodeTombstones(prefs.getString(_deletedTasksKey));
    tombstones[taskId] = DateTime.now();
    await prefs.setString(_deletedTasksKey, _encodeTombstones(tombstones));
  }

  /// Remove a single tombstone (used by sync when a NEWER cloud edit
  /// wins over a local delete — the task must stay alive).
  static Future<void> removeTaskDeletionTombstone(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final tombstones = _decodeTombstones(prefs.getString(_deletedTasksKey));
    if (tombstones.remove(taskId) != null) {
      await prefs.setString(_deletedTasksKey, _encodeTombstones(tombstones));
    }
  }

  /// Get deletion tombstones, pruning entries older than 30 days.
  static Future<Map<String, DateTime>> getDeletedTaskTombstones() async {
    final prefs = await SharedPreferences.getInstance();
    final tombstones = _decodeTombstones(prefs.getString(_deletedTasksKey));
    final cutoff = DateTime.now().subtract(_tombstoneRetention);
    final beforePrune = tombstones.length;
    tombstones.removeWhere((_, deletedAt) => deletedAt.isBefore(cutoff));
    if (tombstones.length != beforePrune) {
      await prefs.setString(_deletedTasksKey, _encodeTombstones(tombstones));
    }
    return tombstones;
  }

  static Map<String, DateTime> _decodeTombstones(String? jsonStr) {
    if (jsonStr == null) return {};
    try {
      final Map<String, dynamic> decoded = json.decode(jsonStr);
      final result = <String, DateTime>{};
      decoded.forEach((id, timestamp) {
        final parsed = DateTime.tryParse(timestamp.toString());
        if (parsed != null) result[id] = parsed;
      });
      return result;
    } catch (e) {
      return {};
    }
  }

  static String _encodeTombstones(Map<String, DateTime> tombstones) {
    return json.encode(
      tombstones.map((id, time) => MapEntry(id, time.toIso8601String())),
    );
  }
  
  // Get tasks for today
  static Future<List<Task>> getTasksForToday() async {
    final tasks = await getAllTasks();
    final today = DateTime.now();

    return tasks.where((task) => _shouldTaskShowOnDate(task, today)).toList();
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
  
  // Check if task should show on a specific date.
  // Recurrence logic lives in Task.shouldShowOnDate (single source of truth).
  static bool _shouldTaskShowOnDate(Task task, DateTime date) {
    // Skip completed one-time tasks
    if (task.isCompleted && task.recurrence == TaskRecurrence.once) {
      return false;
    }

    return task.shouldShowOnDate(date);
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
      // Anchor the task to the requested date. Without this, a once +
      // prayer-relative task falls back to createdAt and "tomorrow"
      // shows up today (and never on the requested day).
      startDate: baseDate,
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