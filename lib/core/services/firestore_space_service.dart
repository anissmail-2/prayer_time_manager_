import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/space.dart';
import 'auth_service.dart';
import 'space_service.dart';

/// Firestore-backed implementation of SpaceService
class FirestoreSpaceService {
  static const String _spacesKey = 'spaces';
  static const String _migrationKey = 'spaces_migrated_to_firestore';
  
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
      final snapshot = await _spacesCollection!.get();
      final spaces = snapshot.docs
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
  
  /// Delete a space
  static Future<void> deleteSpace(String id) async {
    if (!_useFirestore) {
      throw Exception('User not authenticated');
    }
    
    try {
      await _spacesCollection!.doc(id).delete();
    } catch (e) {
      print('Error deleting space from Firestore: $e');
      rethrow;
    }
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
  
  /// Migrate local data to Firestore
  static Future<void> migrateLocalDataToFirestore() async {
    if (!_useFirestore) return;
    
    final prefs = await SharedPreferences.getInstance();
    final migrated = prefs.getBool(_migrationKey) ?? false;
    
    if (migrated) return;
    
    try {
      final localSpaces = await SpaceService.getAllSpaces();
      
      if (localSpaces.isEmpty) {
        await prefs.setBool(_migrationKey, true);
        return;
      }
      
      final firestoreSpaces = await _spacesCollection!.get();
      final existingIds = firestoreSpaces.docs.map((doc) => doc.id).toSet();
      
      final batch = FirebaseFirestore.instance.batch();
      int migratedCount = 0;
      
      for (final space in localSpaces) {
        if (!existingIds.contains(space.id)) {
          batch.set(_spacesCollection!.doc(space.id), space.toJson());
          migratedCount++;
        }
      }
      
      if (migratedCount > 0) {
        await batch.commit();
        print('Migrated $migratedCount spaces to Firestore');
      }
      
      await prefs.setBool(_migrationKey, true);
    } catch (e) {
      print('Error migrating spaces to Firestore: $e');
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
            .map((doc) => Space.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }
  
  /// Sync local changes to Firestore
  static Future<void> syncLocalChangesToFirestore() async {
    if (!_useFirestore) return;
    
    try {
      final localSpaces = await SpaceService.getAllSpaces();
      final firestoreSnapshot = await _spacesCollection!.get();
      final firestoreSpaces = Map.fromEntries(
        firestoreSnapshot.docs.map((doc) => 
          MapEntry(doc.id, Space.fromJson({...doc.data(), 'id': doc.id}))
        )
      );
      
      for (final localSpace in localSpaces) {
        final firestoreSpace = firestoreSpaces[localSpace.id];
        
        if (firestoreSpace == null || 
            (localSpace.updatedAt ?? localSpace.createdAt).isAfter(
              firestoreSpace.updatedAt ?? firestoreSpace.createdAt)) {
          await _spacesCollection!.doc(localSpace.id).set(localSpace.toJson());
        }
      }
      
      for (final firestoreSpace in firestoreSpaces.values) {
        final localExists = localSpaces.any((s) => s.id == firestoreSpace.id);
        if (!localExists) {
          await SpaceService.createSpace(firestoreSpace);
        }
      }
    } catch (e) {
      print('Error syncing spaces: $e');
    }
  }
}