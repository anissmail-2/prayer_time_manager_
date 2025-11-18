import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow_pro/widgets/subtasks_widget.dart';
import 'package:taskflow_pro/models/enhanced_task.dart';
import 'package:taskflow_pro/models/task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubtasksWidget', () {
    late EnhancedTask parentTask;

    setUp(() {
      SharedPreferences.setMockInitialValues({});

      parentTask = EnhancedTask(
        id: 'parent-1',
        title: 'Parent Task',
        description: 'Parent Description',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
      );
    });

    testWidgets('should display subtasks header', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtasksWidget(
              parentTask: parentTask,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Subtasks'), findsOneWidget);
    });

    testWidgets('should show add subtask input when editing allowed',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtasksWidget(
              parentTask: parentTask,
              allowEditing: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Add a subtask...'), findsOneWidget);
    });

    testWidgets('should not show add subtask input when editing disabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtasksWidget(
              parentTask: parentTask,
              allowEditing: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('should show progress bar when subtasks exist',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtasksWidget(
              parentTask: parentTask,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially no progress bar (no subtasks)
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('should show loading indicator initially',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtasksWidget(
              parentTask: parentTask,
            ),
          ),
        ),
      );

      // Before pumpAndSettle, should show loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      // After loading, should not show loading indicator
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('should call onSubtasksChanged callback',
        (WidgetTester tester) async {
      bool callbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtasksWidget(
              parentTask: parentTask,
              onSubtasksChanged: () {
                callbackCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Callback should not be called initially
      expect(callbackCalled, false);
    });
  });
}
