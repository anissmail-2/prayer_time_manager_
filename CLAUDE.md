# CLAUDE.md - Complete Project Memory

This file provides comprehensive guidance to Claude Code (claude.ai/code) when working with the TaskFlow Pro (prayer_time_manager) codebase. This is the COMPLETE memory of the project.

## 🎯 Project Overview

**TaskFlow Pro** is a Flutter application that seamlessly integrates professional task management with Islamic prayer times. It provides accurate prayer times for Abu Dhabi, UAE (with global support), and allows users to schedule tasks relative to prayer times while offering AI-powered assistance for productivity optimization.

### Core Identity
- **Current Name**: TaskFlow Pro
- **Legacy Name**: prayer_time_manager (still used in namespace)
- **Package Name**: `taskflow_pro`
- **Namespace**: `com.example.prayer_time_manager`
- **Flutter SDK**: ^3.8.1
- **Min SDK**: 24 (Android 7.0)
- **Target SDK**: 34 (Android 14)

### Key Features
1. **Prayer-Aware Scheduling**: Schedule tasks relative to prayer times (e.g., "15 minutes before Dhuhr")
2. **AI Assistant**: Natural language task/space management with Gemini AI
3. **Offline-First**: Full functionality without internet via automatic caching
4. **Space Organization**: Hierarchical project/context management
5. **Voice Input**: Android-only voice transcription via Deepgram
6. **Timeline View**: Visual daily schedule with prayer blocks
7. **Multi-Platform**: Adaptive UI for mobile, tablet, and desktop

## 🏗️ Architecture Overview

### Design Philosophy
- **No State Management Libraries**: Direct state with `setState()`
- **Static Service Pattern**: All business logic in static service classes
- **Offline-First**: Automatic caching via `StorageHelper`
- **Permission Abstraction**: All permissions through `PermissionHelper`
- **Theme Consistency**: Centralized `AppTheme` for all UI

### Navigation Structure
```
MainLayout (Adaptive Navigation Shell)
├── DashboardScreen (index: 0)
├── AgendaScreen (index: 1)
├── MobileSpacesScreen (index: 2)
├── TimelineScreen (index: 3)
├── AIAssistantScreen (index: 4)
└── PrayerScheduleScreen (index: 5)
```

- **Desktop/Tablet**: Animated collapsible sidebar
- **Mobile**: Navigation drawer
- **Programmatic Navigation**: `MainLayout.navigateTo(index)`

### Directory Structure
```
lib/
├── core/
│   ├── helpers/
│   │   ├── connectivity_helper.dart    # Network monitoring
│   │   ├── permission_helper.dart      # CRITICAL: Centralized permissions
│   │   ├── prayer_time_api.dart        # API documentation
│   │   └── storage_helper.dart         # Offline caching
│   ├── services/
│   │   ├── activity_service.dart       # Events/appointments
│   │   ├── ai_conversation_service.dart # Chat persistence
│   │   ├── enhanced_ai_assistant.dart  # Main AI brain
│   │   ├── gemini_task_assistant.dart  # Task AI suggestions
│   │   ├── location_service.dart       # Location management
│   │   ├── prayer_duration_service.dart # Prayer blocks
│   │   ├── prayer_time_service.dart    # Prayer calculations
│   │   ├── space_service.dart          # Space/project management
│   │   └── todo_service.dart           # Task CRUD operations
│   └── theme/
│       └── app_theme.dart              # UI constants
├── models/
│   ├── activity.dart                   # Events with recurrence
│   ├── chat_message.dart               # AI chat messages
│   ├── enhanced_task.dart              # Extended task model
│   ├── location_settings.dart          # Prayer location config
│   ├── prayer_duration.dart            # Prayer time blocks
│   ├── space.dart                      # Organization containers
│   └── task.dart                       # Core task model
├── screens/
│   ├── main_layout.dart                # Navigation shell
│   ├── dashboard_screen.dart           # Home overview
│   ├── agenda_screen.dart              # Task list view
│   ├── mobile_spaces_screen.dart       # Space management
│   ├── timeline_screen.dart            # Daily timeline
│   ├── ai_assistant_screen.dart        # AI chat interface
│   ├── prayer_schedule_screen.dart     # Prayer times
│   ├── add_edit_item_screen.dart       # Full task form
│   ├── prayer_settings_screen.dart     # Prayer durations
│   └── location_settings_screen.dart   # Location config
├── widgets/
│   ├── enhanced_item_form.dart         # Dialog task form
│   ├── scheduling_section.dart         # Time input widget
│   └── task_details_dialog.dart        # Task viewer
└── utils/
    └── constants.dart                  # App constants
```

## 🔑 Critical Implementation Details

### Prayer Time System

#### API Configuration
- **Primary**: Aladhan API (free, no auth)
- **Endpoint**: `https://api.aladhan.com/v1/timingsByCity`
- **Method**: 16 (Dubai - works for UAE)
- **Tune Parameters**: `0,1,-3,0,1,1,0,0,0` (Abu Dhabi accuracy)
- **Fallback**: Local calculation via Adhan library

