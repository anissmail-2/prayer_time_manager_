import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/task.dart';
import 'auth_service.dart';
import 'todo_service.dart';
import 'gemini_task_assistant.dart';

/// Firestore-backed implementation of TodoService
/// Falls back to local storage when offline or not authenticated
class FirestoreTodoService {
  static const String _tasksKey = 'tasks';
  static const String _migrationKeyPrefix = 'data_migrated_to_firestore';

  // Cloud soft-delete marker fields. Deleting a task writes these onto the
  // doc instead of removing it, so OTHER devices can observe the deletion
  // (a hard delete is indistinguishable from "never synced" and gets
  // resurrected by their next sync).
  static const String _deletedField = 'deleted';
  static const String _deletedAtField = 'deletedAt';
  static const Duration _softDeleteRetention = Duration(days: 30);

  /// Migration flag is per-uid so a stale flag from a previous account
  /// can never skip a new user's migration.
  static String? get _migrationKey {
    final userId = AuthService.userId;
    if (userId == null) return null;
    return '${_migrationKeyPrefix}_$userId';
  }

  /// Get the Firestore tasks collection for the current user
  static CollectionReference<Map<String, dynamic>>? get _tasksCollection {
    final userId = AuthService.userId;
    if (userId == null) return null;
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('tasks');
  }
  
  /// Check if we should use Firestore
  static bool get _useFirestore => AuthService.isLoggedIn && _tasksCollection != null;
  
