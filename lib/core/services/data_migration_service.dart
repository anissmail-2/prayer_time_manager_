import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'auth_service.dart';
import '../../models/task.dart';
import '../../models/space.dart';
import '../../models/activity.dart';
import '../../models/chat_message.dart';
import '../../models/prayer_duration.dart';

class DataMigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if user has local data
  static Future<bool> hasLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check for any of these keys
    final hasData = prefs.containsKey('tasks') ||
        prefs.containsKey('spaces') ||
        prefs.containsKey('activities') ||
        prefs.containsKey('prayer_durations') ||
        prefs.containsKey('location_settings');
    
    return hasData;
  }

  // Migrate all local data to Firebase
  static Future<void> migrateToCloud({
    required void Function(String) onProgress,
    required void Function(String) onError,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) {
      onError('No user logged in');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Migrate tasks
      onProgress('Migrating tasks...');
      await _migrateTasks(userId, prefs);
      
      // Migrate spaces
      onProgress('Migrating spaces...');
      await _migrateSpaces(userId, prefs);
      
      // Migrate activities
      onProgress('Migrating activities...');
      await _migrateActivities(userId, prefs);
      
      // Migrate prayer durations
      onProgress('Migrating prayer settings...');
      await _migratePrayerDurations(userId, prefs);
      
      // Migrate location settings
      onProgress('Migrating location settings...');
      await _migrateLocationSettings(userId, prefs);
      
      // Migrate AI conversations
      onProgress('Migrating AI conversations...');
      await _migrateAIConversations(userId, prefs);
      
      // Clear local data after successful migration
      onProgress('Cleaning up local data...');
      await _clearLocalData(prefs);
      
      onProgress('Migration completed successfully!');
    } catch (e) {
      onError('Migration failed: $e');
    }
  }

  // Migrate tasks
  static Future<void> _migrateTasks(String userId, SharedPreferences prefs) async {
    final tasksJson = prefs.getString('tasks');
    if (tasksJson == null) return;

    final tasksList = (jsonDecode(tasksJson) as List)
        .map((json) => Task.fromJson(json))
        .toList();

    if (tasksList.isEmpty) return;

    final batch = _firestore.batch();
    final userTasksRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks');

    for (final task in tasksList) {
      final docRef = userTasksRef.doc(task.id);
      batch.set(docRef, {
        ...task.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // Migrate spaces
  static Future<void> _migrateSpaces(String userId, SharedPreferences prefs) async {
    final spacesJson = prefs.getString('spaces');
    if (spacesJson == null) return;

    final spacesList = (jsonDecode(spacesJson) as List)
        .map((json) => Space.fromJson(json))
        .toList();

    if (spacesList.isEmpty) return;

    final batch = _firestore.batch();
    final userSpacesRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('spaces');

    for (final space in spacesList) {
      final docRef = userSpacesRef.doc(space.id);
      batch.set(docRef, {
        ...space.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // Migrate activities
  static Future<void> _migrateActivities(String userId, SharedPreferences prefs) async {
    final activitiesJson = prefs.getString('activities');
    if (activitiesJson == null) return;

    final activitiesList = (jsonDecode(activitiesJson) as List)
        .map((json) => Activity.fromJson(json))
        .toList();

    if (activitiesList.isEmpty) return;

    final batch = _firestore.batch();
    final userActivitiesRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('activities');

    for (final activity in activitiesList) {
      final docRef = userActivitiesRef.doc(activity.id);
      batch.set(docRef, {
        ...activity.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // Migrate prayer durations
  static Future<void> _migratePrayerDurations(String userId, SharedPreferences prefs) async {
    final durationsJson = prefs.getString('prayer_durations');
    if (durationsJson == null) return;

    final durations = PrayerDuration.fromJson(jsonDecode(durationsJson));
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('prayer_durations')
        .set({
          ...durations.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  // Migrate location settings
  static Future<void> _migrateLocationSettings(String userId, SharedPreferences prefs) async {
    final locationJson = prefs.getString('location_settings');
    if (locationJson == null) return;

    final location = jsonDecode(locationJson);
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('location')
        .set({
          ...location,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  // Migrate AI conversations
  static Future<void> _migrateAIConversations(String userId, SharedPreferences prefs) async {
    final conversationsJson = prefs.getString('ai_conversations');
    if (conversationsJson == null) return;

    final conversations = jsonDecode(conversationsJson) as Map<String, dynamic>;
    
    final batch = _firestore.batch();
    final userConversationsRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('ai_conversations');

    conversations.forEach((id, messagesJson) {
      final messages = (messagesJson as List)
          .map((json) => ChatMessage(
                text: json['text'] ?? json['content'] ?? '',
                isUser: json['isUser'] ?? (json['role'] == 'user'),
                timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
              ))
          .toList();
      
      final docRef = userConversationsRef.doc(id);
      batch.set(docRef, {
        'messages': messages.map((m) => {
          'text': m.text,
          'isUser': m.isUser,
          'timestamp': m.timestamp.toIso8601String(),
        }).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // Also migrate current conversation ID
    final currentConversationId = prefs.getString('current_ai_conversation');
    if (currentConversationId != null) {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
            'currentAIConversationId': currentConversationId,
          });
    }

    await batch.commit();
  }

  // Clear local data after migration
  static Future<void> _clearLocalData(SharedPreferences prefs) async {
    final keysToRemove = [
      'tasks',
      'spaces',
      'enhanced_tasks',
      'activities',
      'prayer_durations',
      'location_settings',
      'ai_conversations',
      'current_ai_conversation',
    ];

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }

  // Check if migration is needed and show dialog
  static Future<bool> checkAndPromptMigration(BuildContext context) async {
    final hasData = await hasLocalData();
    if (!hasData) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Local Data Found'),
        content: const Text(
          'We found existing data on this device. Would you like to sync it with your account? This will allow you to access your data from any device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sync Data'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // Show migration progress dialog
  static Future<void> showMigrationDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _MigrationProgressDialog(),
    );
  }
}

// Separate widget for migration progress
class _MigrationProgressDialog extends StatefulWidget {
  @override
  State<_MigrationProgressDialog> createState() => _MigrationProgressDialogState();
}

class _MigrationProgressDialogState extends State<_MigrationProgressDialog> {
  String progressMessage = 'Preparing migration...';
  bool isComplete = false;
  bool hasError = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _startMigration();
  }

  Future<void> _startMigration() async {
    DataMigrationService.migrateToCloud(
      onProgress: (message) {
        if (mounted) {
          setState(() {
            progressMessage = message;
            if (message.contains('completed')) {
              isComplete = true;
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            hasError = true;
            errorMessage = error;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Syncing Data'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isComplete && !hasError) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
          ],
          if (hasError)
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
          if (isComplete && !hasError)
            Icon(
              Icons.check_circle,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          const SizedBox(height: 16),
          Text(
            hasError ? errorMessage ?? 'Migration failed' : progressMessage,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        if (isComplete || hasError)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
      ],
    );
  }
}