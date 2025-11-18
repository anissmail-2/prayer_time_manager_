# Android SDK Setup Guide for WSL

**Date:** 2025-11-16
**Issue:** Flutter cannot find Android build tools in WSL because Windows SDK has .exe files
**Solution:** Install Linux build-tools and create symlinks

---

## 🔍 Problem Diagnosis

Your setup:
- ✅ **Windows Android SDK:** `/mnt/d/users/anis/AppData/Local/Android/Sdk` (has .exe files)
- ✅ **Linux adb:** `/usr/bin/adb` (already installed)
- ❌ **Missing:** Linux build-tools (aapt, aapt2, aidl, zipalign)

**Root cause:** WSL runs Linux Flutter which needs Linux executables, but your SDK has Windows .exe files.

---

## 🛠️ Complete Setup Instructions

### Step 1: Set Up Passwordless Sudo (Optional but Recommended)

Run this command **ONCE** (it will ask for password one last time):

```bash
sudo bash -c 'echo "anis ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/anis && chmod 0440 /etc/sudoers.d/anis'
```

**What it does:** Allows you to run `sudo` without password in future commands.

---

### Step 2: Install Linux Android Build-Tools

```bash
sudo apt install -y google-android-build-tools-34.0.0-installer
```

**What it does:** Installs Linux versions of Android build tools to `/usr/lib/android-sdk/build-tools/34.0.0/`

**Time:** ~30 seconds

---

### Step 3: Create Symlinks to Windows SDK Path

Flutter expects tools in the Windows SDK path, so we'll create symlinks:

```bash
# Link aapt
sudo ln -sf /usr/lib/android-sdk/build-tools/34.0.0/aapt /mnt/d/users/anis/AppData/Local/Android/Sdk/build-tools/35.0.1/aapt

# Link aapt2
sudo ln -sf /usr/lib/android-sdk/build-tools/34.0.0/aapt2 /mnt/d/users/anis/AppData/Local/Android/Sdk/build-tools/35.0.1/aapt2

# Link aidl
sudo ln -sf /usr/lib/android-sdk/build-tools/34.0.0/aidl /mnt/d/users/anis/AppData/Local/Android/Sdk/build-tools/35.0.1/aidl

# Link zipalign
sudo ln -sf /usr/lib/android-sdk/build-tools/34.0.0/zipalign /mnt/d/users/anis/AppData/Local/Android/Sdk/build-tools/35.0.1/zipalign
```

**What it does:** Makes Linux tools available at the path where Flutter expects them.

---

### Step 4: Verify Setup

```bash
flutter doctor -v
```

**Expected output:**
- ✅ Android toolchain should now show green checkmark
- ✅ No more "adb not found" or "aapt not found" errors

---

### Step 5: Test Android Build

```bash
# Check connected devices
adb devices

# Try building the app for Android (debug mode)
cd /home/anis/Projects/MINE/prayer_time_manager
flutter build apk --debug
```

---

## 📋 Quick Command Summary

Copy and paste these commands in order:

```bash
# 1. Passwordless sudo (optional)
sudo bash -c 'echo "anis ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/anis && chmod 0440 /etc/sudoers.d/anis'

# 2. Install build-tools
sudo apt install -y google-android-build-tools-34.0.0-installer

# 3. Create all symlinks at once
sudo ln -sf /usr/lib/android-sdk/build-tools/34.0.0/aapt /mnt/d/users/anis/AppData/Local/Android/Sdk/build-tools/35.0.1/aapt && \
sudo ln -sf /usr/lib/android-sdk/build-tools/34.0.0/aapt2 /mnt/d/users/anis/AppData/Local/Android/Sdk/build-tools/35.0.1/aapt2 && \
sudo ln -sf /usr/lib/android-sdk/build-tools/34.0.0/aidl /mnt/d/users/anis/AppData/Local/Android/Sdk/build-tools/35.0.1/aidl && \
sudo ln -sf /usr/lib/android-sdk/build-tools/34.0.0/zipalign /mnt/d/users/anis/AppData/Local/Android/Sdk/build-tools/35.0.1/zipalign

# 4. Verify
flutter doctor -v

# 5. Test
cd /home/anis/Projects/MINE/prayer_time_manager
flutter build apk --debug
```

