import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'firestore_todo_service.dart';
import 'firestore_space_service.dart';
import '../helpers/connectivity_helper.dart';

/// Service to handle data synchronization between local storage and Firestore
class DataSyncService {
  static bool _isInitialized = false;
  static bool _isSyncing = false;
  
  /// Initialize data sync service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isInitialized = true;
    
    // Listen to auth state changes
    AuthService.authStateChanges.listen((user) async {
      if (user != null) {
        // User signed in - migrate and sync data
        await _onUserSignedIn();
      }
    });
    
    // Listen to connectivity changes.
    // connectivity_plus ^6 emits a List<ConnectivityResult>.
    Connectivity().onConnectivityChanged.listen((results) async {
      final isOnline = results.isNotEmpty &&
          !results.contains(ConnectivityResult.none);
      if (isOnline && AuthService.isLoggedIn) {
        // Back online - sync any local changes
        await syncAllData();
      }
    });
  }

  /// Called when user signs in: push any unmigrated local data to
  /// Firestore, then run a two-way sync (which also hydrates the local
  /// mirror with cloud data).
  static Future<void> _onUserSignedIn() async {
    try {
      await migrateAllDataToFirestore();
      await syncAllData();
      await _loadFirestoreDataToLocal();
    } catch (e) {
      print('Error handling sign-in sync: $e');
    }
  }
  
  /// Migrate all local data to Firestore
  static Future<void> migrateAllDataToFirestore() async {
    if (!AuthService.isLoggedIn) return;
    
    try {
      print('Starting data migration to Firestore...');
      
      // Migrate in parallel
      await Future.wait([
        FirestoreTodoService.migrateLocalDataToFirestore(),
        FirestoreSpaceService.migrateLocalDataToFirestore(),
        // Add more services as needed
      ]);
      
      print('Data migration completed');
    } catch (e) {
      print('Error during data migration: $e');
    }
  }
  
  /// Sync all data between local and Firestore
  static Future<void> syncAllData() async {
    if (!AuthService.isLoggedIn || _isSyncing) return;
    
    // Check connectivity
    if (!await ConnectivityHelper.hasInternetConnection()) {
      print('No internet connection, skipping sync');
      return;
    }
    
    _isSyncing = true;
    
    try {
      print('Starting data sync...');
      
      // Sync in parallel
      await Future.wait([
        FirestoreTodoService.syncLocalChangesToFirestore(),
        FirestoreSpaceService.syncLocalChangesToFirestore(),
        // Add more services as needed
      ]);
      
      print('Data sync completed');
    } catch (e) {
      print('Error during data sync: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Clear all local data. Called from AuthService.signOut so the next
  /// account signing in on this device cannot inherit (and upload to its
  /// own cloud) the previous user's local mirror. The signed-out user's
  /// data is safe in their cloud: sign-in auto-runs migrate + sync.
  ///
  /// Also clears deletion tombstones and migration flags — tombstones
  /// from user A must not soft-delete user B's cloud docs, and a stale
  /// migration flag must not skip a new user's migration.
  static Future<void> clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    const keysToRemove = [
      // Local content mirror
      'tasks',
      'spaces',
      'enhanced_tasks',
      'activities',
      // Deletion tombstones
      'deleted_task_ids',
      'deleted_space_ids',
    ];
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }

    // Migration/sync flags (covers both the legacy global keys and the
    // per-uid variants, e.g. 'data_migrated_to_firestore_<uid>').
    const flagPrefixes = [
      'data_migrated_to_firestore',
      'spaces_migrated_to_firestore',
    ];
    for (final key in prefs.getKeys().toList()) {
      if (flagPrefixes.any((prefix) => key.startsWith(prefix))) {
        await prefs.remove(key);
      }
    }
  }
  
  /// Force refresh all data from Firestore
  static Future<void> refreshFromCloud() async {
    if (!AuthService.isLoggedIn) return;
    
    try {
      // Get fresh data from Firestore
      await Future.wait([
        FirestoreTodoService.getAllTasks(),
        FirestoreSpaceService.getAllSpaces(),
      ]);
    } catch (e) {
      print('Error refreshing from cloud: $e');
    }
  }
  
  /// Manual sync for testing
  static Future<Map<String, dynamic>> manualSync() async {
    print('Manual sync started...');
    final results = <String, dynamic>{
      'success': false,
      'message': '',
      'errors': [],
    };
    
    try {
      if (!AuthService.isLoggedIn) {
        results['message'] = 'User not authenticated';
        return results;
      }
      
      results['userId'] = AuthService.userId;
      
      // Get local tasks
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = prefs.getString('tasks');
      int localTaskCount = 0;
      if (tasksJson != null) {
        final tasks = json.decode(tasksJson) as List;
        localTaskCount = tasks.length;
      }
      results['localTaskCount'] = localTaskCount;
      
      // Try to sync to Firestore
      print('Attempting to sync to Firestore...');
      await migrateAllDataToFirestore();
      
      // Try to get Firestore task count
      try {
        final firestoreTasks = await FirestoreTodoService.getAllTasks();
        results['firestoreTaskCount'] = firestoreTasks.length;
      } catch (e) {
        results['errors'].add('Firestore read error: $e');
      }
      
      results['success'] = true;
      results['message'] = 'Sync completed';
    } catch (e) {
      results['errors'].add('Sync error: $e');
      results['message'] = 'Sync failed: $e';
    }

    return results;
  }
  
  /// Load Firestore data into local storage
  static Future<void> _loadFirestoreDataToLocal() async {
    if (!AuthService.isLoggedIn) return;
    
    try {
      // Get data from Firestore
      final tasks = await FirestoreTodoService.getAllTasks();
      final spaces = await FirestoreSpaceService.getAllSpaces();
      
      // Save to local storage. Write the mirror even when the cloud list
      // is empty: a fresh account must overwrite any stale local mirror
      // instead of inheriting it.
      final prefs = await SharedPreferences.getInstance();

      final tasksJson = json.encode(tasks.map((task) => task.toJson()).toList());
      await prefs.setString('tasks', tasksJson);

      final spacesJson = json.encode(spaces.map((space) => space.toJson()).toList());
      await prefs.setString('spaces', spacesJson);
      
      print('Loaded ${tasks.length} tasks and ${spaces.length} spaces from Firestore');
    } catch (e) {
      print('Error loading Firestore data to local: $e');
    }
  }
}