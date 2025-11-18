/// Test helper utilities and mocks for TaskFlow Pro tests
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sets up mock method channels for testing
class TestHelpers {
  /// Mock the connectivity_plus plugin
  static void setupConnectivityMock({bool hasConnection = true}) {
    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'check':
          // Return connectivity result as List (connectivity_plus expects this format)
          return hasConnection ? ['wifi'] : ['none'];
        case 'wifiName':
          return hasConnection ? 'MockWiFi' : null;
        case 'wifiBSSID':
          return hasConnection ? '00:00:00:00:00:00' : null;
        case 'wifiIPAddress':
          return hasConnection ? '192.168.1.1' : null;
        case 'getLocationServiceEnabled':
          return true;
        default:
          return null;
      }
    });
  }

  /// Mock Firebase Core
  static void setupFirebaseMock() {
    const channel = MethodChannel('plugins.flutter.io/firebase_core');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'Firebase#initializeCore':
          return [
            {
              'name': '[DEFAULT]',
              'options': {
                'apiKey': 'mock-api-key',
                'appId': 'mock-app-id',
                'messagingSenderId': 'mock-sender-id',
                'projectId': 'mock-project-id',
              },
              'pluginConstants': {},
            }
          ];
        case 'Firebase#initializeApp':
          return {
            'name': methodCall.arguments['appName'],
            'options': methodCall.arguments['options'],
            'pluginConstants': {},
          };
        default:
          return null;
      }
    });
  }

  /// Mock Firebase Auth
  static void setupFirebaseAuthMock() {
    const channel = MethodChannel('plugins.flutter.io/firebase_auth');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'Auth#registerIdTokenListener':
          return {'name': 'mock-auth'};
        case 'Auth#registerAuthStateListener':
          return {'name': 'mock-auth'};
        case 'Auth#authStateChanges':
          return null;
        case 'Auth#idTokenChanges':
          return null;
        case 'Auth#userChanges':
          return null;
        default:
          return null;
      }
    });
  }

  /// Mock Firestore
  static void setupFirestoreMock() {
    const channel = MethodChannel('plugins.flutter.io/cloud_firestore');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      // Return empty data for all Firestore operations
      return null;
    });
  }

  /// Setup all common mocks for tests
  static void setupAllMocks({bool hasConnection = true}) {
    setupConnectivityMock(hasConnection: hasConnection);
    setupFirebaseMock();
    setupFirebaseAuthMock();
    setupFirestoreMock();
  }

  /// Clean up all mocks
  static void cleanupMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/connectivity'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/firebase_core'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/firebase_auth'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/cloud_firestore'), null);
  }
}
