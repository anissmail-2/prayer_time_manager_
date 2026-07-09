import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow_pro/models/enhanced_task.dart';
import 'package:taskflow_pro/models/space.dart';
import 'package:taskflow_pro/models/task.dart';

void main() {
  group('EnhancedTask.copyWith spaceId', () {
    EnhancedTask buildEnhanced({String? spaceId = 'space-1'}) {
      return EnhancedTask(
        id: 'et-1',
        title: 'Idea',
        createdAt: DateTime(2026, 1, 1),
        scheduleType: ScheduleType.absolute,
        recurrence: TaskRecurrence.once,
        spaceId: spaceId,
        tags: ['a'],
      );
    }

    test('explicit null clears the space reference', () {
      final task = buildEnhanced();
      final detached = task.copyWith(spaceId: null);
      expect(detached.spaceId, isNull);
    });

    test('omitting spaceId keeps the current value', () {
      final task = buildEnhanced();
      final renamed = task.copyWith(title: 'Renamed');
      expect(renamed.spaceId, 'space-1');
      expect(renamed.title, 'Renamed');
    });

    test('passing a new value replaces the space reference', () {
      final task = buildEnhanced();
      final moved = task.copyWith(spaceId: 'space-2');
      expect(moved.spaceId, 'space-2');
    });
  });

  group('Space.copyWith parentSpaceId', () {
    Space buildSpace() => Space(
          id: 's-1',
          name: 'Child',
          createdAt: DateTime(2026, 1, 1),
          parentSpaceId: 'parent-1',
        );

    test('explicit null makes the space root-level', () {
      expect(buildSpace().copyWith(parentSpaceId: null).parentSpaceId, isNull);
    });

    test('omitting parentSpaceId keeps the current parent', () {
      expect(buildSpace().copyWith(name: 'Renamed').parentSpaceId, 'parent-1');
    });
  });

  group('JSON round-trips', () {
    test('Task round-trips through toJson/fromJson', () {
      final task = Task(
        id: 'rt-1',
        title: 'Round trip',
        description: 'desc #space1',
        createdAt: DateTime(2026, 3, 4, 5, 6, 7),
        updatedAt: DateTime(2026, 3, 5),
        isCompleted: false,
        priority: TaskPriority.high,
        itemType: ItemType.routine,
        scheduleType: ScheduleType.prayerRelative,
        relatedPrayer: PrayerName.maghrib,
        isBeforePrayer: true,
        minutesOffset: 15,
        endRelatedPrayer: PrayerName.isha,
        endIsBeforePrayer: false,
        endMinutesOffset: 10,
        recurrence: TaskRecurrence.weekly,
        weeklyDays: [1, 4],
        weeklyInterval: 2,
        startDate: DateTime(2026, 3, 2),
        endDate: DateTime(2026, 9, 30),
        monthlyDates: [1, 15, 31],
        monthlyPattern: 'first_monday',
        completedDates: [DateTime(2026, 3, 5), DateTime(2026, 3, 9)],
        estimatedMinutes: 45,
      );

      final restored = Task.fromJson(task.toJson());

      expect(restored.id, task.id);
      expect(restored.title, task.title);
      expect(restored.description, task.description);
      expect(restored.createdAt, task.createdAt);
      expect(restored.priority, task.priority);
      expect(restored.itemType, task.itemType);
      expect(restored.scheduleType, task.scheduleType);
      expect(restored.relatedPrayer, task.relatedPrayer);
      expect(restored.isBeforePrayer, task.isBeforePrayer);
      expect(restored.minutesOffset, task.minutesOffset);
      expect(restored.endRelatedPrayer, task.endRelatedPrayer);
      expect(restored.recurrence, task.recurrence);
      expect(restored.weeklyDays, task.weeklyDays);
      expect(restored.weeklyInterval, task.weeklyInterval);
      expect(restored.startDate, task.startDate);
      expect(restored.endDate, task.endDate);
      expect(restored.monthlyDates, task.monthlyDates);
      expect(restored.monthlyPattern, task.monthlyPattern);
      expect(restored.completedDates, task.completedDates);
      expect(restored.estimatedMinutes, task.estimatedMinutes);
    });

    test('EnhancedTask round-trips through toJson/fromJson', () {
      final task = EnhancedTask(
        id: 'ert-1',
        title: 'Enhanced round trip',
        createdAt: DateTime(2026, 2, 2, 3, 4),
        scheduleType: ScheduleType.absolute,
        absoluteTime: DateTime(2026, 2, 2, 15, 0),
        recurrence: TaskRecurrence.once,
        spaceId: 'space-9',
        parentTaskId: 'parent-9',
        subtaskIds: ['sub-1', 'sub-2'],
        tags: ['deep', 'work'],
        status: TaskStatus.inProgress,
        estimatedMinutes: 30,
        actualMinutes: 20,
        notes: 'some notes',
        attachments: ['file.png'],
        customFields: {'key': 'value'},
      );

      final restored = EnhancedTask.fromJson(task.toJson());

      expect(restored.id, task.id);
      expect(restored.title, task.title);
      expect(restored.createdAt, task.createdAt);
      expect(restored.absoluteTime, task.absoluteTime);
      expect(restored.spaceId, task.spaceId);
      expect(restored.parentTaskId, task.parentTaskId);
      expect(restored.subtaskIds, task.subtaskIds);
      expect(restored.tags, task.tags);
      expect(restored.status, task.status);
      expect(restored.estimatedMinutes, task.estimatedMinutes);
      expect(restored.actualMinutes, task.actualMinutes);
      expect(restored.notes, task.notes);
      expect(restored.attachments, task.attachments);
      expect(restored.customFields, task.customFields);
    });

    test('Space round-trips through toJson/fromJson', () {
      final space = Space(
        id: 'srt-1',
        name: 'Projects',
        description: 'All projects',
        color: '#FF8800',
        createdAt: DateTime(2026, 1, 15, 10, 30),
        updatedAt: DateTime(2026, 1, 20),
        status: SpaceStatus.archived,
        itemIds: ['t1', 't2'],
        parentSpaceId: 'root',
        subSpaceIds: ['child-1'],
        metadata: {'icon': 'folder'},
      );

      final restored = Space.fromJson(space.toJson());

      expect(restored.id, space.id);
      expect(restored.name, space.name);
      expect(restored.description, space.description);
      expect(restored.color, space.color);
      expect(restored.createdAt, space.createdAt);
      expect(restored.updatedAt, space.updatedAt);
      expect(restored.status, space.status);
      expect(restored.itemIds, space.itemIds);
      expect(restored.parentSpaceId, space.parentSpaceId);
      expect(restored.subSpaceIds, space.subSpaceIds);
      expect(restored.metadata, space.metadata);
    });
  });
}