#### Prayer-Relative Scheduling Format
```
{prayer}_{when}_{minutes}
Examples:
- dhuhr_before_15 = 15 minutes before Dhuhr
- maghrib_after_10 = 10 minutes after Maghrib
```

#### Supported Prayers
- fajr, dhuhr, asr, maghrib, isha (5 daily prayers)
- sunrise (for Duha/Ishraq timing)

### Task Scheduling System

#### Task Model Features
- **ID Generation**: `DateTime.now().millisecondsSinceEpoch`
- **Dual Scheduling**: Absolute time OR prayer-relative
- **Recurrence Patterns**: 
  - Once, Daily, Weekly (with day selection)
  - Monthly (specific dates or patterns like "first Monday")
  - Yearly
- **Time Blocks**: Support for start and end times
- **Completion Tracking**: Per-date for recurring tasks
- **Space Integration**: Via `#spaceId` tag in description

#### Enhanced Task Features
- Subtask hierarchy
- Status tracking (todo, inProgress, blocked, review, done, cancelled)
- Tags and attachments
- Time tracking (estimated vs actual)

### AI Integration

#### Gemini Configuration
- **API Key**: Configured in `.env` or `app_config.local.dart`
- **Model**: `gemini-2.5-flash-lite-preview-06-17`
- **Temperature**: 0.7 for creativity
- **Setup**: See `SETUP_INSTRUCTIONS.md` for API key configuration

#### Voice Input (Android Only)
- **Deepgram API Key**: Configured in `.env` or `app_config.local.dart`
- **Platform Channel**: `com.awkati.taskflow/audio_recorder`
- **Setup**: See `SETUP_INSTRUCTIONS.md` for API key configuration
- **Custom Implementation**: `MainActivity.kt`

#### AI Assistant Capabilities
1. Natural language task creation
2. Space/project suggestions
3. Schedule analysis and optimization
4. Bulk task operations
5. Context-aware responses
6. Prayer-aware scheduling

### Space System

#### Features
- Hierarchical organization (parent/child spaces)
- Task containment via `#spaceId` tags
- Enhanced tasks (unscheduled ideas)
- Progress tracking
- AI personas per space
- Bulk operations

#### Space-Task Relationship
```dart
// Task contains space reference
task.description = "Task title #spaceId"

// Space tracks items
space.itemIds = ["task1", "task2"]
```

### Permissions (CRITICAL)

#### ⚠️ NEVER call permission_handler directly!
Always use `PermissionHelper`:

```dart
// ✅ CORRECT
await PermissionHelper.requestAllPermissions();
bool hasCamera = await PermissionHelper.hasCameraPermission();

// ❌ WRONG - NEVER DO THIS
await Permission.camera.request(); // DO NOT USE
```

#### Android Version Handling
- **Android 13+**: Granular media permissions (photos, videos, audio)
- **Android <13**: Combined storage permission
- Automatic version detection via device_info_plus

### Data Persistence

#### Storage Keys (SharedPreferences)
- `tasks` - Task list
- `spaces` - Space definitions
- `enhanced_tasks` - Unscheduled ideas
- `activities` - Events/appointments
- `prayer_durations` - Prayer block settings
- `location_settings` - Prayer location
- `ai_conversations` - Chat history
- `current_ai_conversation` - Active chat

#### Offline Strategy
1. All API responses cached automatically
2. Cache validity checked by date
3. Network check before API calls
4. Graceful fallback to cache

## 🛠️ Development Workflow

### Essential Commands
```bash
# Development
flutter run                    # Debug mode
flutter run --release         # Release mode
flutter build apk --release   # Build APK
flutter build apk --debug     # Debug APK

# Code Quality
flutter analyze              # Static analysis
flutter test                 # Run tests

# Maintenance
flutter clean               # Clean build
flutter pub get            # Install dependencies
flutter pub upgrade        # Update dependencies
```

### Testing
- Test directory: `/test/`
- Framework: Standard Flutter testing
- Run: `flutter test`
- Coverage: Widget tests, offline functionality

### Platform Configuration

#### Android Requirements
- **Java**: JDK 17 required
- **NDK**: 27.0.12077973
- **Core Library Desugaring**: Enabled
- **Gradle**: Kotlin DSL (.kts files)

#### Build Configuration
```xml
minSdkVersion 24      // Android 7.0
targetSdkVersion 34   // Android 14
compileSdkVersion 34
```

## 🎨 UI/UX Conventions

### Theme Usage (ALWAYS use AppTheme)
```dart
// Colors
AppTheme.primary        // Main blue
AppTheme.secondary      // Accent orange
AppTheme.success        // Green
AppTheme.error          // Red
AppTheme.prayerColors   // Prayer-specific

// Text Styles
AppTheme.headlineLarge
AppTheme.bodyMedium
AppTheme.labelSmall

// Spacing (8pt grid)
AppTheme.space8   // 8.0
AppTheme.space16  // 16.0
AppTheme.space24  // 24.0

// Radius
AppTheme.radiusSmall   // 4.0
AppTheme.radiusMedium  // 8.0
AppTheme.radiusLarge   // 16.0
```