---

## ✅ What's Already Done

From our previous session:
- ✅ Created symlink: `adb` → `/usr/bin/adb`
- ✅ Code compiles with 0 errors
- ✅ Linux build works perfectly

---

## 🔧 Alternative Solutions

If the above doesn't work, you have these options:

### Option A: Install Complete Linux Android SDK
```bash
# Download Android command-line tools
cd ~
wget https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip
unzip commandlinetools-linux-9477386_latest.zip
mkdir -p ~/android-sdk/cmdline-tools
mv cmdline-tools ~/android-sdk/cmdline-tools/latest

# Update your .bashrc
echo 'export ANDROID_HOME="$HOME/android-sdk"' >> ~/.bashrc
echo 'export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"' >> ~/.bashrc
source ~/.bashrc

# Install SDK components
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
```

### Option B: Use Windows Flutter Instead
Instead of WSL Flutter, use Windows PowerShell/CMD with Windows Flutter installation. Windows Flutter will work perfectly with Windows Android SDK.

### Option C: Use Docker
Run Flutter in a Docker container with pre-configured Android SDK.

---

## 🐛 Troubleshooting

### Issue: "aapt not found" still appears
**Solution:** Check symlink was created:
```bash
ls -la /mnt/d/users/anis/AppData/Local/Android/Sdk/build-tools/35.0.1/aapt
```
Should show: `... -> /usr/lib/android-sdk/build-tools/34.0.0/aapt`

### Issue: "Permission denied"
**Solution:** Make sure you used `sudo` for symlink commands

### Issue: Package not found
**Solution:** Update package list first:
```bash
sudo apt update
```

### Issue: Different build-tools version
If Flutter expects a different version (not 35.0.1), replace in commands:
```bash
# Check what version Flutter wants
flutter doctor -v | grep build-tools

# Use that version in symlink paths
```

---

## 📊 File Locations Reference

| Component | Windows Path | Linux Path |
|-----------|-------------|------------|
| Android SDK | `/mnt/d/users/anis/AppData/Local/Android/Sdk` | `/usr/lib/android-sdk` |
| adb | `platform-tools/adb.exe` (Windows) | `/usr/bin/adb` (Linux) ✅ |
| build-tools | `build-tools/35.0.1/*.exe` (Windows) | `/usr/lib/android-sdk/build-tools/34.0.0/*` (Linux) |
| aapt | `build-tools/35.0.1/aapt.exe` ❌ | Symlink to Linux version ⚠️ |

---

## 🎯 Expected Results

After completing all steps:

```bash
$ flutter doctor -v
[✓] Flutter (Channel stable, 3.x.x)
[✓] Android toolchain - develop for Android devices (Android SDK version 35.0.1)
    • Android SDK at /mnt/d/users/anis/AppData/Local/Android/Sdk
    • Platform android-36, build-tools 35.0.1
    • ANDROID_HOME = /mnt/d/users/anis/AppData/Local/Android/Sdk
    • Java binary at: ...
    • All Android licenses accepted.
[✓] Chrome - develop for the web
[✓] Linux toolchain - develop for Linux desktop
[✓] Connected device (X available)
[✓] Network resources

! Doctor found issues in 0 categories.
```

---

## 💡 Why This Works

1. **adb symlink:** Links Windows SDK path to Linux adb binary
2. **build-tools symlinks:** Links Windows SDK path to Linux build tools
3. **Flutter detects:** Tools at expected Windows SDK paths
4. **Linux executables run:** Because symlinks point to Linux binaries
5. **Best of both worlds:** Keep Windows SDK, use Linux tools

---

## 📝 Notes

- Symlinks are permanent until deleted
- Linux build-tools version (34.0.0) vs Windows (35.0.1) is fine - compatible
- You only need to do this setup once
- If Windows SDK updates, you may need to recreate symlinks

---

**Ready to proceed?** Copy the commands from "Quick Command Summary" above!
