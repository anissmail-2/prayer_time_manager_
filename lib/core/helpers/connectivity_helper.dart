import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';

/// Connectivity Helper for managing network status
class ConnectivityHelper {
  static final Connectivity _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  /// Check if device is connected to internet
  static Future<bool> isConnected() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }
  
  /// Listen to connectivity changes
  static Stream<bool> connectivityStream() {
    return _connectivity.onConnectivityChanged.map((results) {
      return !results.contains(ConnectivityResult.none);
    });
  }
  
  /// Start listening to connectivity changes
  static void startListening(Function(bool) onConnectivityChanged) {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      onConnectivityChanged(isConnected);
    });
  }
  
  /// Stop listening to connectivity changes
  static void stopListening() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
  
  /// Get human-readable connection status
  static Future<String> getConnectionStatus() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return 'No Internet Connection';
    } else if (connectivityResult.contains(ConnectivityResult.mobile)) {
      return 'Connected via Mobile Data';
    } else if (connectivityResult.contains(ConnectivityResult.wifi)) {
      return 'Connected via WiFi';
    } else if (connectivityResult.contains(ConnectivityResult.ethernet)) {
      return 'Connected via Ethernet';
    } else {
      return 'Connected';
    }
  }
  
  /// Check actual internet connectivity by trying to reach a reliable endpoint
  static Future<bool> hasInternetConnection() async {
    try {
      // First check if we have any network interface
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      }
      
      // Try to reach a reliable endpoint
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
  
  /// Check connectivity with multiple fallback checks
  static Future<Map<String, dynamic>> getDetailedConnectivityStatus() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    final hasInternet = await hasInternetConnection();
    
    return {
      'hasNetworkInterface': !connectivityResult.contains(ConnectivityResult.none),
      'hasInternetAccess': hasInternet,
      'connectionType': connectivityResult,
      'status': hasInternet ? 'online' : 'offline',
    };
  }
}