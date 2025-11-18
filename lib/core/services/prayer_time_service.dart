import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:adhan/adhan.dart' as adhan;
import '../helpers/storage_helper.dart';
import '../../models/location_settings.dart' as app_models;
import 'location_service.dart';

/// Prayer Time Service
/// 
/// Uses both Aladhan API and Adhan library for accurate prayer time calculations.
/// Supports multiple calculation methods based on location.
class PrayerTimeService {
  static const String baseUrl = 'https://api.aladhan.com/v1';
  
  /// Get calculation method for location
  static int _getCalculationMethodForLocation(double latitude, double longitude) {
    // Gulf countries
    if (latitude >= 22 && latitude <= 26.5 && longitude >= 47 && longitude <= 56) {
      return 16; // Dubai method for UAE and Gulf region
    }
    
    // Saudi Arabia
    if (latitude >= 16 && latitude <= 32 && longitude >= 34 && longitude <= 55) {
      return 4; // Umm Al-Qura
    }
    
    // Egypt
    if (latitude >= 22 && latitude <= 32 && longitude >= 25 && longitude <= 35) {
      return 5; // Egyptian General Authority
    }
    
    // Turkey
    if (latitude >= 36 && latitude <= 42 && longitude >= 26 && longitude <= 45) {
      return 13; // Turkey
    }
    
    // North America
    if (latitude >= 25 && latitude <= 85 && longitude >= -170 && longitude <= -50) {
      return 2; // ISNA
    }
    
    // Default to Muslim World League
    return 3;
  }
  
  /// Get calculation parameters for Adhan library
  static adhan.CalculationParameters _getAdhanCalculationParams(app_models.LocationSettings location) {
    final method = location.calculationMethod ?? _getCalculationMethodForLocation(location.latitude ?? 24.4539, location.longitude ?? 54.3773);
    
    switch (method) {
      case 2: // ISNA
        return adhan.CalculationMethod.north_america.getParameters();
      case 3: // Muslim World League
        return adhan.CalculationMethod.muslim_world_league.getParameters();
      case 4: // Umm Al-Qura
        return adhan.CalculationMethod.umm_al_qura.getParameters();
      case 5: // Egyptian
        return adhan.CalculationMethod.egyptian.getParameters();
      case 8: // Gulf (similar to Dubai)
      case 16: // Dubai
        return adhan.CalculationMethod.dubai.getParameters();
      case 9: // Kuwait
        return adhan.CalculationMethod.kuwait.getParameters();
      case 10: // Qatar
        return adhan.CalculationMethod.qatar.getParameters();
      case 11: // Singapore
        return adhan.CalculationMethod.singapore.getParameters();
      case 13: // Turkey
        return adhan.CalculationMethod.turkey.getParameters();
      case 7: // Tehran
        return adhan.CalculationMethod.tehran.getParameters();
      case 1: // Karachi
        return adhan.CalculationMethod.karachi.getParameters();
      default:
        // Custom parameters
        final params = adhan.CalculationParameters(
          fajrAngle: 18.0,
          ishaAngle: 17.0,
          method: adhan.CalculationMethod.other,
        );
        return params;
    }
  }
  
