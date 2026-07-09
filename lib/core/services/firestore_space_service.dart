import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/space.dart';
import 'auth_service.dart';
import 'space_service.dart';

/// Firestore-backed implementation of SpaceService
class FirestoreSpaceService {
  static const String _spacesKey = 'spaces';
  static const String _migrationKeyPrefix = 'spaces_migrated_to_firestore';

  // Cloud soft-delete marker fields (see FirestoreTodoService for the
  // full rationale: hard deletes get resurrected by other devices' syncs).
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

  /// Get the Firestore spaces collection for the current user
  static CollectionReference<Map<String, dynamic>>? get _spacesCollection {
    final userId = AuthService.userId;
    if (userId == null) return null;
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('spaces');
  }
  
  /// Check if we should use Firestore
  static bool get _useFirestore => AuthService.isLoggedIn && _spacesCollection != null;
  
  /// Get all spaces
  static Future<List<Space>> getAllSpaces() async {
    if (!_useFirestore) {
      throw Exception('User not authenticated');
    }
    
    try {
      // Hide soft-deleted docs
      final snapshot = await _spacesCollection!.get();
      final spaces = snapshot.docs
          .where((doc) => doc.data()[_deletedField] != true)
          .map((doc) => Space.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      // Sort by creation date
      spaces.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return spaces;
    } catch (e) {
      print('Error getting spaces from Firestore: $e');
      rethrow;
    }
  }
  
  /// Create a new space
  static Future<Space> createSpace(Space space) async {
    if (!_useFirestore) {
      throw Exception('User not authenticated');
    }
    
    try {
      // Add to Firestore only
      await _spacesCollection!.doc(space.id).set(space.toJson());
      return space;
    } catch (e) {
      print('Error creating space in Firestore: $e');
      rethrow;
    }
  }
  
  /// Update a space
  static Future<void> updateSpace(Space space) async {
    if (!_useFirestore) {
      throw Exception('User not authenticated');
    }
    
    try {
      await _spacesCollection!.doc(space.id).set(space.toJson());
    } catch (e) {
      print('Error updating space in Firestore: $e');
      rethrow;
    }
  }
  
  /// Delete a space (cloud SOFT delete — see FirestoreTodoService.deleteTask)
  static Future<void> deleteSpace(String id) async {
    if (!_useFirestore) {
      throw Exception('User not authenticated');
    }

    try {
      await _softDeleteCloudSpace(id, DateTime.now());
    } catch (e) {
      print('Error deleting space from Firestore: $e');
      rethrow;
    }
  }

  /// Write the soft-delete marker onto a space doc, preserving other fields.
  static Future<void> _softDeleteCloudSpace(String id, DateTime deletedAt) async {
    await _spacesCollection!.doc(id).set({
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
  
  /// Get space by ID
  static Future<Space?> getSpaceById(String id) async {
    final spaces = await getAllSpaces();
    try {
      return spaces.firstWhere((space) => space.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Read spaces straight from SharedPreferences.
  /// Migration/sync MUST use this instead of SpaceService.getAllSpaces(),
  /// which returns Firestore data when the user is logged in.
  static Future<List<Space>> _getLocalSpaces() async {
    final prefs = await SharedPreferences.getInstance();
    final spacesJson = prefs.getString(_spacesKey);
    if (spacesJson == null) return [];

    try {
      final List<dynamic> spacesList = jsonDecode(spacesJson);
      return spacesList.map((json) => Space.fromJson(json)).toList();
    } catch (e) {
      print('Error decoding local spaces: $e');
      return [];
    }
  }

  /// Write spaces straight to SharedPreferences (local mirror).
  static Future<void> _saveLocalSpaces(List<Space> spaces) async {
    final prefs = await SharedPreferences.getInstance();
    final spacesJson = jsonEncode(spaces.map((s) => s.toJson()).toList());
    await prefs.setString(_spacesKey, spacesJson);
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
      // Get local spaces (raw SharedPreferences, never Firestore)
      final localSpaces = await _getLocalSpaces();

      if (localSpaces.isEmpty) {
        await prefs.setBool(migrationKey, true);
        return;
      }

      final firestoreSpaces = await _spacesCollection!.get();
      final existingIds = firestoreSpaces.docs.map((doc) => doc.id).toSet();

      // Commit in chunks to stay under Firestore's 500-writes-per-batch limit
      const chunkSize = 400;
      var batch = FirebaseFirestore.instance.batch();
      var inBatch = 0;
      var migratedCount = 0;

      for (final space in localSpaces) {
        if (existingIds.contains(space.id)) continue;
        batch.set(_spacesCollection!.doc(space.id), space.toJson());
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
        print('Migrated $migratedCount spaces to Firestore');
      }

      await prefs.setBool(migrationKey, true);
    } catch (e) {
      // Leave the flag unset so the next sign-in/sync retries, but
      // surface the failure to the caller instead of swallowing it.
      print('Error migrating spaces to Firestore: $e');
      rethrow;
    }
  }
  
  /// Listen to real-time space updates
  static Stream<List<Space>> watchSpaces() {
    if (!_useFirestore) {
      return Stream.fromFuture(SpaceService.getAllSpaces());
    }
    
    return _spacesCollection!
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => doc.data()[_deletedField] != true)
            .map((doc) => Space.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }
  
  /// Sync local changes to Firestore.
  ///
  /// Mirrors FirestoreTodoService.syncLocalChangesToFirestore — local
  /// tombstones + cloud soft-deletes, delete-vs-edit resolved by
  /// timestamp, and a periodic hard-purge of soft-deletes older than
  /// 30 days. See that method for the full decision table.
  ///
  /// NOTE: not unit-testable here (no Firestore emulator/fakes) — keep
  /// the branches self-contained and documented.
  static Future<void> syncLocalChangesToFirestore() async {
    if (!_useFirestore) return;

    try {
      // Get local spaces (raw SharedPreferences, never Firestore)
      final localSpaces = await _getLocalSpaces();

      // Local deletion tombstones (pruned to the last 30 days)
      final tombstones = await SpaceService.getDeletedSpaceTombstones();

      // Partition Firestore docs into live and soft-deleted,
      // hard-purging soft-deletes past the retention window.
      final firestoreSnapshot = await _spacesCollection!.get();
      final cloudLive = <String, Space>{};
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
          cloudLive[doc.id] = Space.fromJson({...data, 'id': doc.id});
        }
      }

      var localChanged = false;
      final mergedLocal = <String, Space>{
        for (final s in localSpaces) s.id: s,
      };

      // 1) Local tombstones: the delete wins unless the cloud copy was
      //    edited AFTER the deletion.
      for (final entry in tombstones.entries) {
        final id = entry.key;
        final deletedAt = entry.value;
        final cloudSpace = cloudLive[id];

        if (cloudSpace != null) {
          final cloudUpdatedAt = cloudSpace.updatedAt ?? cloudSpace.createdAt;
          if (cloudUpdatedAt.isAfter(deletedAt)) {
            // Cloud edit is newer than the local delete — the edit wins.
            await SpaceService.removeSpaceDeletionTombstone(id);
            mergedLocal[id] = cloudSpace;
            localChanged = true;
            continue;
          }
          // Local delete is newer — propagate it as a cloud soft-delete.
          await _softDeleteCloudSpace(id, deletedAt);
          cloudLive.remove(id);
        }

        // Deleted (here and/or in the cloud) — drop any stale local copy.
        if (mergedLocal.remove(id) != null) {
          localChanged = true;
        }
      }

      // 2) Local spaces without tombstones: last-write-wins vs the cloud.
      for (final localSpace in localSpaces) {
        if (tombstones.containsKey(localSpace.id)) continue; // handled above

        final localUpdatedAt = localSpace.updatedAt ?? localSpace.createdAt;

        final cloudDeleted = cloudDeletedAt[localSpace.id];
        if (cloudDeleted != null) {
          if (cloudDeleted.isAfter(localUpdatedAt)) {
            // Deleted elsewhere after our last edit — drop the local copy.
            mergedLocal.remove(localSpace.id);
            localChanged = true;
          } else {
            // Our edit is newer than the remote delete — resurrect the
            // doc (plain set replaces it, clearing the deletion marker).
            await _spacesCollection!.doc(localSpace.id).set(localSpace.toJson());
          }
          continue;
        }

        final cloudSpace = cloudLive[localSpace.id];
        if (cloudSpace == null) {
          await _spacesCollection!.doc(localSpace.id).set(localSpace.toJson());
          continue;
        }

        final cloudUpdatedAt = cloudSpace.updatedAt ?? cloudSpace.createdAt;
        if (localUpdatedAt.isAfter(cloudUpdatedAt)) {
          await _spacesCollection!.doc(localSpace.id).set(localSpace.toJson());
        } else if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
          // Cloud copy is newer — refresh the local mirror.
          mergedLocal[localSpace.id] = cloudSpace;
          localChanged = true;
        }
      }

      // 3) Live cloud spaces unknown locally — hydrate the local mirror
      //    directly (SpaceService.createSpace would route back to Firestore).
      for (final cloudSpace in cloudLive.values) {
        if (mergedLocal.containsKey(cloudSpace.id)) continue;
        if (tombstones.containsKey(cloudSpace.id)) continue; // handled in (1)
        mergedLocal[cloudSpace.id] = cloudSpace;
        localChanged = true;
      }

      if (localChanged) {
        await _saveLocalSpaces(mergedLocal.values.toList());
      }
    } catch (e) {
      print('Error syncing spaces: $e');
    }
  }
}