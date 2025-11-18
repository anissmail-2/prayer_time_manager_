#!/bin/bash

# 🚀 SUPER SIMPLE - JUST RUN: ./GO.sh

echo "🚀 TaskFlow Pro - Auto Everything!"
echo "================================="

# Sync function
sync_to_windows() {
    rsync -aq --delete \
        --exclude='.git' \
        --exclude='build' \
        --exclude='.dart_tool' \
        --exclude='android/.gradle' \
        --exclude='android/local.properties' \
        --exclude='.flutter-plugins-dependencies' \
        /home/anis/Projects/MINE/prayer_time_manager/ \
        /mnt/d/CAREER_2022/Python_Small_Tasks/PERSONAL/MINE/prayer_time_manager/
    echo "✅ Synced at $(date '+%H:%M:%S')"
}

# Initial sync
echo "📦 Initial sync..."
sync_to_windows

# Watch for file changes and sync before hot reload
echo "🔄 Watching for changes..."
(
    while true; do
        # Use inotifywait to detect file changes in lib folder
        inotifywait -q -e modify,create,delete -r /home/anis/Projects/MINE/prayer_time_manager/lib 2>/dev/null
        # Small delay to batch multiple changes
        sleep 0.5
        echo "📝 Changes detected, syncing..."
        sync_to_windows
    done
) &
WATCH_PID=$!

# Cleanup on exit
trap "kill $WATCH_PID 2>/dev/null; echo 'Stopped'; exit" EXIT INT TERM

# Run Flutter
echo "📱 Starting app on phone..."
echo ""
echo "HOT RELOAD: Press 'r' (files auto-sync on change)"
echo "QUIT: Press 'q' or Ctrl+C"
echo ""

cd /mnt/d/CAREER_2022/Python_Small_Tasks/PERSONAL/MINE/prayer_time_manager
powershell.exe -NoProfile -Command "flutter run"