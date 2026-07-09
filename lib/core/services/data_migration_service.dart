import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'auth_service.dart';
import '../../models/task.dart';
import '../../models/enhanced_task.dart';
import '../../models/space.dart';
import '../../models/activity.dart';
import '../../models/chat_message.dart';
import '../../models/prayer_duration.dart';

class DataMigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Firestore allows at most 500 writes per batch; stay comfortably under.
  static const int _batchChunkSize = 400;

  // Genuine user CONTENT keys. Settings keys ('prayer_durations',
  // 'location_settings') are deliberately excluded: they are never
  // cleared after migration, so counting them made the migration prompt
  // re-fire on every launch.
  static const List<String> _contentKeys = [
    'tasks',
    'spaces',
    'enhanced_tasks',
    'activities',
  ];

  // Check if the device holds genuinely unmigrated user content.
  // A key whose value decodes to an empty list/map does not count —
  // sync hydration re-creates 'tasks'/'spaces' (possibly empty) for
  // logged-in users, and that must not look like unmigrated data.
  static Future<bool> hasLocalData() async {
    final prefs = await SharedPreferences.getInstance();

    for (final key in _contentKeys) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List && decoded.isNotEmpty) return true;
        if (decoded is Map && decoded.isNotEmpty) return true;
      } catch (_) {
        // Undecodable content — ignore rather than re-prompt forever
      }
    }

    return false;
  }

  /// Commit doc writes in chunks so migrations of large datasets don't
  /// exceed Firestore's per-batch write limit.
  static Future<void> _setInChunks(
    List<MapEntry<DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>>
        writes,
  ) async {
    for (var i = 0; i < writes.length; i += _batchChunkSize) {
      final batch = _firestore.batch();
      for (final entry in writes.skip(i).take(_batchChunkSize)) {
        batch.set(entry.key, entry.value);
      }
      await batch.commit();
    }
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

      // Migrate enhanced tasks (unscheduled ideas)
      onProgress('Migrating ideas...');
      await _migrateEnhancedTasks(userId, prefs);

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

      // Deliberately do NOT clear any local keys after migration.
      // SpaceService ('enhanced_tasks'), ActivityService ('activities'),
      // AIConversationService ('ai_conversations'/'current_ai_conversation'),
      // PrayerDurationService and LocationService all serve their data from
      // SharedPreferences only — deleting those keys makes the data vanish
      // from the app the moment migration finishes. 'tasks'/'spaces' are
      // served from Firestore when logged in, but their local copies are
      // the offline mirror that DataSyncService keeps in sync. So the
      // consistent policy is: local storage stays the working copy for
      // everything; the Firestore copy written above is the cloud backup
      // (mirroring the decision already made for prayer_durations and
      // location_settings).
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

    final userTasksRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks');

    // Preserve the task's own ISO timestamps: overwriting them with
    // FieldValue.serverTimestamp() destroys real creation dates and
    // mixes Timestamp/String types, breaking orderBy('createdAt').
    await _setInChunks([
      for (final task in tasksList)
        MapEntry(userTasksRef.doc(task.id), task.toJson()),
    ]);
  }

  // Migrate enhanced tasks (unscheduled ideas).
  // Stored per space, matching firestore.rules:
  //   users/{uid}/spaces/{spaceId}/enhanced_tasks/{taskId}
  // Tasks without a space go under the reserved 'unassigned' space id.
  static Future<void> _migrateEnhancedTasks(String userId, SharedPreferences prefs) async {
    final tasksJson = prefs.getString('enhanced_tasks');
    if (tasksJson == null) return;

    final tasksList = (jsonDecode(tasksJson) as List)
        .map((json) => EnhancedTask.fromJson(json))
        .toList();

    if (tasksList.isEmpty) return;

    final userSpacesRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('spaces');

    await _setInChunks([
      for (final task in tasksList)
        MapEntry(
          userSpacesRef
              .doc(task.spaceId ?? 'unassigned')
              .collection('enhanced_tasks')
              .doc(task.id),
          task.toJson(),
        ),
    ]);
  }

  // Migrate spaces
  static Future<void> _migrateSpaces(String userId, SharedPreferences prefs) async {
    final spacesJson = prefs.getString('spaces');
    if (spacesJson == null) return;

    final spacesList = (jsonDecode(spacesJson) as List)
        .map((json) => Space.fromJson(json))
        .toList();

    if (spacesList.isEmpty) return;

    final userSpacesRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('spaces');

    // Preserve the space's own ISO timestamps (see _migrateTasks)
    await _setInChunks([
      for (final space in spacesList)
        MapEntry(userSpacesRef.doc(space.id), space.toJson()),
    ]);
  }

  // Migrate activities
  static Future<void> _migrateActivities(String userId, SharedPreferences prefs) async {
    final activitiesJson = prefs.getString('activities');
    if (activitiesJson == null) return;

    final activitiesList = (jsonDecode(activitiesJson) as List)
        .map((json) => Activity.fromJson(json))
        .toList();

    if (activitiesList.isEmpty) return;

    final userActivitiesRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('activities');

    // Preserve the activity's own ISO timestamps (see _migrateTasks)
    await _setInChunks([
      for (final activity in activitiesList)
        MapEntry(userActivitiesRef.doc(activity.id), activity.toJson()),
    ]);
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

    final userConversationsRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('ai_conversations');

    final writes = <MapEntry<DocumentReference<Map<String, dynamic>>,
        Map<String, dynamic>>>[];

    conversations.forEach((id, messagesJson) {
      final messages = (messagesJson as List)
          .map((json) => ChatMessage(
                text: json['text'] ?? json['content'] ?? '',
                isUser: json['isUser'] ?? (json['role'] == 'user'),
                timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
              ))
          .toList();

      writes.add(MapEntry(userConversationsRef.doc(id), {
        'messages': messages.map((m) => {
          'text': m.text,
          'isUser': m.isUser,
          'timestamp': m.timestamp.toIso8601String(),
        }).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }));
    });

    // Also migrate current conversation ID. Use set+merge, not update():
    // update() throws when users/{uid} doesn't exist (e.g. accounts
    // created before the user-doc was introduced), aborting migration.
    final currentConversationId = prefs.getString('current_ai_conversation');
    if (currentConversationId != null) {
      await _firestore
          .collection('users')
          .doc(userId)
          .set(
            {'currentAIConversationId': currentConversationId},
            SetOptions(merge: true),
          );
    }

    await _setInChunks(writes);
  }

  // Check if migration is needed and show dialog.
  // The prompt fires at most once per account: a per-uid flag records
  // that the dialog was answered (either way), because hasLocalData can
  // stay true forever (sync hydration re-creates 'tasks'/'spaces').
  static Future<bool> checkAndPromptMigration(BuildContext context) async {
    // Migration copies data into users/{uid}/... — pointless without a uid.
    final userId = AuthService.userId;
    if (userId == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final promptShownKey = 'migration_prompt_shown_$userId';
    if (prefs.getBool(promptShownKey) ?? false) return false;

    final hasData = await hasLocalData();
    if (!hasData) return false;

    if (!context.mounted) return false;

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

    // Record the answer (accepted OR skipped) so the prompt never re-fires
    await prefs.setBool(promptShownKey, true);

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