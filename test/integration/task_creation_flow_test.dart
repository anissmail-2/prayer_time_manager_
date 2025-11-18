import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow_pro/core/services/todo_service.dart';
import 'package:taskflow_pro/models/task.dart';
import 'package:taskflow_pro/models/enhanced_task.dart';

void main() {
  group('Task Creation Flow Integration Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await TodoService.clearAllTasks();
    });

    test('complete task creation and retrieval flow', () async {
      // Step 1: Create a task
      final task = Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Integration Test Task',
        description: 'This is a test task for integration testing',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.absolute,
        absoluteTime: DateTime.now().add(const Duration(hours: 2)),
        recurrence: TaskRecurrence.once,
        priority: TaskPriority.high,
      );

      await TodoService.addTask(task);

      // Step 2: Retrieve all tasks
      final allTasks = await TodoService.getAllTasks();
      expect(allTasks.length, 1);
      expect(allTasks.first.title, task.title);

      // Step 3: Retrieve tasks for today
      final todayTasks = await TodoService.getTasksForDate(DateTime.now());
      expect(todayTasks.length, 1);

      // Step 4: Complete the task
      await TodoService.toggleTaskCompletion(task.id, DateTime.now());
      final completedTasks = await TodoService.getAllTasks();
      expect(completedTasks.first.isCompleted, true);

      // Step 5: Delete the task
      await TodoService.deleteTask(task.id);
      final remainingTasks = await TodoService.getAllTasks();
      expect(remainingTasks.length, 0);
    });

    test('enhanced task with subtasks flow', () async {
      // Step 1: Create parent task
      final parentTask = EnhancedTask(
        id: '1',
        title: 'Parent Task',
        description: 'Main project task',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
        status: TaskStatus.inProgress,
      );

      await TodoService.addTask(parentTask);

      // Step 2: Create subtasks
      final subtask1 = EnhancedTask(
        id: '2',
        title: 'Subtask 1',
        description: 'First step',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
        parentTaskId: '1',
      );

      final subtask2 = EnhancedTask(
        id: '3',
        title: 'Subtask 2',
        description: 'Second step',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
        parentTaskId: '1',
      );

      await TodoService.addTask(subtask1);
      await TodoService.addTask(subtask2);

      // Step 3: Verify hierarchy
      final allTasks = await TodoService.getAllTasks();
      expect(allTasks.length, 3);

      final subtasks = allTasks.whereType<EnhancedTask>()
          .where((t) => t.parentTaskId == '1')
          .toList();
      expect(subtasks.length, 2);

      // Step 4: Complete subtasks
      await TodoService.toggleTaskCompletion('2', DateTime.now());
      await TodoService.toggleTaskCompletion('3', DateTime.now());

      final updatedTasks = await TodoService.getAllTasks();
      final completedSubtasks = updatedTasks
          .whereType<EnhancedTask>()
          .where((t) => t.parentTaskId == '1' && t.isCompleted)
          .toList();
      expect(completedSubtasks.length, 2);
    });

    test('prayer-relative task scheduling flow', () async {
      // Step 1: Create prayer-relative task
      final prayerTask = Task(
        id: '1',
        title: 'Prayer Task',
        description: 'Task before Dhuhr',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.prayerRelative,
        relatedPrayer: 'dhuhr',
        isBeforePrayer: true,
        minutesOffset: 15,
        recurrence: TaskRecurrence.daily,
      );

      await TodoService.addTask(prayerTask);

      // Step 2: Verify task was saved with correct prayer info
      final tasks = await TodoService.getAllTasks();
      expect(tasks.first.scheduleType, ScheduleType.prayerRelative);
      expect(tasks.first.relatedPrayer, 'dhuhr');
      expect(tasks.first.isBeforePrayer, true);
      expect(tasks.first.minutesOffset, 15);

      // Step 3: Verify it shows up in daily recurrence
      final todayTasks = await TodoService.getTasksForDate(DateTime.now());
      expect(todayTasks.length, 1);

      final tomorrowTasks = await TodoService.getTasksForDate(
        DateTime.now().add(const Duration(days: 1)),
      );
      expect(tomorrowTasks.length, 1);
    });

    test('recurring task completion tracking flow', () async {
      // Step 1: Create weekly recurring task
      final recurringTask = Task(
        id: '1',
        title: 'Weekly Task',
        description: 'Happens every Monday',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.absolute,
        absoluteTime: DateTime.now(),
        recurrence: TaskRecurrence.weekly,
        weeklyDays: [1], // Monday
      );

      await TodoService.addTask(recurringTask);

      // Step 2: Complete for today
      final today = DateTime.now();
      await TodoService.toggleTaskCompletion('1', today);

      // Step 3: Verify completion is tracked
      final tasks = await TodoService.getAllTasks();
      expect(tasks.first.completedDates.length, 1);
      expect(tasks.first.completedDates.first.day, today.day);

      // Step 4: Complete for another day
      final tomorrow = today.add(const Duration(days: 1));
      await TodoService.toggleTaskCompletion('1', tomorrow);

      final updatedTasks = await TodoService.getAllTasks();
      expect(updatedTasks.first.completedDates.length, 2);
    });

    test('task priority and filtering flow', () async {
      // Create tasks with different priorities
      final highPriorityTask = Task(
        id: '1',
        title: 'High Priority',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
        priority: TaskPriority.high,
      );

      final mediumPriorityTask = Task(
        id: '2',
        title: 'Medium Priority',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
        priority: TaskPriority.medium,
      );

      final lowPriorityTask = Task(
        id: '3',
        title: 'Low Priority',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
        priority: TaskPriority.low,
      );

      await TodoService.addTask(highPriorityTask);
      await TodoService.addTask(mediumPriorityTask);
      await TodoService.addTask(lowPriorityTask);

      // Retrieve and verify priorities
      final allTasks = await TodoService.getAllTasks();
      expect(allTasks.length, 3);

      final highTasks = allTasks.where((t) => t.priority == TaskPriority.high);
      final mediumTasks = allTasks.where((t) => t.priority == TaskPriority.medium);
      final lowTasks = allTasks.where((t) => t.priority == TaskPriority.low);

      expect(highTasks.length, 1);
      expect(mediumTasks.length, 1);
      expect(lowTasks.length, 1);
    });

    test('task update flow', () async {
      // Step 1: Create initial task
      final task = Task(
        id: '1',
        title: 'Original Title',
        description: 'Original Description',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
        priority: TaskPriority.low,
      );

      await TodoService.addTask(task);

      // Step 2: Update task details
      final updatedTask = Task(
        id: '1',
        title: 'Updated Title',
        description: 'Updated Description',
        createdAt: task.createdAt,
        scheduleType: ScheduleType.absolute,
        absoluteTime: DateTime.now().add(const Duration(hours: 1)),
        recurrence: TaskRecurrence.daily,
        priority: TaskPriority.high,
      );

      await TodoService.updateTask(updatedTask);

      // Step 3: Verify updates
      final tasks = await TodoService.getAllTasks();
      expect(tasks.first.title, 'Updated Title');
      expect(tasks.first.description, 'Updated Description');
      expect(tasks.first.scheduleType, ScheduleType.absolute);
      expect(tasks.first.recurrence, TaskRecurrence.daily);
      expect(tasks.first.priority, TaskPriority.high);
    });
  });
}
