# iOS Platform - TaskFlow Pro

This directory contains the iOS-specific code and configuration for TaskFlow Pro.

## 📁 Directory Structure

```
ios/
├── Podfile                         # CocoaPods dependencies
├── Runner/                         # Main iOS app target
│   ├── AppDelegate.swift          # App entry point + voice input
│   ├── Info.plist                 # App configuration & permissions
│   ├── GoogleService-Info.plist   # Firebase configuration (GITIGNORED)
│   ├── Assets.xcassets/           # App icon & launch images
│   └── Base.lproj/                # Localized resources
│       └── LaunchScreen.storyboard
├── Runner.xcodeproj/              # Xcode project
└── Runner.xcworkspace/            # CocoaPods workspace
```

## 🚀 Quick Start

### 1. Install Dependencies

```bash
cd ios
pod install
cd ..
```

### 2. Configure Firebase

1. Download `GoogleService-Info.plist` from Firebase Console
2. Place it in `ios/Runner/` directory
3. **Do NOT commit to git** (it's gitignored for security)

### 3. Open in Xcode

```bash
open ios/Runner.xcworkspace
```

**Important:** Always open `.xcworkspace`, not `.xcodeproj`!

### 4. Run

```bash
# Run on simulator
flutter run -d iPhone

# Run on physical device
flutter run -d <device-id>
```

## 🎤 Voice Input Implementation

The iOS app includes native voice recording and speech recognition.

**File:** `Runner/AppDelegate.swift`

**Features:**
- Audio recording (M4A format)
- Real-time speech recognition
- Microphone permission handling
- Speech recognition permission handling

**Method Channel:** `com.awkati.taskflow/audio_recorder`

**Methods:**
- `startRecording()` - Begin audio recording
- `stopRecording()` - End recording and get file path
- `startSpeechRecognition()` - Begin live transcription
- `stopSpeechRecognition()` - End transcription
- `requestMicrophonePermission()` - Request mic access
- `requestSpeechPermission()` - Request speech access

## 🔐 Required Permissions

Configured in `Info.plist`:

- **Camera** - Photo attachments
- **Photo Library** - Image attachments
- **Microphone** - Voice input
- **Speech Recognition** - Voice-to-text
- **Location** - Prayer times
- **Notifications** - Prayer & task reminders

## 📦 Dependencies (via CocoaPods)

Managed in `Podfile`:

- Firebase/Core
- Firebase/Auth
- Firebase/Firestore
- Firebase/Analytics
- Firebase/Crashlytics
- GoogleSignIn

## 🏗️ Building

### Debug Build
```bash
flutter build ios --debug
```

### Release Build
```bash
flutter build ios --release
```

### Archive (for App Store)
1. Open Xcode
2. Product → Archive
3. Distribute to App Store

## ⚙️ Configuration

### Bundle Identifier
`com.awkati.taskflow`

### Minimum iOS Version
iOS 13.0

### Supported Devices
- iPhone (all models iOS 13+)
- iPad (all models iOS 13+)

### Supported Orientations
- Portrait
- Landscape Left
- Landscape Right
- Portrait Upside Down (iPad only)

## 🐛 Troubleshooting

### Pod Install Fails

```bash
cd ios
rm Podfile.lock
rm -rf Pods
pod repo update
pod install
```

### Signing Issues

1. Xcode → Preferences → Accounts
2. Add your Apple ID
3. Download Manual Profiles
4. Select Team in Runner target settings

### Voice Input Not Working

- Must run on physical device (simulator lacks microphone)
- Grant microphone permission
- Grant speech recognition permission
- Check internet connection (for cloud recognition)

## 📚 Documentation

For detailed iOS setup instructions, see:
**`/docs/IOS_SETUP.md`**

## 🔗 Resources

- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [CocoaPods Guide](https://guides.cocoapods.org/)
- [Xcode Documentation](https://developer.apple.com/documentation/)

---

**Need Help?**

Check `/docs/IOS_SETUP.md` for comprehensive setup instructions and troubleshooting.
