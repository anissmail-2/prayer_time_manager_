import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow_pro/core/services/data_migration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DataMigrationService.hasLocalData', () {
    test('false when no keys exist', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await DataMigrationService.hasLocalData(), isFalse);
    });

    test('false when only settings keys exist (never cleared, must not re-prompt)', () async {
      SharedPreferences.setMockInitialValues({
        'prayer_durations': json.encode({'fajr': 20}),
        'location_settings': json.encode({'city': 'Abu Dhabi'}),
      });
      expect(await DataMigrationService.hasLocalData(), isFalse);
    });

    test('false when content keys hold empty lists (hydrated empty mirror)', () async {
      // A fresh logged-in account gets '[]' written by sync hydration —
      // that is not unmigrated local data.
      SharedPreferences.setMockInitialValues({
        'tasks': '[]',
        'spaces': '[]',
      });
      expect(await DataMigrationService.hasLocalData(), isFalse);
    });

    test('true when tasks has content', () async {
      SharedPreferences.setMockInitialValues({
        'tasks': json.encode([
          {'id': '1', 'title': 'T'},
        ]),
      });
      expect(await DataMigrationService.hasLocalData(), isTrue);
    });

    test('true when enhanced_tasks or activities have content', () async {
      SharedPreferences.setMockInitialValues({
        'enhanced_tasks': json.encode([
          {'id': 'e1', 'title': 'Idea'},
        ]),
      });
      expect(await DataMigrationService.hasLocalData(), isTrue);

      SharedPreferences.setMockInitialValues({
        'activities': json.encode([
          {'id': 'a1', 'title': 'Meeting'},
        ]),
      });
      expect(await DataMigrationService.hasLocalData(), isTrue);
    });

    test('false for undecodable content (must not re-prompt forever)', () async {
      SharedPreferences.setMockInitialValues({
        'tasks': 'not-json{{{',
      });
      expect(await DataMigrationService.hasLocalData(), isFalse);
    });
  });
}
