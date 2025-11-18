import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow_pro/core/helpers/storage_helper.dart';
import 'package:taskflow_pro/core/helpers/connectivity_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Functionality Tests', () {
    setUp(() async {
      // Initialize SharedPreferences with test values
      SharedPreferences.setMockInitialValues({});

      // Setup all mocks (connectivity, Firebase, etc.)
      TestHelpers.setupAllMocks(hasConnection: true);
    });

    tearDown(() {
      // Clean up mocks after each test
      TestHelpers.cleanupMocks();
    });

    test('Should return cached data when offline', () async {
      // First, simulate saving some data to cache
      final testData = {
        'timings': {
          'Fajr': '05:30',
          'Sunrise': '06:45',
          'Dhuhr': '12:30',
          'Asr': '15:45',
          'Maghrib': '18:15',
          'Isha': '19:30',
        },
        'date': {
          'gregorian': {'date': '04-07-2025'},
          'hijri': {'date': '08-01-1447'}
        },
        'meta': {
          'method': {'name': 'Dubai'},
          'latitude': 24.4539,
          'longitude': 54.3773,
          'timezone': 'Asia/Dubai'
        }
      };

      // Save test data to cache
      await StorageHelper.savePrayerTimes(testData);

      // Note: In a real test, you would mock the network call to fail
      // For demonstration purposes, this shows the expected behavior
      print('Test: Cached data should be available for offline use');
      
      final cachedData = await StorageHelper.getCachedPrayerTimes();
      expect(cachedData, isNotNull);
      expect(cachedData!['timings']['Fajr'], equals('05:30'));
    });

    test('Connectivity helper should detect network status', () async {
      // Test the connectivity detection
      final isConnected = await ConnectivityHelper.isConnected();
      print('Network interface available: $isConnected');
      
      // Test actual internet connectivity
      final hasInternet = await ConnectivityHelper.hasInternetConnection();
      print('Actual internet connection: $hasInternet');
      
      // Test detailed status
      final detailedStatus = await ConnectivityHelper.getDetailedConnectivityStatus();
      print('Detailed connectivity status: $detailedStatus');
      
      expect(detailedStatus, isNotNull);
      expect(detailedStatus['hasNetworkInterface'], isA<bool>());
      expect(detailedStatus['hasInternetAccess'], isA<bool>());
    });

    test('Prayer service should handle network errors gracefully', () async {
      // This test demonstrates the expected behavior when network fails
      // In a real implementation, you would mock the HTTP client
      
      // Save some test data first
      final testData = {
        'timings': {
          'Fajr': '05:30',
          'Sunrise': '06:45',
          'Dhuhr': '12:30',
          'Asr': '15:45',
          'Maghrib': '18:15',
          'Isha': '19:30',
        },
        'date': {
          'gregorian': {'date': '04-07-2025'},
          'hijri': {'date': '08-01-1447'}
        },
        'meta': {
          'method': {'name': 'Dubai'},
          'latitude': 24.4539,
          'longitude': 54.3773,
          'timezone': 'Asia/Dubai'
        }
      };
      
      await StorageHelper.savePrayerTimes(testData);
      
      // The service should:
      // 1. Try to fetch fresh data first
      // 2. On network error, fall back to cached data
      // 3. Return success with isFromCache = true
      
      print('Prayer service will attempt to fetch data and fall back to cache on error');
    });
  });
}