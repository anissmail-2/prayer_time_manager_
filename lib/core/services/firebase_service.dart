import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import '../../firebase_options.dart';

/// Service for managing Firebase initialization and instances
class FirebaseService {
  static FirebaseAuth? _auth;
  static FirebaseFirestore? _firestore;
  static FirebaseAnalytics? _analytics;
  static FirebaseCrashlytics? _crashlytics;
  static bool _isInitialized = false;
  
  /// Check if Firebase is supported on this platform
  static bool get isSupported {
    try {
      return Platform.isAndroid || Platform.isIOS || kIsWeb;
    } catch (e) {
      return false;
    }
  }
  
  /// Initialize Firebase services
  static Future<void> initialize() async {
    // Skip Firebase initialization on unsupported platforms
    if (!isSupported) {
      if (kDebugMode) {
        print('ℹ️ Firebase is not supported on this platform');
      }
      return;
    }
    
    try {
      // Initialize Firebase with platform-specific options
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Initialize services
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _analytics = FirebaseAnalytics.instance;
      _crashlytics = FirebaseCrashlytics.instance;
      
      // Configure Crashlytics
      if (!kDebugMode) {
        // Enable crash collection in release mode
        await _crashlytics!.setCrashlyticsCollectionEnabled(true);
        
        // Pass all uncaught errors to Crashlytics
        FlutterError.onError = _crashlytics!.recordFlutterError;
      }
      
      // Set Firestore settings for offline support
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      _isInitialized = true;
      if (kDebugMode) {
        print('✅ Firebase initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Firebase: $e');
      }
      // Don't rethrow on unsupported platforms
      if (isSupported) {
        rethrow;
      }
    }
  }
  
  /// Get Firebase Auth instance
  static FirebaseAuth get auth {
    if (_auth == null) {
      throw Exception('Firebase not initialized. Call FirebaseService.initialize() first.');
    }
    return _auth!;
  }
  
  /// Get Firestore instance
  static FirebaseFirestore get firestore {
    if (_firestore == null) {
      throw Exception('Firebase not initialized. Call FirebaseService.initialize() first.');
    }
    return _firestore!;
  }
  
  /// Get Analytics instance
  static FirebaseAnalytics get analytics {
    if (_analytics == null) {
      throw Exception('Firebase not initialized. Call FirebaseService.initialize() first.');
    }
    return _analytics!;
  }
  
  /// Get Crashlytics instance
  static FirebaseCrashlytics get crashlytics {
    if (_crashlytics == null) {
      throw Exception('Firebase not initialized. Call FirebaseService.initialize() first.');
    }
    return _crashlytics!;
  }
  
  /// Get current user
  static User? get currentUser => _auth?.currentUser;
  
  /// Check if user is logged in
  static bool get isLoggedIn => currentUser != null;
  
  /// Get current user ID
  static String? get currentUserId => currentUser?.uid;
  
  /// Get Firebase Auth instance (nullable)
  static FirebaseAuth? get authNullable => _auth;
  
  /// Get Firestore instance (nullable)
  static FirebaseFirestore? get firestoreNullable => _firestore;
  
  /// Sign out
  static Future<void> signOut() async {
    await auth.signOut();
  }
}