  /// Calculate prayer times using Adhan library
  static Future<Map<String, dynamic>> calculatePrayerTimesLocally(DateTime date) async {
    try {
      // Get location settings
      final locationSettings = await LocationService.getLocationSettings();
      
      // Create coordinates
      final coordinates = adhan.Coordinates(locationSettings.latitude ?? 24.4539, locationSettings.longitude ?? 54.3773);
      
      // Get calculation parameters
      final params = _getAdhanCalculationParams(locationSettings);
      
      // Apply high latitude rule for locations above 48°
      if ((locationSettings.latitude ?? 24.4539).abs() > 48) {
        params.highLatitudeRule = adhan.HighLatitudeRule.twilight_angle;
      }
      
      // Calculate prayer times
      final prayerTimes = adhan.PrayerTimes(
        coordinates,
        adhan.DateComponents.from(date),
        params,
      );
      
      // Calculate Sunnah times
      final sunnahTimes = adhan.SunnahTimes(prayerTimes);
      
      // Get prayer adjustments from location settings
      final adjustments = locationSettings.prayerAdjustments;
      
      // Format times with adjustments (keeping times in their local timezone)
      final timings = {
        'Fajr': _formatTimeWithAdjustment(prayerTimes.fajr, adjustments['fajr'] ?? 0),
        'Sunrise': _formatTimeWithAdjustment(prayerTimes.sunrise, adjustments['sunrise'] ?? 0),
        'Dhuhr': _formatTimeWithAdjustment(prayerTimes.dhuhr, adjustments['dhuhr'] ?? 0),
        'Asr': _formatTimeWithAdjustment(prayerTimes.asr, adjustments['asr'] ?? 0),
        'Maghrib': _formatTimeWithAdjustment(prayerTimes.maghrib, adjustments['maghrib'] ?? 0),
        'Isha': _formatTimeWithAdjustment(prayerTimes.isha, adjustments['isha'] ?? 0),
        'Midnight': _formatTime(sunnahTimes.middleOfTheNight),
      };
      
      return {
        'success': true,
        'timings': timings,
        'date': {
          'gregorian': {
            'date': date.toString(),
          }
        },
        'meta': {
          'latitude': locationSettings.latitude ?? 24.4539,
          'longitude': locationSettings.longitude ?? 54.3773,
          'timezone': locationSettings.timezone,
          'method': locationSettings.calculationMethod,
        },
        'isFromCache': false,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to calculate prayer times: $e',
      };
    }
  }
  
