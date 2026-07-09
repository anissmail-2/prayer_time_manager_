import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow_pro/core/services/todo_service.dart';
import 'package:taskflow_pro/models/task.dart';

Task buildTask({
  String id = 'task-1',
  TaskRecurrence recurrence = TaskRecurrence.daily,
  DateTime? startDate,
  DateTime? absoluteTime,
}) {
  return Task(
    id: id,
    title: 'Test task $id',
    createdAt: DateTime(2026, 1, 1, 9, 0),
    scheduleType: ScheduleType.absolute,
    recurrence: recurrence,
    startDate: startDate,
    absoluteTime: absoluteTime,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TodoService per-date completion', () {
    test('markTaskCompleted returns updated task and persists per-date', () async {
      final task = buildTask(recurrence: TaskRecurrence.daily);
      await TodoService.addTask(task);

      final date = DateTime(2026, 7, 9, 14, 30);
      final updated = await TodoService.markTaskCompleted(task.id, date);

      expect(updated, isNotNull);
      expect(updated!.isCompletedForDate(DateTime(2026, 7, 9)), isTrue);
      // Recurring tasks are not globally completed
      expect(updated.isCompleted, isFalse);

      // Persisted copy matches
      final reloaded = (await TodoService.getAllTasks())
          .firstWhere((t) => t.id == task.id);
      expect(reloaded.isCompletedForDate(DateTime(2026, 7, 9)), isTrue);
      expect(reloaded.isCompletedForDate(DateTime(2026, 7, 10)), isFalse);
    });

    test('markTaskCompleted marks one-time tasks fully completed', () async {
      final task = buildTask(
        id: 'once-1',
        recurrence: TaskRecurrence.once,
        absoluteTime: DateTime(2026, 7, 9, 10, 0),
      );
      await TodoService.addTask(task);

      final updated =
          await TodoService.markTaskCompleted(task.id, DateTime(2026, 7, 9));
      expect(updated!.isCompleted, isTrue);
    });

    test('unmarkTaskCompleted removes the date and returns updated task', () async {
      final task = buildTask(recurrence: TaskRecurrence.daily);
      await TodoService.addTask(task);

      await TodoService.markTaskCompleted(task.id, DateTime(2026, 7, 9, 8));
      final updated =
          await TodoService.unmarkTaskCompleted(task.id, DateTime(2026, 7, 9, 20));

      expect(updated, isNotNull);
      expect(updated!.isCompletedForDate(DateTime(2026, 7, 9)), isFalse);
      expect(updated.isCompleted, isFalse);

      final reloaded = (await TodoService.getAllTasks())
          .firstWhere((t) => t.id == task.id);
      expect(reloaded.isCompletedForDate(DateTime(2026, 7, 9)), isFalse);
    });

    test('mark/unmark return null for unknown task id', () async {
      expect(await TodoService.markTaskCompleted('nope', DateTime.now()), isNull);
      expect(await TodoService.unmarkTaskCompleted('nope', DateTime.now()), isNull);
    });

    test('toggleTaskStatus flips one-time task isCompleted', () async {
      final task = buildTask(id: 'once-2', recurrence: TaskRecurrence.once);
      await TodoService.addTask(task);

      final toggledOn = await TodoService.toggleTaskStatus(task);
      expect(toggledOn!.isCompleted, isTrue);

      final toggledOff = await TodoService.toggleTaskStatus(toggledOn);
      expect(toggledOff!.isCompleted, isFalse);
    });

    test('toggleTaskStatus toggles per-date completion for recurring tasks', () async {
      final task = buildTask(id: 'daily-2', recurrence: TaskRecurrence.daily);
      await TodoService.addTask(task);

      final today = DateTime.now();
      final toggledOn = await TodoService.toggleTaskStatus(task);
      expect(toggledOn!.isCompletedForDate(today), isTrue);
      expect(toggledOn.isCompleted, isFalse);

      final toggledOff = await TodoService.toggleTaskStatus(toggledOn);
      expect(toggledOff!.isCompletedForDate(today), isFalse);
    });
  });

  group('TodoService deletion tombstones', () {
    test('deleteTask records a tombstone under deleted_task_ids', () async {
      final task = buildTask(id: 'del-1');
      await TodoService.addTask(task);
      await TodoService.deleteTask(task.id);

      final tasks = await TodoService.getAllTasks();
      expect(tasks.where((t) => t.id == 'del-1'), isEmpty);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('deleted_task_ids');
      expect(raw, isNotNull);
      final Map<String, dynamic> tombstones = json.decode(raw!);
      expect(tombstones.containsKey('del-1'), isTrue);
      expect(DateTime.tryParse(tombstones['del-1']), isNotNull);

      final loaded = await TodoService.getDeletedTaskTombstones();
      expect(loaded.containsKey('del-1'), isTrue);
    });

    test('tombstones older than 30 days are pruned on read', () async {
      final old = DateTime.now().subtract(const Duration(days: 45));
      final recent = DateTime.now().subtract(const Duration(days: 5));
      SharedPreferences.setMockInitialValues({
        'deleted_task_ids': json.encode({
          'old-task': old.toIso8601String(),
          'recent-task': recent.toIso8601String(),
        }),
      });

      final tombstones = await TodoService.getDeletedTaskTombstones();
      expect(tombstones.containsKey('old-task'), isFalse);
      expect(tombstones.containsKey('recent-task'), isTrue);

      // Pruning persisted
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> raw =
          json.decode(prefs.getString('deleted_task_ids')!);
      expect(raw.containsKey('old-task'), isFalse);
    });
  });

  group('TodoService.getTasksForToday', () {
    test('includes tasks on their endDate (inclusive)', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final task = Task(
        id: 'end-today',
        title: 'Ends today',
        createdAt: today.subtract(const Duration(days: 10)),
        scheduleType: ScheduleType.absolute,
        recurrence: TaskRecurrence.daily,
        startDate: today.subtract(const Duration(days: 10)),
        endDate: today, // midnight today — must still show all day today
      );
      await TodoService.addTask(task);

      final todayTasks = await TodoService.getTasksForToday();
      expect(todayTasks.map((t) => t.id), contains('end-today'));
    });

    test('excludes completed one-time tasks', () async {
      final now = DateTime.now();
      final task = Task(
        id: 'done-once',
        title: 'Done',
        createdAt: now,
        scheduleType: ScheduleType.absolute,
        recurrence: TaskRecurrence.once,
        absoluteTime: now,
        isCompleted: true,
      );
      await TodoService.addTask(task);

      final todayTasks = await TodoService.getTasksForToday();
      expect(todayTasks.map((t) => t.id), isNot(contains('done-once')));
    });
  });
}
