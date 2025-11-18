import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/auth_service.dart';
import '../core/theme/app_theme.dart';

class TestFirebaseScreen extends StatefulWidget {
  const TestFirebaseScreen({super.key});

  @override
  State<TestFirebaseScreen> createState() => _TestFirebaseScreenState();
}

class _TestFirebaseScreenState extends State<TestFirebaseScreen> {
  String _status = 'Checking...';
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _testFirebase();
  }

  void _log(String message) {
    setState(() {
      _logs.add(message);
    });
    print('TestFirebase: $message');
  }
  
  Future<void> _checkAuthPersistence() async {
    _log('\n=== Checking Auth Persistence ===');
    
    // Check shared preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      _log('SharedPreferences keys: ${keys.length}');
      for (final key in keys) {
        if (key.contains('firebase') || key.contains('auth')) {
          _log('  $key: ${prefs.get(key).toString().substring(0, 50)}...');
        }
      }
    } catch (e) {
      _log('Error checking SharedPreferences: $e');
    }
    
    // Check Firebase Auth persistence
    _log('\nFirebase Auth State:');
    _log('Persistence: ${FirebaseAuth.instance.authStateChanges()}');
    
    // Try to get a fresh token
    try {
      final token = await AuthService.currentUser?.getIdToken(true);
      _log('Fresh token obtained: ${token != null ? 'Yes' : 'No'}');
    } catch (e) {
      _log('Error getting fresh token: $e');
    }
  }

  Future<void> _testFirebase() async {
    try {
      // First check auth persistence
      await _checkAuthPersistence();
      
      // Test 1: Check authentication
      _log('\n=== Authentication Check ===');
      _log('Checking authentication...');
      final user = AuthService.currentUser;
      if (user == null) {
        _log('❌ Not authenticated');
        setState(() => _status = 'Not authenticated');
        return;
      }
      _log('✅ Authenticated as: ${user.email}');
      _log('User ID: ${user.uid}');

      // Test 2: Try to read tasks
      _log('\nReading tasks from Firestore...');
      final tasksRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks');
      
      final snapshot = await tasksRef.get();
      _log('✅ Found ${snapshot.docs.length} tasks');
      
      for (var doc in snapshot.docs) {
        _log('Task: ${doc.id} - ${doc.data()['title'] ?? 'No title'}');
      }

      // Test 3: Try to write a test task
      _log('\nTesting write permission...');
      final testTaskId = 'test_${DateTime.now().millisecondsSinceEpoch}';
      await tasksRef.doc(testTaskId).set({
        'title': 'Test Task',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _log('✅ Successfully wrote test task');

      // Test 4: Read it back
      final testDoc = await tasksRef.doc(testTaskId).get();
      if (testDoc.exists) {
        _log('✅ Successfully read test task back');
      } else {
        _log('❌ Could not read test task back');
      }

      // Test 5: Delete test task
      await tasksRef.doc(testTaskId).delete();
      _log('✅ Successfully deleted test task');

      setState(() => _status = 'All tests passed!');
    } catch (e) {
      _log('❌ Error: $e');
      setState(() => _status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: $_status',
              style: AppTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const Text(
              'Test Log:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      _logs[index],
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: _logs[index].contains('❌') 
                            ? Colors.red 
                            : _logs[index].contains('✅')
                                ? Colors.green
                                : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _logs.clear();
                  _status = 'Checking...';
                });
                _testFirebase();
              },
              child: const Text('Run Test Again'),
            ),
          ],
        ),
      ),
    );
  }
}