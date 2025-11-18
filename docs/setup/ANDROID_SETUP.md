# Android Setup Guide for TaskFlow Pro

**Last Updated:** 2025-11-18

This guide consolidates all Android setup information for the TaskFlow Pro project.

---

## ✅ Quick Start

### Prerequisites
- Flutter SDK ^3.8.1
- Android SDK (Min 24, Target 36)
- Java JDK 11
- Android NDK 27.0.12077973

### Build Configuration
```
Min SDK: 24 (Android 7.0)
Target SDK: 36 (Android 14+)
Compile SDK: 36
Package: com.awkati.taskflow
```

---

## 🏗️ Building the APK

### Release Build
```bash
flutter build apk --release
```

### Debug Build
```bash
flutter build apk --debug
```

---

## 🐧 WSL Setup (Linux on Windows)

### Overview
If you're using WSL (Windows Subsystem for Linux), there are some special considerations because Flutter in WSL runs Linux executables but the Windows Android SDK contains `.exe` files.

### Solution 1: Use Windows Flutter (RECOMMENDED) ⭐

**Best option** if you have Windows:

```powershell
# In Windows PowerShell or CMD (not WSL)
# Install Flutter for Windows from: https://docs.flutter.dev/get-started/install/windows

# Navigate to project
cd D:\path\to\prayer_time_manager

# Build APK
flutter build apk --release
```

**Advantages:**
- ✅ Uses Windows Android SDK directly
- ✅ All build tools work perfectly
- ✅ Fastest build times
- ✅ No WSL limitations

### Solution 2: Install Linux Build Tools

If you prefer using WSL:

```bash
# Install Linux Android build tools
sudo apt install -y google-android-build-tools-34.0.0-installer

# Create symlinks to Windows SDK
ANDROID_SDK="/mnt/d/users/YOUR_USERNAME/AppData/Local/Android/Sdk"
BUILD_TOOLS_SRC="/usr/lib/android-sdk/build-tools/34.0.0"
BUILD_TOOLS_DST="$ANDROID_SDK/build-tools/34.0.0"

sudo ln -sf $BUILD_TOOLS_SRC/aapt $BUILD_TOOLS_DST/aapt
sudo ln -sf $BUILD_TOOLS_SRC/aapt2 $BUILD_TOOLS_DST/aapt2
sudo ln -sf $BUILD_TOOLS_SRC/aidl $BUILD_TOOLS_DST/aidl
sudo ln -sf $BUILD_TOOLS_SRC/zipalign $BUILD_TOOLS_DST/zipalign

# Create adb symlink
sudo ln -s /usr/bin/adb $ANDROID_SDK/platform-tools/adb
```

---

## 🔧 Common Issues & Solutions

### Issue 1: "Build Tools revision XX is corrupted"
**Cause:** WSL trying to use Windows .exe files
**Solution:** Use Windows Flutter or install Linux build tools (see above)

### Issue 2: "adb not found"
**Cause:** WSL cannot execute Windows adb.exe
**Solution:** Install adb in WSL: `sudo apt install adb`

### Issue 3: Flutter Doctor Shows Android Toolchain Issues
**Cause:** Missing build tools or SDK path issues
**Solution:** Run `flutter doctor -v` to see specific errors, then:
```bash
# Accept all licenses
flutter doctor --android-licenses

# Verify setup
flutter doctor -v
```

### Issue 4: Gradle Build Fails
**Cause:** NDK version mismatch or missing dependencies
**Solution:**
1. Ensure NDK 27.0.12077973 is installed
2. Check android/app/build.gradle.kts has correct NDK version
3. Run `flutter clean && flutter pub get`

---

## 📱 Platform Channel Implementation

TaskFlow Pro uses custom platform channels for voice recording (Android only).

### Implementation Location
`android/app/src/main/kotlin/com/awkati/taskflow/MainActivity.kt`

### Channels
1. **Audio Recorder**: `com.awkati.taskflow/audio_recorder`
   - `startRecording()`: Start audio recording
   - `stopRecording()`: Stop and save recording
   - `isRecording()`: Check recording status

2. **File Picker**: `com.awkati.taskflow/file_picker`
   - `pickAudioFile()`: Open system file picker

---

## 🔐 Permissions

Configured in `android/app/src/main/AndroidManifest.xml`

### Required Permissions
- `INTERNET` - API calls
- `ACCESS_NETWORK_STATE` - Connectivity detection
- `RECORD_AUDIO` - Voice input
- `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` - Prayer times
- `POST_NOTIFICATIONS` - Notifications (Android 13+)

### Version-Aware Permissions
- Android < 13: `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`
- Android 13+: `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`

---

## 🚀 Success Checklist

After setup, verify everything works:

```bash
# 1. Flutter doctor should show all ✓
flutter doctor -v

# Expected output:
# [✓] Flutter (Channel stable, 3.X.X)
# [✓] Android toolchain - develop for Android devices
# [✓] Connected device (if phone connected)
# [✓] Network resources

# 2. Clean build should succeed
flutter clean
flutter pub get
flutter build apk --debug

# 3. App should run
flutter run
```

---

## 📚 Additional Resources

- [Flutter Android Setup](https://docs.flutter.dev/get-started/install/linux#android-setup)
- [Android SDK Command-line Tools](https://developer.android.com/studio/command-line)
- [WSL Android Development Guide](https://docs.microsoft.com/en-us/windows/android/wsl)

---

## 🎯 Project-Specific Notes

### Firebase Configuration
- Firebase is configured but sync is disabled by default
- To enable: Set `enableFirebaseSync = true` in `lib/core/config/app_config.dart`

### Voice Input (Android Only)
- Requires Deepgram API key
- Configure in `.env` file (see `.env.example`)
- Platform channel implementation in `MainActivity.kt`

### Build Variants
- **Debug**: Full logging, slower performance
- **Release**: Optimized, minified, ProGuard enabled
- **Profile**: Performance profiling enabled

---

**Status:** ✅ Setup Complete
**Last Verified:** 2025-11-16
**Platform:** Android 7.0+ (API 24-36)
