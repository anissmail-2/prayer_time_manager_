# TaskFlow Pro

A Flutter application that seamlessly integrates professional task management with Islamic prayer times. Schedule tasks relative to prayer times, leverage AI-powered assistance, and maintain productivity with prayer-aware planning.

![Flutter](https://img.shields.io/badge/Flutter-3.8.1+-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)
![License](https://img.shields.io/badge/License-Private-red)

---

## ✨ Features

- **Prayer-Aware Scheduling** - Schedule tasks relative to prayer times (e.g., "15 minutes before Dhuhr")
- **AI Assistant** - Natural language task management powered by Google Gemini
- **Offline-First** - Full functionality without internet via automatic caching
- **Space Organization** - Hierarchical project/context management
- **Voice Input** - Android voice transcription via Deepgram (Android only)
- **Timeline View** - Visual daily schedule with prayer time blocks
- **Cloud Sync** - Optional Firebase synchronization
- **Multi-Platform UI** - Adaptive design for mobile, tablet, and desktop

---

## 🚀 Quick Start

### Prerequisites

- Flutter SDK ^3.8.1
- Dart SDK (included with Flutter)
- Android SDK (Min API 24, Target API 36)
- Java JDK 11

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd prayer_time_manager_
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure API keys**
   ```bash
   # Copy the example environment file
   cp .env.example .env

   # Edit .env and add your API keys
   # - GEMINI_API_KEY (for AI features)
   # - DEEPGRAM_API_KEY (for voice input)
   # - FIREBASE_API_KEY (for cloud sync)
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

5. **Build APK**
   ```bash
   flutter build apk --release
   ```

---

## 📁 Project Structure

```
prayer_time_manager_/
├── lib/                        # Main source code
│   ├── core/                   # Core functionality
│   │   ├── config/            # App configuration
│   │   ├── helpers/           # Utility classes
│   │   ├── services/          # Business logic services
│   │   └── theme/             # UI theme system
│   ├── models/                # Data models
│   ├── screens/               # UI screens
│   ├── widgets/               # Reusable widgets
│   └── main.dart              # Entry point
├── test/                      # Test files
├── android/                   # Android platform code
├── docs/                      # Documentation
│   ├── CLAUDE.md              # Complete project memory
│   ├── README.md              # Detailed documentation
│   ├── setup/                 # Setup guides
│   ├── testing/               # Testing documentation
│   └── archive/               # Historical documents
├── scripts/                   # Utility scripts
├── .env.example              # Environment template
└── pubspec.yaml              # Dependencies
```

---

## 📚 Documentation

### Essential Reading
- **[CLAUDE.md](docs/CLAUDE.md)** - Complete project memory and architecture guide
- **[Detailed README](docs/README.md)** - Comprehensive project documentation

### Setup Guides
- **[Android Setup](docs/setup/ANDROID_SETUP.md)** - Android build configuration and troubleshooting

### Testing
- **[Testing Guide](docs/testing/TESTING_GUIDE.md)** - How to run and write tests

### Scripts
- **[GO.sh](scripts/GO.sh)** - Development helper script
- **[deploy-web.sh](scripts/deploy-web.sh)** - Web deployment script

---

## 🏗️ Architecture

### Design Principles
- **No State Management Libraries** - Direct state with `setState()`
- **Static Service Pattern** - All business logic in static service classes
- **Offline-First** - Automatic caching via `StorageHelper`
- **Permission Abstraction** - Centralized `PermissionHelper`
- **Theme Consistency** - Single source via `AppTheme`

### Key Services
- **TodoService** - Task CRUD operations
- **PrayerTimeService** - Prayer time calculations
- **EnhancedAIAssistant** - AI-powered task management
- **SpaceService** - Project organization
- **DataSyncService** - Firebase cloud sync
- **PermissionHelper** - Centralized permission management

### Navigation
- **MainLayout** - Adaptive navigation shell
  - Mobile: Navigation drawer
  - Desktop/Tablet: Collapsible sidebar
- 6 main screens: Dashboard, Agenda, Spaces, Timeline, AI Assistant, Prayer Schedule

---

## 🧪 Testing

### Run Tests
```bash
# All tests
flutter test

# Specific test file
flutter test test/offline_functionality_test.dart

# With coverage
flutter test --coverage
```

### Current Status
✅ 4/4 tests passing (100%)
- Widget tests
- Offline functionality tests
- Network connectivity tests

See [Testing Guide](docs/testing/TESTING_GUIDE.md) for details.

---

## 🔧 Development

### Essential Commands
```bash
# Run app in debug mode
flutter run

# Run in release mode
flutter run --release

# Static analysis
flutter analyze

# Format code
flutter format lib/ test/

# Clean build
flutter clean && flutter pub get

# Check outdated packages
flutter pub outdated
```

### Code Quality
- Linting enabled via `analysis_options.yaml`
- Flutter lints ^5.0.0
- Run `flutter analyze` before committing

---

## 🔐 Configuration

### Environment Variables (.env)
```bash
GEMINI_API_KEY=your_gemini_api_key_here
DEEPGRAM_API_KEY=your_deepgram_api_key_here
FIREBASE_API_KEY=your_firebase_api_key_here
FIREBASE_PROJECT_ID=your_project_id_here
```

**Security:** Never commit `.env` file with real keys! Use `.env.example` as template.

### App Configuration
- **Location**: `lib/core/config/app_config.dart`
- **Local overrides**: `lib/core/config/app_config.local.dart` (gitignored)
- **Package name**: `com.awkati.taskflow`

---

## 📱 Platform Support

### Android ✅
- Min SDK: 24 (Android 7.0)
- Target SDK: 36 (Android 14+)
- Platform channels: Voice recording, file picker
- Full feature support

### iOS ⚠️
- Not currently supported
- Requires platform channel implementation

### Web 🔧
- Basic support (limited features)

### Desktop (Linux) 🔧
- Limited support
- UI works, some features disabled

---

## 🤝 Contributing

### Before Committing
1. Run tests: `flutter test`
2. Check analysis: `flutter analyze`
3. Format code: `flutter format .`
4. Update documentation if needed

### Commit Guidelines
- Clear, descriptive commit messages
- Reference issues when applicable
- Don't commit API keys or secrets

---

## 📖 Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Flutter Testing](https://docs.flutter.dev/testing)
- [Android Development](https://developer.android.com/)

---

## 📄 License

Private project. All rights reserved.

---

## 🙏 Prayer Times API

Uses [Aladhan API](https://aladhan.com/prayer-times-api) for accurate prayer times worldwide.

---

**Package Name:** `taskflow_pro`
**Namespace:** `com.awkati.taskflow`
**Current Version:** Development
**Last Updated:** 2025-11-18
