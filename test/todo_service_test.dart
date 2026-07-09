import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow_pro/core/services/gemini_task_assistant.dart';
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

  group('TodoService.updateTask updatedAt stamping', () {
    test('stamps updatedAt when the caller left it null', () async {
      final task = buildTask(id: 'stamp-1');
      await TodoService.addTask(task);

      // Build a fresh Task directly (like the edit screen does) so
      // updatedAt is null — updateTask must stamp it, otherwise toJson
      // falls back to createdAt and LWW sync reverts the edit.
      final edited = Task(
        id: task.id,
        title: 'Edited title',
        createdAt: task.createdAt,
        scheduleType: task.scheduleType,
        recurrence: task.recurrence,
      );
      expect(edited.updatedAt, isNull);

      final before = DateTime.now().subtract(const Duration(seconds: 1));
      await TodoService.updateTask(edited);

      final reloaded = (await TodoService.getAllTasks())
          .firstWhere((t) => t.id == task.id);
      expect(reloaded.updatedAt, isNotNull);
      expect(reloaded.updatedAt!.isAfter(before), isTrue);
      // Not the createdAt fallback (createdAt is 2026-01-01)
      expect(reloaded.updatedAt!.isAfter(reloaded.createdAt), isTrue);
    });

    test('preserves a caller-provided updatedAt', () async {
      final task = buildTask(id: 'stamp-2');
      await TodoService.addTask(task);

      final explicit = DateTime(2026, 7, 1, 12, 0);
      final edited = Task(
        id: task.id,
        title: 'Edited',
        createdAt: task.createdAt,
        updatedAt: explicit,
        scheduleType: task.scheduleType,
        recurrence: task.recurrence,
      );
      await TodoService.updateTask(edited);

      final reloaded = (await TodoService.getAllTasks())
          .firstWhere((t) => t.id == task.id);
      expect(reloaded.updatedAt, explicit);
    });
  });

  group('Once-task completion consistency (isCompleted <-> completedDates)', () {
    test('toggle on sets BOTH isCompleted and a completedDates entry', () async {
      final task = buildTask(id: 'once-sync', recurrence: TaskRecurrence.once);
      await TodoService.addTask(task);

      final on = await TodoService.toggleTaskStatus(task);
      expect(on!.isCompleted, isTrue);
      expect(on.isCompletedForDate(DateTime.now()), isTrue);

      final off = await TodoService.toggleTaskStatus(on);
      expect(off!.isCompleted, isFalse);
      expect(off.completedDates, isEmpty);
    });

    test('unmark clears ALL completedDates entries for once tasks', () async {
      final task = buildTask(id: 'once-clear', recurrence: TaskRecurrence.once);
      await TodoService.addTask(task);

      await TodoService.markTaskCompleted(task.id, DateTime(2026, 7, 8));
      await TodoService.markTaskCompleted(task.id, DateTime(2026, 7, 9));

      final un =
          await TodoService.unmarkTaskCompleted(task.id, DateTime(2026, 7, 10));
      expect(un!.isCompleted, isFalse);
      expect(un.completedDates, isEmpty);
    });

    test('toggle repairs a stale split-brain state (date entry but isCompleted false)', () async {
      final today = DateTime.now();
      final task = Task(
        id: 'once-split',
        title: 'Split brain',
        createdAt: today,
        scheduleType: ScheduleType.absolute,
        recurrence: TaskRecurrence.once,
        completedDates: [today],
        isCompleted: false, // stale: date says done, flag says not
      );
      await TodoService.addTask(task);

      // Either completion signal counts as "done", so toggling
      // un-completes and clears both signals.
      final off = await TodoService.toggleTaskStatus(task);
      expect(off!.isCompleted, isFalse);
      expect(off.completedDates, isEmpty);
    });

    test('markTaskCompleted does not duplicate an existing date entry', () async {
      final task = buildTask(id: 'dedup-1', recurrence: TaskRecurrence.daily);
      await TodoService.addTask(task);

      await TodoService.markTaskCompleted(task.id, DateTime(2026, 7, 9, 8));
      final second =
          await TodoService.markTaskCompleted(task.id, DateTime(2026, 7, 9, 20));

      expect(second!.completedDates.length, 1);
    });
  });

  group('TodoService.createTaskFromSuggestion date anchoring', () {
    test('absolute suggestion for tomorrow is anchored to tomorrow', () async {
      final suggestion = TaskSuggestion(
        title: 'Tomorrow absolute',
        scheduleType: 'absolute',
        absoluteTime: '10:30',
        taskDate: 'tomorrow',
        recurrenceType: 'once',
      );
      await TodoService.createTaskFromSuggestion(suggestion);

      final task = (await TodoService.getAllTasks())
          .firstWhere((t) => t.title == 'Tomorrow absolute');
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));

      expect(task.startDate, isNotNull);
      expect(Task.isSameDay(task.startDate!, tomorrow), isTrue);
      expect(Task.isSameDay(task.absoluteTime!, tomorrow), isTrue);
      expect(task.shouldShowOnDate(tomorrow), isTrue);
      expect(task.shouldShowOnDate(today), isFalse);
    });

    test('prayer-relative once suggestion for tomorrow shows tomorrow, not today', () async {
      // Task creation never hits PrayerTimeService (only display-time
      // calculation does), so the prayer-relative path is testable here.
      final suggestion = TaskSuggestion(
        title: 'Prayer relative tomorrow',
        scheduleType: 'prayerRelative',
        relatedPrayer: 'dhuhr',
        isBeforePrayer: true,
        minutesOffset: 15,
        taskDate: 'tomorrow',
        recurrenceType: 'once',
      );
      await TodoService.createTaskFromSuggestion(suggestion);

      final task = (await TodoService.getAllTasks())
          .firstWhere((t) => t.title == 'Prayer relative tomorrow');
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));

      // Without startDate the once + prayer-relative anchor fell back to
      // createdAt, making the task show TODAY instead of tomorrow.
      expect(task.startDate, isNotNull);
      expect(Task.isSameDay(task.startDate!, tomorrow), isTrue);
      expect(task.shouldShowOnDate(tomorrow), isTrue);
      expect(task.shouldShowOnDate(today), isFalse);
    });
  });

  group('TodoService tombstone removal', () {
    test('removeTaskDeletionTombstone drops only the given id', () async {
      await TodoService.recordTaskDeletion('keep-me');
      await TodoService.recordTaskDeletion('drop-me');

      await TodoService.removeTaskDeletionTombstone('drop-me');

      final tombstones = await TodoService.getDeletedTaskTombstones();
      expect(tombstones.containsKey('drop-me'), isFalse);
      expect(tombstones.containsKey('keep-me'), isTrue);
    });
  });
}
