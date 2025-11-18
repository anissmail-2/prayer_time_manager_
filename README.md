# Prayer Time Manager

A Flutter application for managing prayer times in Abu Dhabi with full permission support for future features.

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Android SDK
- Java JDK 17

### Installation
```bash
# Clone the repository
cd prayer_time_manager

# Get dependencies
flutter pub get

# Run the app
flutter run

# Build APK
flutter build apk --release
```

## 📱 Features Ready for Implementation

### ✅ Permissions (All Configured & Tested)
- **Camera**: Ready for prayer time AR features or QR code scanning
- **Location**: Ready for automatic city detection and Qibla direction
- **Gallery/Photos**: Ready for custom notification backgrounds
- **Microphone**: Ready for voice reminders or Quran recitation
- **Notifications**: Ready for prayer time alerts

### 📁 Project Structure
```
lib/
├── main.dart                    # App entry point
├── screens/
│   └── home_screen.dart         # Main home screen
├── core/
│   └── helpers/
│       ├── permission_helper.dart    # All permission logic
│       └── prayer_time_api.dart      # Prayer time API documentation
├── examples/
│   └── permissions/
│       └── permission_test_screen.dart  # Test all permissions
└── utils/
    └── constants.dart           # App constants
```

## 🔧 Key Components

### Permission Helper (`lib/core/helpers/permission_helper.dart`)
Handles all permission requests with Android 13+ support:
```dart
// Request all permissions
final statuses = await PermissionHelper.requestAllPermissions();

// Check specific permission
bool hasCamera = await PermissionHelper.hasCameraPermission();

// Request specific permission
bool granted = await PermissionHelper.requestCameraPermission();
```

### Prayer Time API (`lib/core/helpers/prayer_time_api.dart`)
Documentation for fetching prayer times:
- Uses Aladhan API (free, no auth required)
- Configured for Abu Dhabi
- Easy to extend for other cities

## 📝 Android Configuration

### Minimum SDK
- minSdk: 23 (Android 6.0)
- targetSdk: 34 (Android 14)

### Permissions in AndroidManifest.xml
All permissions are already configured:
- Camera
- Location (Fine & Coarse)
- Storage/Media (Android 13+ compatible)
- Microphone
- Notifications
- Internet (for API calls)

## 🎯 Next Steps for Development

### 1. Add Prayer Time Features
```bash
# Add http package for API calls
flutter pub add http

# Add shared_preferences for settings
flutter pub add shared_preferences
```

### 2. Implement Notifications
```bash
# Add back the notifications package when ready
flutter pub add flutter_local_notifications
```

### 3. Add Audio Features
```bash
# For audio recording
flutter pub add record

# For Adhan playback
flutter pub add just_audio  # (already added)
```

### 4. Add Islamic Features
- Qibla direction using location + compass
- Prayer time calculations
- Islamic calendar
- Tasbeeh counter

## 🧪 Testing Permissions

1. Open the app
2. Go to "Developer Tools" section
3. Click "Test All Permissions"
4. Test each feature individually

## 📱 Building for Release

```bash
# Build release APK
flutter build apk --release

# APK location
build/app/outputs/flutter-apk/app-release.apk
```

## 🤝 Contributing

This project is structured for easy development:
- All permissions are pre-configured
- Helper classes are ready to use
- Example implementations provided
- Clean separation of concerns

## 📄 License

This project is for personal use.

## 🆘 Troubleshooting

### Permission Issues
- For Android 13+: Photos, Videos, and Audio permissions are separate
- For older Android: Uses combined Storage permission
- All handled automatically by PermissionHelper

### Build Issues
- Ensure NDK version 27.0.12077973 is installed
- Core library desugaring is enabled for compatibility

---

**Note**: All permission implementations are in the `examples/permissions` folder. Don't reinvent the wheel - use what's already there!