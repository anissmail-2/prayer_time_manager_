import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_service.dart';

class AuthService {
  static FirebaseAuth? get _auth => FirebaseService.isSupported ? FirebaseService.authNullable : null;
  static FirebaseFirestore? get _firestore => FirebaseService.isSupported ? FirebaseService.firestoreNullable : null;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Current user stream
  static Stream<User?> get authStateChanges => 
    _auth?.authStateChanges() ?? Stream.value(null);

  // Get current user
  static User? get currentUser => _auth?.currentUser;

  // Check if user is logged in
  static bool get isLoggedIn => currentUser != null;

  // Get user ID
  static String? get userId => currentUser?.uid;

  // Sign up with email and password
  static Future<User?> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (_auth == null) return null;
    
    try {
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await credential.user?.updateDisplayName(displayName);

      // Create user document in Firestore
      if (credential.user != null) {
        await _createUserDocument(credential.user!);
      }

      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with email and password
  static Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (_auth == null) return null;
    
    try {
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google
  static Future<User?> signInWithGoogle() async {
    if (_auth == null) return null;
    
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // Obtain the auth details from the request
      final GoogleSignInAuthentication? googleAuth = 
          await googleUser?.authentication;

      if (googleAuth == null) return null;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final userCredential = await _auth!.signInWithCredential(credential);

      // Create user document if new user
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _createUserDocument(userCredential.user!);
      }

      return userCredential.user;
    } catch (e) {
      throw 'Failed to sign in with Google: $e';
    }
  }

  // Sign out
  static Future<void> signOut() async {
    await Future.wait([
      if (_auth != null) _auth!.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    if (_auth == null) return;
    
    try {
      await _auth!.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Update user profile
  static Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    final user = currentUser;
    if (user == null) throw 'No user logged in';

    if (displayName != null) {
      await user.updateDisplayName(displayName);
    }
    if (photoURL != null) {
      await user.updatePhotoURL(photoURL);
    }

    // Update Firestore document
    if (_firestore != null) {
      await _firestore!.collection('users').doc(user.uid).update({
        if (displayName != null) 'displayName': displayName,
        if (photoURL != null) 'photoURL': photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Delete account
  static Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw 'No user logged in';

    try {
      // Delete user data from Firestore
      await _deleteUserData(user.uid);
      
      // Delete auth account
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw 'Please sign in again to delete your account';
      }
      throw _handleAuthException(e);
    }
  }

  // Create user document in Firestore
  static Future<void> _createUserDocument(User user) async {
    if (_firestore == null) return;
    
    final userDoc = _firestore!.collection('users').doc(user.uid);
    
    // Check if document already exists
    final docSnapshot = await userDoc.get();
    if (!docSnapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? 'User',
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'settings': {
          'theme': 'system',
          'notifications': true,
          'prayerReminders': true,
        },
        'subscription': {
          'tier': 'free',
          'expiresAt': null,
        },
      });
    }
  }

  // Delete all user data
  static Future<void> _deleteUserData(String uid) async {
    if (_firestore == null) return;
    
    final batch = _firestore!.batch();
    
    // Delete user document
    batch.delete(_firestore!.collection('users').doc(uid));
    
    // Delete user's tasks
    final tasks = await _firestore!
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .get();
    for (final doc in tasks.docs) {
      batch.delete(doc.reference);
    }
    
    // Delete user's spaces
    final spaces = await _firestore!
        .collection('users')
        .doc(uid)
        .collection('spaces')
        .get();
    for (final doc in spaces.docs) {
      batch.delete(doc.reference);
    }
    
    // Delete user's activities
    final activities = await _firestore!
        .collection('users')
        .doc(uid)
        .collection('activities')
        .get();
    for (final doc in activities.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  }

  // Handle Firebase Auth exceptions
  static String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password is too weak';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'The email address is invalid';
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled';
      default:
        return e.message ?? 'An authentication error occurred';
    }
  }

  // Check if user needs to migrate local data
  static Future<bool> hasLocalData() async {
    // This will be implemented to check SharedPreferences for existing data
    return false; // Placeholder
  }

  // Get user subscription tier
  static Future<String> getSubscriptionTier() async {
    if (!isLoggedIn || _firestore == null) return 'free';
    
    try {
      final doc = await _firestore!
          .collection('users')
          .doc(userId!)
          .get();
      
      return doc.data()?['subscription']?['tier'] ?? 'free';
    } catch (e) {
      return 'free';
    }
  }

  // Check if user has premium features
  static Future<bool> isPremium() async {
    final tier = await getSubscriptionTier();
    return tier == 'premium' || tier == 'pro';
  }
}