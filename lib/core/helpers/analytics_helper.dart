import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';

/// Helper for logging analytics events
class AnalyticsHelper {
  static FirebaseAnalytics? get _analytics => FirebaseService.isSupported
      ? FirebaseService.analytics
      : null;

  /// Log a custom event
  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (_analytics == null) return;

    try {
      await _analytics!.logEvent(
        name: name,
        parameters: parameters,
      );
      if (kDebugMode) {
        print('📊 Analytics: $name ${parameters != null ? parameters.toString() : ''}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Analytics error: $e');
      }
    }
  }

  // Task Events
  static Future<void> logTaskCreated({String? source}) async {
    await logEvent(
      name: 'task_created',
      parameters: {'source': source ?? 'unknown'},
    );
  }

  static Future<void> logTaskCompleted({bool? isPrayerRelative}) async {
    await logEvent(
      name: 'task_completed',
      parameters: {
        'is_prayer_relative': isPrayerRelative ?? false,
      },
    );
  }

  static Future<void> logTaskDeleted() async {
    await logEvent(name: 'task_deleted');
  }

  // Prayer Events
  static Future<void> logPrayerTimeViewed() async {
    await logEvent(name: 'prayer_time_viewed');
  }

  static Future<void> logPrayerRelativeTaskCreated({String? prayer}) async {
    await logEvent(
      name: 'prayer_relative_task_created',
      parameters: {'prayer': prayer ?? 'unknown'},
    );
  }

  // Space Events
  static Future<void> logSpaceCreated() async {
    await logEvent(name: 'space_created');
  }

  static Future<void> logSpaceViewed() async {
    await logEvent(name: 'space_viewed');
  }

  // AI Events
  static Future<void> logAIMessageSent() async {
    await logEvent(name: 'ai_message_sent');
  }

  static Future<void> logAITaskSuggestionAccepted() async {
    await logEvent(name: 'ai_task_suggestion_accepted');
  }

  // Navigation Events
  static Future<void> logScreenView(String screenName) async {
    if (_analytics == null) return;

    try {
      await _analytics!.logScreenView(screenName: screenName);
      if (kDebugMode) {
        print('📊 Screen View: $screenName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Screen view error: $e');
      }
    }
  }

  // Auth Events
  static Future<void> logLogin(String method) async {
    await logEvent(
      name: 'login',
      parameters: {'method': method},
    );
  }

  static Future<void> logSignUp(String method) async {
    await logEvent(
      name: 'sign_up',
      parameters: {'method': method},
    );
  }

  // Settings Events
  static Future<void> logSettingsOpened() async {
    await logEvent(name: 'settings_opened');
  }

  static Future<void> logLocationChanged(String city) async {
    await logEvent(
      name: 'location_changed',
      parameters: {'city': city},
    );
  }

  // Search Events
  static Future<void> logSearch(String query) async {
    await logEvent(
      name: 'search',
      parameters: {'search_term': query},
    );
  }
}
