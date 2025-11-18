import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/location_settings.dart' as app_models;
import '../helpers/permission_helper.dart';

class LocationService {
  static const String _locationSettingsKey = 'location_settings';
  static const String _geocodingApiUrl = 'https://nominatim.openstreetmap.org/reverse';
  
  // Get current location settings
  static Future<app_models.LocationSettings> getLocationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_locationSettingsKey);
    
    if (settingsJson != null) {
      return app_models.LocationSettings.fromJson(json.decode(settingsJson));
    }
    
    // Return default settings for Abu Dhabi
    return app_models.LocationSettings(
      useGPS: false,
      customCity: 'Abu Dhabi',
      customCountry: 'United Arab Emirates',
      latitude: 24.4539,
      longitude: 54.3773,
      timezone: 'Asia/Dubai',
      calculationMethod: 16,
    );
  }
  
  // Save location settings
  static Future<void> saveLocationSettings(app_models.LocationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_locationSettingsKey, json.encode(settings.toJson()));
  }
  
  // Get current GPS location
  static Future<Position?> getCurrentLocation() async {
    // Check if location permission is granted
    if (!await PermissionHelper.hasLocationPermission()) {
      final granted = await PermissionHelper.requestLocationPermission();
      if (!granted) {
        return null;
      }
    }
    
    // Check if location service is enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }
    
    try {
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }
  
  // Get city and country from coordinates
  static Future<Map<String, String>?> getCityFromCoordinates(double latitude, double longitude) async {
    try {
      final url = Uri.parse('$_geocodingApiUrl?format=json&lat=$latitude&lon=$longitude&zoom=10&addressdetails=1');
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'TaskFlow Pro Prayer Time App/1.0',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] ?? {};
        
        // Try to get city from various fields
        final city = address['city'] ?? 
                    address['town'] ?? 
                    address['village'] ?? 
                    address['municipality'] ?? 
                    address['state_district'] ??
                    address['state'];
                    
        final country = address['country'];
        
        if (city != null && country != null) {
          return {
            'city': city,
            'country': country,
            'display_name': data['display_name'] ?? '$city, $country',
          };
        }
      }
    } catch (e) {
      print('Error getting city from coordinates: $e');
    }
    
    return null;
  }
  
  // Update location automatically
  static Future<app_models.LocationSettings?> updateLocationAutomatically() async {
    final position = await getCurrentLocation();
    if (position == null) {
      return null;
    }
    
    final cityInfo = await getCityFromCoordinates(position.latitude, position.longitude);
    
    final currentSettings = await getLocationSettings();
    final updatedSettings = currentSettings.copyWith(
      latitude: position.latitude,
      longitude: position.longitude,
      lastDetectedCity: cityInfo?['display_name'],
      lastLocationUpdate: DateTime.now(),
      customCity: cityInfo?['city'] ?? currentSettings.customCity,
      customCountry: cityInfo?['country'] ?? currentSettings.customCountry,
    );
    
    await saveLocationSettings(updatedSettings);
    return updatedSettings;
  }
  
  // Get timezone from coordinates
  static Future<String?> getTimezoneFromCoordinates(double latitude, double longitude) async {
    try {
      // Using TimezoneDB API (you might need to register for a free API key)
      // For now, we'll use a simple mapping based on longitude
      // This is a simplified approach - in production, use a proper timezone API
      
      // Rough timezone calculation based on longitude
      final offset = (longitude / 15).round();
      
      // Common timezone mappings for Middle East region
      if (latitude >= 20 && latitude <= 35) {
        if (longitude >= 45 && longitude <= 60) {
          return 'Asia/Dubai'; // UAE, Oman
        } else if (longitude >= 35 && longitude <= 45) {
          return 'Asia/Riyadh'; // Saudi Arabia
        } else if (longitude >= 25 && longitude <= 35) {
          return 'Africa/Cairo'; // Egypt
        }
      }
      
      // Default to UTC offset
      if (offset >= 0) {
        return 'UTC+$offset';
      } else {
        return 'UTC$offset';
      }
    } catch (e) {
      print('Error getting timezone: $e');
      return null;
    }
  }
  
  // Common cities in the region
  static List<Map<String, dynamic>> getCommonCities() {
    return [
      {'city': 'Abu Dhabi', 'country': 'United Arab Emirates', 'lat': 24.4539, 'lng': 54.3773, 'timezone': 'Asia/Dubai'},
      {'city': 'Dubai', 'country': 'United Arab Emirates', 'lat': 25.2048, 'lng': 55.2708, 'timezone': 'Asia/Dubai'},
      {'city': 'Sharjah', 'country': 'United Arab Emirates', 'lat': 25.3462, 'lng': 55.4209, 'timezone': 'Asia/Dubai'},
      {'city': 'Ajman', 'country': 'United Arab Emirates', 'lat': 25.4052, 'lng': 55.5136, 'timezone': 'Asia/Dubai'},
      {'city': 'Ras Al Khaimah', 'country': 'United Arab Emirates', 'lat': 25.7953, 'lng': 55.9432, 'timezone': 'Asia/Dubai'},
      {'city': 'Fujairah', 'country': 'United Arab Emirates', 'lat': 25.1288, 'lng': 56.3265, 'timezone': 'Asia/Dubai'},
      {'city': 'Riyadh', 'country': 'Saudi Arabia', 'lat': 24.7136, 'lng': 46.6753, 'timezone': 'Asia/Riyadh'},
      {'city': 'Jeddah', 'country': 'Saudi Arabia', 'lat': 21.5433, 'lng': 39.1728, 'timezone': 'Asia/Riyadh'},
      {'city': 'Mecca', 'country': 'Saudi Arabia', 'lat': 21.4225, 'lng': 39.8262, 'timezone': 'Asia/Riyadh'},
      {'city': 'Medina', 'country': 'Saudi Arabia', 'lat': 24.5247, 'lng': 39.5692, 'timezone': 'Asia/Riyadh'},
      {'city': 'Kuwait City', 'country': 'Kuwait', 'lat': 29.3759, 'lng': 47.9774, 'timezone': 'Asia/Kuwait'},
      {'city': 'Doha', 'country': 'Qatar', 'lat': 25.2854, 'lng': 51.5310, 'timezone': 'Asia/Qatar'},
      {'city': 'Manama', 'country': 'Bahrain', 'lat': 26.2285, 'lng': 50.5860, 'timezone': 'Asia/Bahrain'},
      {'city': 'Muscat', 'country': 'Oman', 'lat': 23.5880, 'lng': 58.3829, 'timezone': 'Asia/Muscat'},
      {'city': 'Cairo', 'country': 'Egypt', 'lat': 30.0444, 'lng': 31.2357, 'timezone': 'Africa/Cairo'},
      {'city': 'Istanbul', 'country': 'Turkey', 'lat': 41.0082, 'lng': 28.9784, 'timezone': 'Europe/Istanbul'},
      {'city': 'London', 'country': 'United Kingdom', 'lat': 51.5074, 'lng': -0.1278, 'timezone': 'Europe/London'},
      {'city': 'New York', 'country': 'United States', 'lat': 40.7128, 'lng': -74.0060, 'timezone': 'America/New_York'},
      {'city': 'Los Angeles', 'country': 'United States', 'lat': 34.0522, 'lng': -118.2437, 'timezone': 'America/Los_Angeles'},
      {'city': 'Toronto', 'country': 'Canada', 'lat': 43.6532, 'lng': -79.3832, 'timezone': 'America/Toronto'},
    ];
  }
}