import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow_pro/core/services/todo_service.dart';
import 'package:taskflow_pro/models/task.dart';
import 'package:taskflow_pro/models/enhanced_task.dart';

void main() {
  group('TodoService', () {
    setUp(() async {
      // Initialize shared preferences with empty data
      SharedPreferences.setMockInitialValues({});
    });

    test('should add a new task', () async {
      final task = Task(
        id: '1',
        title: 'Test Task',
        description: 'Test Description',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
      );

      await TodoService.addTask(task);
      final tasks = await TodoService.getAllTasks();

      expect(tasks.length, 1);
      expect(tasks.first.title, 'Test Task');
    });

    test('should update an existing task', () async {
      final task = Task(
        id: '1',
        title: 'Original Title',
        description: 'Original Description',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
      );

      await TodoService.addTask(task);

      final updatedTask = Task(
        id: '1',
        title: 'Updated Title',
        description: 'Updated Description',
        createdAt: task.createdAt,
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
      );

      await TodoService.updateTask(updatedTask);
      final tasks = await TodoService.getAllTasks();

      expect(tasks.length, 1);
      expect(tasks.first.title, 'Updated Title');
      expect(tasks.first.description, 'Updated Description');
    });

    test('should delete a task', () async {
      final task = Task(
        id: '1',
        title: 'Test Task',
        description: 'Test Description',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
      );

      await TodoService.addTask(task);
      expect((await TodoService.getAllTasks()).length, 1);

      await TodoService.deleteTask('1');
      expect((await TodoService.getAllTasks()).length, 0);
    });

    test('should toggle task completion', () async {
      final task = Task(
        id: '1',
        title: 'Test Task',
        description: 'Test Description',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
        isCompleted: false,
      );

      await TodoService.addTask(task);
      await TodoService.toggleTaskCompletion('1', DateTime.now());

      final tasks = await TodoService.getAllTasks();
      expect(tasks.first.isCompleted, true);
    });

    test('should get tasks for today', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final tomorrow = today.add(const Duration(days: 1));

      final todayTask = Task(
        id: '1',
        title: 'Today Task',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.absolute,
        absoluteTime: DateTime(today.year, today.month, today.day, 10, 0),
        recurrence: TaskRecurrence.once,
      );

      final tomorrowTask = Task(
        id: '2',
        title: 'Tomorrow Task',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.absolute,
        absoluteTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0),
        recurrence: TaskRecurrence.once,
      );

      await TodoService.addTask(todayTask);
      await TodoService.addTask(tomorrowTask);

      final tasksForToday = await TodoService.getTasksForDate(today);
      expect(tasksForToday.length, 1);
      expect(tasksForToday.first.title, 'Today Task');
    });

    test('should handle recurring tasks', () async {
      final task = Task(
        id: '1',
        title: 'Daily Task',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.absolute,
        absoluteTime: DateTime(2024, 1, 1, 10, 0),
        recurrence: TaskRecurrence.daily,
      );

      await TodoService.addTask(task);

      // Should show for multiple days
      final jan1Tasks = await TodoService.getTasksForDate(DateTime(2024, 1, 1));
      final jan2Tasks = await TodoService.getTasksForDate(DateTime(2024, 1, 2));

      expect(jan1Tasks.length, 1);
      expect(jan2Tasks.length, 1);
    });

    test('should create enhanced task with subtasks', () async {
      final parentTask = EnhancedTask(
        id: '1',
        title: 'Parent Task',
        description: 'Parent Description',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
      );

      final subtask = EnhancedTask(
        id: '2',
        title: 'Subtask',
        description: 'Subtask Description',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
        parentTaskId: '1',
      );

      await TodoService.addTask(parentTask);
      await TodoService.addTask(subtask);

      final tasks = await TodoService.getAllTasks();
      final loadedSubtask = tasks.whereType<EnhancedTask>()
          .firstWhere((t) => t.id == '2');

      expect(loadedSubtask.parentTaskId, '1');
      expect(loadedSubtask.isSubtask, true);
    });

    test('should handle task priorities', () async {
      final highPriorityTask = Task(
        id: '1',
        title: 'High Priority',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
        priority: TaskPriority.high,
      );

      final lowPriorityTask = Task(
        id: '2',
        title: 'Low Priority',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
        priority: TaskPriority.low,
      );

      await TodoService.addTask(highPriorityTask);
      await TodoService.addTask(lowPriorityTask);

      final tasks = await TodoService.getAllTasks();
      expect(tasks.firstWhere((t) => t.id == '1').priority, TaskPriority.high);
      expect(tasks.firstWhere((t) => t.id == '2').priority, TaskPriority.low);
    });

    test('should handle prayer-relative tasks', () async {
      final task = Task(
        id: '1',
        title: 'Prayer Task',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.prayerRelative,
        relatedPrayer: 'dhuhr',
        isBeforePrayer: true,
        minutesOffset: 15,
        recurrence: TaskRecurrence.once,
      );

      await TodoService.addTask(task);
      final tasks = await TodoService.getAllTasks();

      expect(tasks.first.scheduleType, ScheduleType.prayerRelative);
      expect(tasks.first.relatedPrayer, 'dhuhr');
      expect(tasks.first.isBeforePrayer, true);
      expect(tasks.first.minutesOffset, 15);
    });

    test('should clear all tasks', () async {
      final task1 = Task(
        id: '1',
        title: 'Task 1',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
      );

      final task2 = Task(
        id: '2',
        title: 'Task 2',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
      );

      await TodoService.addTask(task1);
      await TodoService.addTask(task2);
      expect((await TodoService.getAllTasks()).length, 2);

      await TodoService.clearAllTasks();
      expect((await TodoService.getAllTasks()).length, 0);
    });
  });
}