### Responsive Breakpoints
- **Mobile**: ≤ 600px
- **Tablet**: > 600px and ≤ 1200px
- **Desktop**: > 1200px

### Animation Patterns
- Page transitions: 300ms
- List animations: 500ms with stagger
- Always use `curve: Curves.easeInOut`

## 🔌 Service Integration Patterns

### Service Dependencies
```
EnhancedAIAssistant
├── TodoService (task operations)
├── SpaceService (space management)
├── PrayerTimeService (scheduling)
├── GeminiTaskAssistant (suggestions)
└── AIConversationService (persistence)

TodoService
├── PrayerTimeService (time calculation)
└── SpaceService (space references)

PrayerTimeService
├── LocationService (calculation method)
└── StorageHelper (caching)
```

### Common Flows

#### Task Creation Flow
1. User input → `EnhancedAIAssistant.processMessage()`
2. Intent analysis → Gemini AI
3. Task suggestion → `GeminiTaskAssistant`
4. User confirmation → UI
5. Task creation → `TodoService.createTaskFromSuggestion()`
6. Space linking → Add `#spaceId` tag
7. Time calculation → `PrayerTimeService` if prayer-relative

#### Schedule Analysis Flow
1. Get prayer times → `PrayerTimeService`
2. Calculate blocks → `PrayerDurationService`
3. Get existing tasks → `TodoService`
4. Find free slots → `EnhancedAIAssistant._calculateFreeTimeSlots()`
5. Generate suggestions → Gemini AI

## 🐛 Common Issues & Solutions

### Permission Issues
- **Problem**: Gallery not working on Android 13+
- **Solution**: Use `PermissionHelper.hasGalleryPermission()` which handles version differences

### Prayer Time Accuracy
- **Problem**: Times off by few minutes
- **Solution**: Adjust tune parameters in `PrayerTimeService` or use location settings

### Task Not Showing
- **Problem**: Recurring task missing from today
- **Solution**: Check `shouldShowToday()` logic and recurrence settings

### AI Not Responding
- **Problem**: AI assistant stuck
- **Solution**: Check Gemini API key validity and rate limits

### Build Failures
- **Problem**: Android build fails
- **Solution**: Ensure NDK 27.0.12077973 installed and Java 17 configured

## 🚀 Key Patterns to Remember

### 1. Always Check Connectivity
```dart
if (await ConnectivityHelper.hasInternetConnection()) {
  // Make API call
} else {
  // Use cached data
}
```

### 2. Permission Before Feature
```dart
if (await PermissionHelper.hasMicrophonePermission()) {
  // Start recording
} else {
  // Request permission
}
```

### 3. Prayer-Relative Time Parsing
```dart
final absoluteTime = await PrayerTimeService.calculatePrayerRelativeTime(
  'dhuhr_before_15',
  selectedDate,
);
```

### 4. Space Reference in Tasks
```dart
task.description = "${task.title} #${spaceId}";
```

### 5. Error Handling Pattern
```dart
try {
  // Operation
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

## 📱 Platform Channels

### Audio Recording (Android)
```kotlin
// MainActivity.kt handles:
- startRecording()
- stopRecording()
- pickAudioFile()
```

### Channel Name
`com.example.prayer_time_manager/audio_recorder`

## 🔐 Security Considerations

1. **API Keys**: Currently hardcoded (move to environment variables in production)
2. **Permissions**: Always request minimum necessary
3. **Storage**: No encryption on SharedPreferences
4. **Network**: HTTPS only for API calls

## 📊 Performance Optimization

1. **Image Caching**: Not implemented (consider cached_network_image)
2. **List Performance**: Use `ListView.builder` for long lists
3. **State Updates**: Minimize `setState()` calls
4. **Async Operations**: Show loading indicators

## 🎯 Future Considerations

1. **iOS Support**: Voice input needs iOS implementation
2. **State Management**: Consider Provider/Riverpod for complex state
3. **Testing**: Increase test coverage
4. **Localization**: Add multi-language support
5. **Notifications**: Local notifications for prayer times/tasks

## 📝 Quick Reference

### Must Remember
- ✅ Use `PermissionHelper` for ALL permissions
- ✅ Use `AppTheme` for ALL styling
- ✅ Check connectivity before API calls
- ✅ Parse prayer-relative times properly
- ✅ Add `#spaceId` tags for space integration
- ❌ Never access permission_handler directly
- ❌ Never hardcode colors/dimensions
- ❌ Never skip error handling

### Service Quick Access
- Tasks: `TodoService`
- Spaces: `SpaceService`
- Prayer Times: `PrayerTimeService`
- AI Chat: `EnhancedAIAssistant`
- Activities: `ActivityService`
- Permissions: `PermissionHelper`
- Storage: `StorageHelper`
- Network: `ConnectivityHelper`

This document represents the COMPLETE memory of the TaskFlow Pro project. Every important detail, pattern, and consideration is documented here.