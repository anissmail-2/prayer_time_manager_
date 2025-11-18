# Testing Guide for TaskFlow Pro

**Last Updated:** 2025-11-18
**Test Status:** ✅ 4/4 tests passing (100%)

This guide consolidates all testing information for the TaskFlow Pro project.

---

## 🧪 Quick Start

### Run All Tests
```bash
flutter test
```

### Run Specific Test File
```bash
flutter test test/offline_functionality_test.dart
```

### Run with Coverage
```bash
flutter test --coverage
```

---

## 📊 Current Test Status

### Test Results Summary
```
✅ All tests passed!
Total: 4/4 tests (100% passing)
```

### Test Files
1. **`test/widget_test.dart`** - Basic widget and theme tests
2. **`test/offline_functionality_test.dart`** - Offline behavior tests
3. **`test/test_helpers.dart`** - Mock utilities and test setup

---

## 🎯 Test Coverage

### ✅ Currently Tested
- **Offline Functionality**
  - Cached data retrieval when offline
  - Network connectivity detection
  - Prayer service fallback to cache
  - Graceful error handling

- **Widget Tests**
  - App initialization
  - Theme system
  - Basic widget rendering

### ⚠️ Needs More Coverage
- Service layer logic
- AI assistant functionality
- Task CRUD operations
- Space management
- Prayer time calculations
- Task filtering
- Data synchronization

### ❌ Not Tested (Requires Device)
- Platform channel integration (voice recording, file picker)
- Permission handling
- Voice input with Deepgram
- Image picker functionality
- Audio playback
- End-to-end user flows

---

## 🔧 Test Environment Setup

### Prerequisites
- Flutter SDK ^3.8.1
- Dart SDK (included with Flutter)
- Test dependencies installed via `flutter pub get`

### Mock Setup

The project uses `test/test_helpers.dart` for mocking:

```dart
import 'test/test_helpers.dart';

void main() {
  setUpAll(() {
    setupMocks(); // Mock plugins
    setupFirebaseMocks(); // Mock Firebase
  });

  // Your tests here
}
```

### Mocked Plugins
- ✅ `connectivity_plus` - Network detection
- ✅ Firebase Core - Firebase initialization
- ✅ Firebase Auth - Authentication
- ✅ Cloud Firestore - Database

---

## 📝 Writing New Tests

### Test Structure
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow_pro/path/to/your/file.dart';

void main() {
  group('Feature Name', () {
    setUp(() {
      // Setup before each test
    });

    tearDown(() {
      // Cleanup after each test
    });

    test('should do something', () {
      // Arrange
      final input = 'test';

      // Act
      final result = functionToTest(input);

      // Assert
      expect(result, equals('expected'));
    });
  });
}
```

### Widget Test Example
```dart
testWidgets('should render widget', (WidgetTester tester) async {
  // Build widget
  await tester.pumpWidget(
    MaterialApp(home: YourWidget()),
  );

  // Verify
  expect(find.text('Expected Text'), findsOneWidget);
});
```

---

## 🐛 Common Test Issues

### Issue 1: MissingPluginException
**Error:** `No implementation found for method X on channel Y`

**Solution:** Add mock in `test/test_helpers.dart`:
```dart
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(
        const MethodChannel('channel_name'),
        (MethodCall methodCall) async {
          return yourMockResponse;
        }
    );
```

### Issue 2: Firebase Not Initialized
**Error:** `Firebase has not been correctly initialized`

**Solution:** Use `setupFirebaseMocks()` in `setUpAll()`:
```dart
setUpAll(() {
  setupFirebaseMocks();
});
```

### Issue 3: Async Timeout
**Error:** `Test timed out after 30 seconds`

**Solution:** Increase timeout or use `await tester.pumpAndSettle()`:
```dart
test('async test', () async {
  // ...
  await tester.pumpAndSettle();
}, timeout: Timeout(Duration(minutes: 2)));
```

---

## 📈 Test Commands

### Basic Commands
```bash
# Run all tests
flutter test

