# Setup Instructions for TaskFlow Pro

## 🔐 Required Configuration (First Time Setup)

Before running the app, you need to configure your API keys and Firebase settings.

### 1. Environment Variables (.env)

```bash
# Copy the example file
cp .env.example .env

# Edit .env and add your real API keys
nano .env  # or use your preferred editor
```

Required keys:
- `GEMINI_API_KEY` - Get from https://makersuite.google.com/app/apikey
- `DEEPGRAM_API_KEY` - Get from https://console.deepgram.com/
- `FIREBASE_API_KEY` - Get from Firebase Console
- `FIREBASE_PROJECT_ID` - Your Firebase project ID

### 2. App Configuration (Optional Alternative)

If you prefer Dart configuration over .env:

```bash
# Copy the example file
cp lib/core/config/app_config.local.dart.example lib/core/config/app_config.local.dart

# Edit and add your API keys
nano lib/core/config/app_config.local.dart
```

### 3. Firebase Configuration (If using Firebase sync)

```bash
# Copy the example file
cp android/app/google-services.json.example android/app/google-services.json

# Get your actual google-services.json from Firebase Console:
# 1. Go to https://console.firebase.google.com/
# 2. Select your project
# 3. Go to Project Settings > Your Apps > Android App
# 4. Download google-services.json
# 5. Replace the example file with your downloaded file
```

## ⚠️ Security Notice

**NEVER commit these files to git:**
- `.env` (gitignored)
- `android/app/google-services.json` (gitignored)
- `lib/core/config/app_config.local.dart` (gitignored)

Only commit the `.example` versions!

## ✅ Verify Setup

Run this to check if everything is configured:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

If you see warnings about missing API keys, check your configuration files.

## 📚 More Information

- See [README.md](README.md) for general information
- See [docs/CLAUDE.md](docs/CLAUDE.md) for architecture details
- See [docs/setup/ANDROID_SETUP.md](docs/setup/ANDROID_SETUP.md) for Android-specific setup