  /// Get all tasks from Firestore
  static Future<List<Task>> getAllTasks() async {
    if (!_useFirestore) {
      throw Exception('User not authenticated');
    }
    
    try {
      // Get from Firestore, hiding soft-deleted docs
      final snapshot = await _tasksCollection!.get();
      final tasks = snapshot.docs
          .where((doc) => doc.data()[_deletedField] != true)
          .map((doc) => Task.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      // Sort by creation date (newest first)
      tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return tasks;
    } catch (e) {
      print('Error getting tasks from Firestore: $e');
      rethrow;
    }
  }
  
  /// Add a new task
  static Future<void> addTask(Task task) async {
    if (!_useFirestore) {
      throw Exception('User not authenticated');
    }

    try {
      // Add to Firestore only
      await _tasksCollection!.doc(task.id).set(task.toJson());
    } catch (e) {
      print('Error adding task to Firestore: $e');
      rethrow;
    }
  }
  
  /// Update a task
  static Future<void> updateTask(Task updatedTask) async {
    if (!_useFirestore) {
      throw Exception('User not authenticated');
    }
    
    try {
      // Update in Firestore only
      await _tasksCollection!.doc(updatedTask.id).set(updatedTask.toJson());
    } catch (e) {
      print('Error updating task in Firestore: $e');
      rethrow;
    }
  }
  
  /// Delete a task (cloud SOFT delete).
  /// Writes a deletion marker onto the doc (keeping its other fields)
  /// instead of removing it, so other devices' syncs see the deletion
  /// and can compare timestamps (delete-vs-edit). Soft-deleted docs are
  /// hard-purged after [_softDeleteRetention] during sync.
  static Future<void> deleteTask(String taskId) async {
    if (!_useFirestore) {
      throw Exception('User not authenticated');
    }

    try {
      await _softDeleteCloudTask(taskId, DateTime.now());
    } catch (e) {
      print('Error deleting task from Firestore: $e');
      rethrow;
    }
  }

  /// Write the soft-delete marker onto a task doc, preserving other fields.
  /// set+merge (rather than update) so it also works if the doc is missing.
  static Future<void> _softDeleteCloudTask(String taskId, DateTime deletedAt) async {
    await _tasksCollection!.doc(taskId).set({
      _deletedField: true,
      _deletedAtField: deletedAt.toIso8601String(),
    }, SetOptions(merge: true));
  }

  /// Parse a deletedAt value that may be an ISO string or a Timestamp.
  static DateTime? _parseDeletedAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  /// Get tasks for a specific date
  static Future<List<Task>> getTasksForDate(DateTime date) async {
    final allTasks = await getAllTasks();
    return allTasks.where((task) => task.shouldShowOnDate(date)).toList();
  }
  
  /// Create a task from AI suggestion
  static Future<Task> createTaskFromSuggestion(TaskSuggestion suggestion) async {
    // Parse absolute time if provided
    DateTime? absoluteTime;
    if (suggestion.absoluteTime != null) {
      final parts = suggestion.absoluteTime!.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          final now = DateTime.now();
          absoluteTime = DateTime(now.year, now.month, now.day, hour, minute);
        }
      }
    }
    
    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: suggestion.title,
      description: suggestion.description ?? '',
      scheduleType: suggestion.scheduleType == 'prayerRelative' 
          ? ScheduleType.prayerRelative 
          : ScheduleType.absolute,
      absoluteTime: absoluteTime,
      relatedPrayer: suggestion.relatedPrayer != null 
          ? PrayerName.values.firstWhere(
              (p) => p.toString().split('.').last == suggestion.relatedPrayer,
              orElse: () => PrayerName.fajr,
            )
          : null,
      isBeforePrayer: suggestion.isBeforePrayer,
      minutesOffset: suggestion.minutesOffset,
      priority: suggestion.priority,
      recurrence: _parseRecurrenceType(suggestion.recurrenceType),
      weeklyDays: suggestion.weeklyDays,
      createdAt: DateTime.now(),
    );
    
    await addTask(task);
    return task;
  }
  
  /// Read tasks straight from SharedPreferences.
  /// Migration/sync MUST use this instead of TodoService.getAllTasks(),
  /// which returns Firestore data when the user is logged in.
  static Future<List<Task>> _getLocalTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getString(_tasksKey);
    if (tasksJson == null) return [];

    try {
      final List<dynamic> tasksList = json.decode(tasksJson);
      return tasksList.map((taskJson) => Task.fromJson(taskJson)).toList();
    } catch (e) {
      print('Error decoding local tasks: $e');
      return [];
    }
  }

  /// Write tasks straight to SharedPreferences (local mirror).
  static Future<void> _saveLocalTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = json.encode(tasks.map((task) => task.toJson()).toList());
    await prefs.setString(_tasksKey, tasksJson);
  }

  /// Migrate local data to Firestore
  static Future<void> migrateLocalDataToFirestore() async {
    if (!_useFirestore) return;

    final migrationKey = _migrationKey;
    if (migrationKey == null) return;

    final prefs = await SharedPreferences.getInstance();
    final migrated = prefs.getBool(migrationKey) ?? false;

    if (migrated) return;

    try {
      // Get local tasks (raw SharedPreferences, never Firestore)
      final localTasks = await _getLocalTasks();

      if (localTasks.isEmpty) {
        // No data to migrate
        await prefs.setBool(migrationKey, true);
        return;
      }

      // Get existing Firestore tasks to avoid duplicates
      final firestoreTasks = await _tasksCollection!.get();
      final existingIds = firestoreTasks.docs.map((doc) => doc.id).toSet();

      // Migrate tasks that don't exist in Firestore, committing in
      // chunks to stay under Firestore's 500-writes-per-batch limit.
      const chunkSize = 400;
      var batch = FirebaseFirestore.instance.batch();
      var inBatch = 0;
      var migratedCount = 0;

      for (final task in localTasks) {
        if (existingIds.contains(task.id)) continue;
        batch.set(_tasksCollection!.doc(task.id), task.toJson());
        migratedCount++;
        inBatch++;
        if (inBatch >= chunkSize) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          inBatch = 0;
        }
      }

      if (inBatch > 0) {
        await batch.commit();
      }
      if (migratedCount > 0) {
        print('Migrated $migratedCount tasks to Firestore');
      }

      // Mark as migrated
      await prefs.setBool(migrationKey, true);
    } catch (e) {
      // Leave the flag unset so the next sign-in/sync retries, but
      // surface the failure to the caller instead of swallowing it.
      print('Error migrating tasks to Firestore: $e');
      rethrow;
    }
  }

  /// Clear the current user's migration flag (useful for testing)
  static Future<void> resetMigration() async {
    final migrationKey = _migrationKey;
    if (migrationKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(migrationKey);
  }
  
  /// Listen to real-time task updates
  static Stream<List<Task>> watchTasks() {
    if (!_useFirestore) {
      // Return a stream that emits local tasks once
      return Stream.fromFuture(TodoService.getAllTasks());
    }
    
    return _tasksCollection!
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => doc.data()[_deletedField] != true)
            .map((doc) => Task.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }
  
  /// Sync local changes to Firestore (for offline-to-online sync).
  ///
  /// Deletions use a two-part mechanism:
  ///  - LOCAL tombstones (TodoService.getDeletedTaskTombstones) record
  ///    deletions made on this device;
  ///  - CLOUD soft-deletes ({'deleted': true, 'deletedAt': ...} on the doc)
  ///    make deletions visible to other devices.
  ///
  /// Conflicts are resolved by timestamp (delete-vs-edit):
  ///  - cloud soft-delete newer than the local copy's updatedAt
  ///      -> remove from the local mirror;
  ///  - local tombstone newer than the cloud copy's updatedAt
  ///      -> soft-delete the cloud doc;
  ///  - local tombstone OLDER than a cloud edit
  ///      -> drop the tombstone, the edit wins and the task stays;
  ///  - local edit newer than a cloud soft-delete
  ///      -> resurrect the cloud doc with the local copy.
  ///
  /// Soft-deleted cloud docs older than 30 days are hard-purged here.
  ///
  /// NOTE: this merge logic cannot be unit-tested in this repo (no
  /// Firestore emulator/fakes wired up) — keep it self-contained and
  /// behavior-per-branch documented as above.
  static Future<void> syncLocalChangesToFirestore() async {
    if (!_useFirestore) return;

    try {
      // Get local tasks (raw SharedPreferences, never Firestore)
      final localTasks = await _getLocalTasks();

      // Local deletion tombstones (pruned to the last 30 days)
      final tombstones = await TodoService.getDeletedTaskTombstones();

      // Partition Firestore docs into live and soft-deleted,
      // hard-purging soft-deletes past the retention window.
      final firestoreSnapshot = await _tasksCollection!.get();
      final cloudLive = <String, Task>{};
      final cloudDeletedAt = <String, DateTime>{};
      final now = DateTime.now();

      for (final doc in firestoreSnapshot.docs) {
        final data = doc.data();
        if (data[_deletedField] == true) {
          final deletedAt = _parseDeletedAt(data[_deletedAtField]) ?? now;
          if (now.difference(deletedAt) > _softDeleteRetention) {
            await doc.reference.delete(); // periodic hard purge
          } else {
            cloudDeletedAt[doc.id] = deletedAt;
          }
        } else {
          cloudLive[doc.id] = Task.fromJson({...data, 'id': doc.id});
        }
      }

      var localChanged = false;
      final mergedLocal = <String, Task>{
        for (final t in localTasks) t.id: t,
      };

      // 1) Local tombstones: the delete wins unless the cloud copy was
      //    edited AFTER the deletion.
      for (final entry in tombstones.entries) {
        final id = entry.key;
        final deletedAt = entry.value;
        final cloudTask = cloudLive[id];

        if (cloudTask != null) {
          final cloudUpdatedAt = cloudTask.updatedAt ?? cloudTask.createdAt;
          if (cloudUpdatedAt.isAfter(deletedAt)) {
            // Cloud edit is newer than the local delete — the edit wins:
            // drop the tombstone and take the cloud copy locally.
            await TodoService.removeTaskDeletionTombstone(id);
            mergedLocal[id] = cloudTask;
            localChanged = true;
            continue;
          }
          // Local delete is newer — propagate it as a cloud soft-delete.
          await _softDeleteCloudTask(id, deletedAt);
          cloudLive.remove(id);
        }

        // Deleted (here and/or in the cloud) — drop any stale local copy.
        if (mergedLocal.remove(id) != null) {
          localChanged = true;
        }
      }

      // 2) Local tasks without tombstones: last-write-wins vs the cloud.
      for (final localTask in localTasks) {
        if (tombstones.containsKey(localTask.id)) continue; // handled above

        final localUpdatedAt = localTask.updatedAt ?? localTask.createdAt;

        final cloudDeleted = cloudDeletedAt[localTask.id];
        if (cloudDeleted != null) {
          if (cloudDeleted.isAfter(localUpdatedAt)) {
            // Deleted elsewhere after our last edit — drop the local copy.
            mergedLocal.remove(localTask.id);
            localChanged = true;
          } else {
            // Our edit is newer than the remote delete — resurrect the
            // doc (plain set replaces it, clearing the deletion marker).
            await _tasksCollection!.doc(localTask.id).set(localTask.toJson());
          }
          continue;
        }

        final cloudTask = cloudLive[localTask.id];
        if (cloudTask == null) {
          // Not in the cloud yet — upload.
          await _tasksCollection!.doc(localTask.id).set(localTask.toJson());
          continue;
        }

        final cloudUpdatedAt = cloudTask.updatedAt ?? cloudTask.createdAt;
        if (localUpdatedAt.isAfter(cloudUpdatedAt)) {
          await _tasksCollection!.doc(localTask.id).set(localTask.toJson());
        } else if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
          // Cloud copy is newer — refresh the local mirror.
          mergedLocal[localTask.id] = cloudTask;
          localChanged = true;
        }
      }

      // 3) Live cloud tasks unknown locally — hydrate the local mirror
      //    directly (TodoService.addTask would route back to Firestore).
      for (final cloudTask in cloudLive.values) {
        if (mergedLocal.containsKey(cloudTask.id)) continue;
        if (tombstones.containsKey(cloudTask.id)) continue; // handled in (1)
        mergedLocal[cloudTask.id] = cloudTask;
        localChanged = true;
      }

      if (localChanged) {
        await _saveLocalTasks(mergedLocal.values.toList());
      }
    } catch (e) {
      print('Error syncing tasks: $e');
    }
  }
  
  static TaskRecurrence _parseRecurrenceType(String? type) {
    switch (type?.toLowerCase()) {
      case 'daily':
        return TaskRecurrence.daily;
      case 'weekly':
        return TaskRecurrence.weekly;
      case 'monthly':
        return TaskRecurrence.monthly;
      case 'yearly':
        return TaskRecurrence.yearly;
      default:
        return TaskRecurrence.once;
    }
  }
}