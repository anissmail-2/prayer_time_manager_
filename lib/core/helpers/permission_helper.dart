import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Helper class for managing app permissions
/// Handles Android 13+ granular permissions automatically
class PermissionHelper {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Request all permissions needed for the app
  /// Returns a map of permission statuses
  static Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    Map<Permission, PermissionStatus> statuses = {};
    
    // Core permissions
    statuses[Permission.microphone] = await Permission.microphone.request();
    statuses[Permission.location] = await Permission.location.request();
    statuses[Permission.notification] = await Permission.notification.request();
    
    // Handle storage/media permissions based on Android version
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ uses granular media permissions
        statuses[Permission.photos] = await Permission.photos.request();
        statuses[Permission.videos] = await Permission.videos.request();
        statuses[Permission.audio] = await Permission.audio.request();
      } else {
        // Older Android versions use storage permission
        statuses[Permission.storage] = await Permission.storage.request();
      }
    }
    
    return statuses;
  }

  /// Check if gallery/photos permission is granted
  /// Handles Android version differences
  static Future<bool> hasGalleryPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        return await Permission.photos.isGranted;
      } else {
        return await Permission.storage.isGranted;
      }
    }
    return false;
  }

  /// Request gallery/photos permission
  /// Returns true if granted
  static Future<bool> requestGalleryPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final status = await Permission.photos.request();
        return status.isGranted;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }
    return false;
  }

  /// Check if location permission is granted
  static Future<bool> hasLocationPermission() async {
    return await Permission.location.isGranted;
  }

  /// Request location permission
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }


  /// Check if microphone permission is granted
  static Future<bool> hasMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }

  /// Request microphone permission
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Check if notification permission is granted
  static Future<bool> hasNotificationPermission() async {
    return await Permission.notification.isGranted;
  }

  /// Request notification permission
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Open app settings if user needs to manually grant permissions
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Get a human-readable string for permission status
  static String getStatusString(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Granted';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      case PermissionStatus.permanentlyDenied:
        return 'Permanently Denied';
      case PermissionStatus.provisional:
        return 'Provisional';
    }
  }
}