  static String _formatTime(DateTime? time) {
    if (time == null) return 'N/A';
    // Keep the time in its original timezone (don't convert to local)
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  
  static String _formatTimeWithAdjustment(DateTime? time, int adjustmentMinutes) {
    if (time == null) return 'N/A';
    // Apply adjustment
    final adjustedTime = time.add(Duration(minutes: adjustmentMinutes));
    return '${adjustedTime.hour.toString().padLeft(2, '0')}:${adjustedTime.minute.toString().padLeft(2, '0')}';
  }
  
  static String _adjustTimeString(String timeStr, int adjustmentMinutes) {
    if (adjustmentMinutes == 0) return timeStr;
    
    try {
      final parts = timeStr.split(':');
      if (parts.length != 2) return timeStr;
      
      int hours = int.parse(parts[0]);
      int minutes = int.parse(parts[1]);
      
      // Add adjustment
      minutes += adjustmentMinutes;
      
      // Handle overflow/underflow
      while (minutes >= 60) {
        minutes -= 60;
        hours += 1;
      }
      while (minutes < 0) {
        minutes += 60;
        hours -= 1;
      }
      
      // Handle hour overflow/underflow
      if (hours >= 24) hours -= 24;
      if (hours < 0) hours += 24;
      
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    } catch (e) {
      return timeStr;
    }
  }
  
  static Map<String, dynamic> _applyAdjustmentsToTimings(Map<String, dynamic> timings, Map<String, int> adjustments) {
    final adjustedTimings = Map<String, dynamic>.from(timings);
    
    final prayersToAdjust = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (final prayer in prayersToAdjust) {
      if (adjustedTimings.containsKey(prayer) && adjustments.containsKey(prayer.toLowerCase())) {
        final adjustment = adjustments[prayer.toLowerCase()] ?? 0;
        adjustedTimings[prayer] = _adjustTimeString(adjustedTimings[prayer].toString(), adjustment);
      }
    }
    
    return adjustedTimings;
  }
  
  /// Get prayer times for today with fallback to API
  static Future<Map<String, dynamic>> getTodayPrayerTimes() async {
    // First try local calculation
    final localResult = await calculatePrayerTimesLocally(DateTime.now());
    if (localResult['success'] == true) {
      // Save to cache
      await StorageHelper.savePrayerTimes({
        'timings': localResult['timings'],
        'date': localResult['date'],
        'meta': localResult['meta'],
      });
      return localResult;
    }
    
    // Fallback to API if local calculation fails
    // Get location settings
    final locationSettings = await LocationService.getLocationSettings();
    
    // Get cached data as a fallback
    final cachedData = await StorageHelper.getCachedPrayerTimes();
    
    // Build API URL with location
    final city = Uri.encodeComponent(locationSettings.customCity ?? 'Abu Dhabi');
    final country = Uri.encodeComponent(locationSettings.customCountry ?? 'United Arab Emirates');
    final method = locationSettings.calculationMethod ?? _getCalculationMethodForLocation(locationSettings.latitude ?? 24.4539, locationSettings.longitude ?? 54.3773);
    
    // Always try to fetch fresh data first
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/timingsByCity?city=$city&country=$country&method=$method'),
      ).timeout(const Duration(seconds: 10));
        
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Apply adjustments to API timings
        final adjustedTimings = _applyAdjustmentsToTimings(
          data['data']['timings'] as Map<String, dynamic>,
          locationSettings.prayerAdjustments,
        );
        
        final result = {
          'success': true,
          'timings': adjustedTimings,
          'date': data['data']['date'],
          'meta': data['data']['meta'],
          'isFromCache': false,
        };
        
        // Save to cache for offline use
        await StorageHelper.savePrayerTimes({
          'timings': data['data']['timings'],
          'date': data['data']['date'],
          'meta': data['data']['meta'],
        });
        
        return result;
      } else {
        throw HttpException('Server returned status code: ${response.statusCode}');
      }
    } on SocketException {
      // Network error - use cached data if available
      if (cachedData != null) {
        // Apply adjustments to cached timings
        final adjustedTimings = _applyAdjustmentsToTimings(
          cachedData['timings'] as Map<String, dynamic>,
          locationSettings.prayerAdjustments,
        );
        
        return {
          'success': true,
          'timings': adjustedTimings,
          'date': cachedData['date'],
          'meta': cachedData['meta'],
          'isFromCache': true,
          'lastUpdate': await StorageHelper.getLastUpdateTime(),
          'networkStatus': 'offline',
        };
      }
      return {
        'success': false,
        'error': 'No internet connection. Please check your network settings.',
        'errorType': 'network',
      };
    } on TimeoutException {
      // Timeout - use cached data if available
      if (cachedData != null) {
        // Apply adjustments to cached timings
        final adjustedTimings = _applyAdjustmentsToTimings(
          cachedData['timings'] as Map<String, dynamic>,
          locationSettings.prayerAdjustments,
        );
        
        return {
          'success': true,
          'timings': adjustedTimings,
          'date': cachedData['date'],
          'meta': cachedData['meta'],
          'isFromCache': true,
          'lastUpdate': await StorageHelper.getLastUpdateTime(),
          'networkStatus': 'timeout',
        };
      }
      return {
        'success': false,
        'error': 'Connection timeout. Please try again.',
        'errorType': 'timeout',
      };
    } catch (e) {
      // Any other error - use cached data if available
      if (cachedData != null) {
        // Apply adjustments to cached timings
        final adjustedTimings = _applyAdjustmentsToTimings(
          cachedData['timings'] as Map<String, dynamic>,
          locationSettings.prayerAdjustments,
        );
        
        return {
          'success': true,
          'timings': adjustedTimings,
          'date': cachedData['date'],
          'meta': cachedData['meta'],
          'isFromCache': true,
          'lastUpdate': await StorageHelper.getLastUpdateTime(),
          'networkStatus': 'error',
        };
      }
      return {
        'success': false,
        'error': 'An unexpected error occurred: ${e.toString()}',
        'errorType': 'unknown',
      };
    }
  }
  
  /// Get prayer times for a specific date
  /// date format: DD-MM-YYYY
  static Future<Map<String, dynamic>> getPrayerTimesForDate(String date) async {
    // Parse date string
    final parts = date.split('-');
    if (parts.length == 3) {
      final dateTime = DateTime(
        int.parse(parts[2]), // year
        int.parse(parts[1]), // month
        int.parse(parts[0]), // day
      );
      
      // Try local calculation first
      final localResult = await calculatePrayerTimesLocally(dateTime);
      if (localResult['success'] == true) {
        return localResult;
      }
    }
    
    // Fallback to API
    final locationSettings = await LocationService.getLocationSettings();
    final city = Uri.encodeComponent(locationSettings.customCity ?? 'Abu Dhabi');
    final country = Uri.encodeComponent(locationSettings.customCountry ?? 'United Arab Emirates');
    final method = locationSettings.calculationMethod ?? _getCalculationMethodForLocation(locationSettings.latitude ?? 24.4539, locationSettings.longitude ?? 54.3773);
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/timingsByCity?city=$city&country=$country&method=$method&date=$date'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Apply adjustments to API timings
        final adjustedTimings = _applyAdjustmentsToTimings(
          data['data']['timings'] as Map<String, dynamic>,
          locationSettings.prayerAdjustments,
        );
        
        return {
          'success': true,
          'timings': adjustedTimings,
          'date': data['data']['date'],
          'meta': data['data']['meta'],
        };
      } else {
        throw Exception('Failed to load prayer times');
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Get formatted prayer times for display
  static List<Map<String, String>> formatPrayerTimes(Map<String, dynamic> timings) {
    final List<String> prayerNames = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final List<Map<String, String>> formattedTimes = [];
    
    for (String prayer in prayerNames) {
      if (timings.containsKey(prayer)) {
        formattedTimes.add({
          'name': prayer,
          'time': timings[prayer] ?? 'N/A',
        });
      }
    }
    
    return formattedTimes;
  }
  
  /// Get prayer times as a simple map for todo list integration
  static Future<Map<String, String>> getPrayerTimes({DateTime? date}) async {
    final result = date != null 
        ? await getPrayerTimesForDate('${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}')
        : await getTodayPrayerTimes();
    
    if (result['success'] == true && result['timings'] != null) {
      final timings = result['timings'] as Map<String, dynamic>;
      
      // Filter to only include the main 5 prayers + sunrise
      final allowedPrayers = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
      final filteredTimings = <String, String>{};
      
      for (final prayer in allowedPrayers) {
        if (timings.containsKey(prayer)) {
          filteredTimings[prayer] = timings[prayer].toString();
        }
      }
      
      return filteredTimings;
    }
    
    // Return empty map if failed
    return {};
  }
  
  /// Get prayer times with status information
  static Future<Map<String, dynamic>> getPrayerTimesWithStatus({DateTime? date}) async {
    final result = date != null 
        ? await getPrayerTimesForDate('${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}')
        : await getTodayPrayerTimes();
    
    // Extract times from result
    Map<String, String> times = {};
    if (result['success'] == true && result['timings'] != null) {
      final timings = result['timings'] as Map<String, dynamic>;
      final allowedPrayers = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
      
      for (final prayer in allowedPrayers) {
        if (timings.containsKey(prayer)) {
          times[prayer] = timings[prayer].toString();
        }
      }
    }
    
    return {
      'times': times,
      'isOffline': result['isFromCache'] ?? false,
      'lastUpdated': result['lastUpdate'],
    };
  }
  
  /// Calculate the actual time from prayer-relative settings
  /// Returns null if prayer time is not available
  static DateTime? calculatePrayerRelativeTime({
    required Map<String, String> prayerTimes,
    required String prayerName,
    required bool isBefore,
    required int minutesOffset,
    DateTime? baseDate,
  }) {
    // Get the prayer time string
    final prayerTimeStr = prayerTimes[prayerName];
    if (prayerTimeStr == null) return null;
    
    // Parse the prayer time (format: "HH:MM (UTC)")
    final timeMatch = RegExp(r'(\d{2}):(\d{2})').firstMatch(prayerTimeStr);
    if (timeMatch == null) return null;
    
    final hour = int.parse(timeMatch.group(1)!);
    final minute = int.parse(timeMatch.group(2)!);
    
    // Create DateTime for the prayer time
    final now = baseDate ?? DateTime.now();
    DateTime prayerTime = DateTime(now.year, now.month, now.day, hour, minute);
    
    // Apply the offset
    if (isBefore) {
      prayerTime = prayerTime.subtract(Duration(minutes: minutesOffset));
    } else {
      prayerTime = prayerTime.add(Duration(minutes: minutesOffset));
    }
    
    return prayerTime;
  }
}