# Run with verbose output
flutter test --verbose

# Run specific test file
flutter test test/offline_functionality_test.dart

# Run tests matching pattern
flutter test --name "offline"
```

### Coverage Commands
```bash
# Generate coverage
flutter test --coverage

# View coverage report (requires lcov)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Analysis Commands
```bash
# Run static analysis
flutter analyze

# Format code
flutter format lib/ test/

# Check for outdated packages
flutter pub outdated
```

---

## 🎯 Testing Best Practices

### 1. Test Organization
- Group related tests with `group()`
- Use descriptive test names
- Follow Arrange-Act-Assert pattern
- One assertion per test (when possible)

### 2. Mock External Dependencies
- Always mock API calls
- Mock platform channels
- Mock file system operations
- Mock time/date for consistency

### 3. Test Coverage Goals
- Aim for 80%+ coverage
- Focus on business logic
- Don't over-test simple getters/setters
- Prioritize critical paths

### 4. Continuous Testing
- Run tests before committing
- Fix failing tests immediately
- Update tests when changing features
- Add tests for bug fixes

---

## 🔍 Static Code Analysis

### Run Analysis
```bash
flutter analyze
```

### Analysis Configuration
File: `analysis_options.yaml`

Key linting rules:
- Prefer const constructors
- Avoid print statements
- Require trailing commas
- Prefer single quotes
- Sort imports

---

## 📱 Device Testing

### Android Testing
```bash
# List devices
flutter devices

# Run on specific device
flutter run -d device_id

# Run tests on device
flutter drive --target=test_driver/app.dart
```

### Platform Channel Testing
Platform channels require physical device or emulator:
- Voice recording functionality
- File picker
- Permission requests
- Camera access

**Note:** These cannot be unit tested, require integration tests on device.

---

## 🚀 Test Automation

### Pre-commit Testing
Create a git pre-commit hook to run tests automatically:

```bash
#!/bin/sh
# .git/hooks/pre-commit

echo "Running tests..."
flutter test

if [ $? -ne 0 ]; then
  echo "Tests failed. Commit aborted."
  exit 1
fi
```

### Continuous Integration
For CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Run tests
  run: |
    flutter pub get
    flutter analyze
    flutter test --coverage
```

---

## 📊 Test Reports

### Generate Reports
```bash
# Analysis report
flutter analyze > analysis_report.txt

# Test results
flutter test > test_results.txt 2>&1

# Dependency check
flutter pub outdated > pub_outdated.txt

# Environment info
flutter doctor -v > flutter_doctor.txt
```

---

## 🎯 Testing Roadmap

### Phase 1: Current (Completed ✅)
- Basic widget tests
- Offline functionality tests
- Mock infrastructure

### Phase 2: Expand Unit Tests
- [ ] Service layer tests
  - [ ] TodoService
  - [ ] SpaceService
  - [ ] PrayerTimeService
  - [ ] AIAssistant
- [ ] Model tests
- [ ] Helper tests

### Phase 3: Integration Tests
- [ ] End-to-end user flows
- [ ] Multi-screen navigation
- [ ] Data persistence
- [ ] Firebase sync

### Phase 4: UI Tests
- [ ] Screen rendering tests
- [ ] User interaction tests
- [ ] Form validation tests
- [ ] Dialog tests

### Phase 5: Platform Tests
- [ ] Platform channel tests (requires device)
- [ ] Permission handling
- [ ] Voice recording
- [ ] File operations

---

## 📚 Additional Resources

- [Flutter Testing Guide](https://docs.flutter.dev/testing)
- [Widget Testing](https://docs.flutter.dev/cookbook/testing/widget/introduction)
- [Integration Testing](https://docs.flutter.dev/cookbook/testing/integration/introduction)
- [Mockito Package](https://pub.dev/packages/mockito)

---

**Test Status:** ✅ All Tests Passing
**Coverage:** Basic (needs expansion)
**Last Run:** 2025-11-16
**Next Steps:** Expand service layer test coverage
