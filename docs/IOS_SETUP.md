# iOS Setup Guide - TaskFlow Pro

Complete guide for setting up and building TaskFlow Pro for iOS.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Firebase Configuration](#firebase-configuration)
- [Xcode Setup](#xcode-setup)
- [Permissions](#permissions)
- [Building](#building)
- [Voice Input](#voice-input)
- [Troubleshooting](#troubleshooting)

---

## 🔧 Prerequisites

### Required Software

1. **macOS** (Monterey 12.0+ recommended)
2. **Xcode** 14.0 or later
   ```bash
   xcode-select --install
   ```

3. **CocoaPods** (Dependency Manager)
   ```bash
   sudo gem install cocoapods
   ```

4. **Flutter** (3.24.0+ recommended)
   ```bash
   flutter doctor
   ```

### System Requirements

- macOS 12.0 (Monterey) or later
- Xcode 14.0+
- 8GB RAM minimum (16GB recommended)
- 20GB free disk space

---

## 🔥 Firebase Configuration

### Step 1: Create iOS App in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project (or create one)
3. Click "Add App" → iOS
4. Enter Bundle ID: `com.awkati.taskflow`
5. Download `GoogleService-Info.plist`

### Step 2: Add Firebase Configuration

```bash
# Replace the example file with your real configuration
cp path/to/GoogleService-Info.plist ios/Runner/GoogleService-Info.plist
```

**Important:** The `GoogleService-Info.plist.example` file is just a template. You MUST replace it with your actual Firebase configuration.

### Step 3: Verify Configuration

Check that your `GoogleService-Info.plist` contains real values (not "YOUR_"):

```xml
<key>BUNDLE_ID</key>
<string>com.awkati.taskflow</string>
<key>API_KEY</key>
<string>Your-Actual-API-Key-Here</string>
```

---

## 📱 Xcode Setup

### Step 1: Install Dependencies

```bash
cd ios
pod install
cd ..
```

This will:
- Install Flutter dependencies
- Install Firebase SDKs
- Configure CocoaPods workspace

### Step 2: Open Project in Xcode

```bash
open ios/Runner.xcworkspace
```

**Important:** Always open `Runner.xcworkspace`, NOT `Runner.xcodeproj`!

### Step 3: Configure Signing

1. In Xcode, select the **Runner** target
2. Go to **Signing & Capabilities** tab
3. Select your **Team**
4. Xcode will automatically generate a provisioning profile

**Bundle Identifier:** `com.awkati.taskflow`

### Step 4: Update Deployment Target

1. Select **Runner** project (top of file navigator)
2. Select **Runner** target
3. **General** tab → **Deployment Info**
4. Set **iOS Deployment Target** to **13.0**

---

## 🔐 Permissions

TaskFlow Pro requires the following iOS permissions:

### Configured in Info.plist

| Permission | Purpose | Required |
|------------|---------|----------|
| **Camera** | Take photos for task attachments | Optional |
| **Photo Library** | Attach photos to tasks | Optional |
| **Microphone** | Voice input for tasks | Optional |
| **Speech Recognition** | Convert voice to text | Optional |
| **Location (When In Use)** | Accurate prayer times | Required |
| **Notifications** | Prayer & task reminders | Optional |

### Permission Descriptions

All permissions include user-friendly descriptions explaining why access is needed:

```xml
<key>NSCameraUsageDescription</key>
<string>TaskFlow Pro needs camera access to take photos for task attachments</string>
```

These descriptions appear in iOS permission dialogs.

---

## 🏗️ Building

### Debug Build (for testing)

```bash
# Build and run on simulator
flutter run -d iPhone

# Build and run on physical device
flutter run -d <device-id>

# List available devices
flutter devices
```

### Release Build

```bash
# Build release IPA
flutter build ios --release

# Build for specific device
flutter build ios --release --no-codesign
```

### Archive for App Store

1. Open Xcode → **Product** → **Archive**
2. Wait for archive to complete
3. **Window** → **Organizer**
4. Select archive → **Distribute App**
5. Follow wizard for App Store submission

---

## 🎤 Voice Input

TaskFlow Pro includes native iOS voice recording and speech recognition.

### Features

1. **Audio Recording** - Record voice notes
   - Format: M4A (AAC)
   - Quality: High (44.1kHz)
   - Storage: Temporary directory

2. **Speech Recognition** - Real-time transcription
   - Language: English (US)
   - Partial results: Yes
   - Offline support: Limited

### Implementation Details

**AppDelegate.swift** handles:
- `startRecording()` - Begin audio recording
- `stopRecording()` - End and save recording
- `startSpeechRecognition()` - Begin live transcription
- `stopSpeechRecognition()` - End transcription

**Method Channel:** `com.awkati.taskflow/audio_recorder`

### Usage in Flutter

```dart
// Platform channel
static const platform = MethodChannel('com.awkati.taskflow/audio_recorder');

// Start recording
final filePath = await platform.invokeMethod('startRecording');

// Stop recording
final savedPath = await platform.invokeMethod('stopRecording');

// Speech recognition
await platform.invokeMethod('startSpeechRecognition');
await platform.invokeMethod('stopSpeechRecognition');
```

### Testing Voice Input

1. Run app on physical device (simulator doesn't support microphone)
2. Grant microphone permission when prompted
3. Grant speech recognition permission when prompted
4. Try voice input in task creation

---

## 🎨 App Icon & Launch Screen

### App Icon

**Location:** `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

**Required Sizes:**
- 20x20 @2x, @3x
- 29x29 @2x, @3x
- 40x40 @2x, @3x
- 60x60 @2x, @3x
- 1024x1024 @1x (App Store)

**To Update:**
1. Generate all required sizes
2. Place in `AppIcon.appiconset/` folder
3. Update `Contents.json` filenames

### Launch Screen

**Location:** `ios/Runner/Base.lproj/LaunchScreen.storyboard`

**Current Design:**
- White background
- Centered app logo (200x200)
- "TaskFlow Pro" title below logo
- Primary brand color (#3589EC)

**To Customize:**
1. Open in Xcode Interface Builder
2. Modify colors, layout, or add images
3. Test on different screen sizes

---

## 🐛 Troubleshooting

### Common Issues

#### 1. Pod Install Fails

**Problem:**
```
[!] CocoaPods could not find compatible versions for pod "Firebase/Core"
```

**Solution:**
```bash
cd ios
rm Podfile.lock
rm -rf Pods
pod repo update
pod install
cd ..
```

#### 2. Signing Errors

**Problem:**
```
No signing certificate "iOS Development" found
```

**Solution:**
1. Xcode → Preferences → Accounts
2. Add your Apple ID
3. Download Manual Profiles
4. Select Team in project settings

#### 3. GoogleService-Info.plist Not Found

**Problem:**
```
error: GoogleService-Info.plist not found
```

**Solution:**
```bash
# Make sure you've replaced the example file
ls -la ios/Runner/GoogleService-Info.plist

# If it's missing, add your actual Firebase config
cp path/to/GoogleService-Info.plist ios/Runner/
```

#### 4. Speech Recognition Not Working

**Problem:** No transcription appears

**Checklist:**
- ✅ Running on physical device (not simulator)
- ✅ Microphone permission granted
- ✅ Speech recognition permission granted
- ✅ Internet connection (for cloud recognition)
- ✅ English language selected on device

#### 5. Build Number Errors

**Problem:**
```
error: Unsupported value for FLUTTER_BUILD_NUMBER
```

**Solution:**
```bash
# In ios/Flutter/Generated.xcconfig, ensure:
FLUTTER_BUILD_NUMBER=1
FLUTTER_BUILD_NAME=1.0.0
```

#### 6. Xcode Version Too Old

**Problem:**
```
error: Xcode 14.0 or higher is required
```

**Solution:**
1. Update Xcode from App Store
2. Run `sudo xcode-select --switch /Applications/Xcode.app`
3. Run `xcodebuild -version` to verify

---

## 📊 Deployment Checklist

Before submitting to App Store:

### Pre-Submission

- [ ] Update version number in `pubspec.yaml`
- [ ] Update build number (must increment)
- [ ] Test on multiple devices/iOS versions
- [ ] Verify all permissions work
- [ ] Test voice input on physical device
- [ ] Check Firebase integration
- [ ] Test prayer time calculations
- [ ] Verify notifications work
- [ ] Test offline functionality

### App Store Assets

- [ ] App icon (1024x1024)
- [ ] Screenshots (6.5" and 5.5" displays)
- [ ] App preview video (optional)
- [ ] App description
- [ ] Keywords
- [ ] Support URL
- [ ] Privacy policy URL

### Compliance

- [ ] Export Compliance (encryption declaration)
- [ ] Privacy Nutrition Labels
- [ ] IDFA usage declaration
- [ ] Age rating

---

## 🎯 Build Configurations

TaskFlow Pro supports three build configurations:

### Debug

- Development signing
- Debug symbols included
- Console logging enabled
- Firebase debug mode

```bash
flutter run --debug
```

### Profile

- Release signing
- Performance profiling enabled
- Some logging enabled

```bash
flutter run --profile
```

### Release

- Release signing
- Optimized code
- Minimal logging
- Production Firebase

```bash
flutter build ios --release
```

---

## 📚 Additional Resources

### Apple Documentation

- [iOS App Distribution Guide](https://developer.apple.com/ios/submit/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

### Firebase Documentation

- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [Firebase Auth for iOS](https://firebase.google.com/docs/auth/ios/start)
- [Cloud Firestore for iOS](https://firebase.google.com/docs/firestore/quickstart)

### Flutter Documentation

- [Building iOS Apps](https://docs.flutter.dev/deployment/ios)
- [Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)
- [iOS Deployment](https://docs.flutter.dev/deployment/ios)

---

## 🔄 Continuous Integration

For automated iOS builds in CI/CD, see: `.github/workflows/ci.yml`

**Requirements:**
- macOS runner (GitHub Actions)
- Fastlane (recommended)
- App Store Connect API key
- Signing certificates in CI

---

## ✅ Verification Steps

After setup, verify everything works:

```bash
# 1. Check Flutter doctor
flutter doctor -v

# 2. Check iOS devices
flutter devices

# 3. Build in debug mode
flutter build ios --debug --no-codesign

# 4. Run on simulator
flutter run -d "iPhone 14 Pro"

# 5. Test on physical device
flutter run -d <your-device-id>
```

Expected output: App builds and runs without errors.

---

## 📞 Support

If you encounter issues:

1. Check this guide's Troubleshooting section
2. Review Flutter doctor output: `flutter doctor -v`
3. Check Xcode build logs
4. Verify Firebase configuration
5. Open issue on GitHub repository

---

**iOS Setup Complete! 🎉**

Your TaskFlow Pro app is now configured for iOS development and deployment.
