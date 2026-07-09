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
///
/// Adjustment convention: RAW timings (no user adjustments) are computed,
/// fetched, and cached; user prayer adjustments from LocationSettings are
/// applied exactly ONCE at read time, just before a result is returned to
/// callers. Never apply adjustments before caching, and never re-apply them
/// to a result that already includes them.
class PrayerTimeService {
  static const String baseUrl = 'https://api.aladhan.com/v1';

  /// Tune offsets (Imsak,Fajr,Sunrise,Dhuhr,Asr,Maghrib,Sunset,Isha,Midnight)
  /// for the default Abu Dhabi / Dubai configuration (method 16). These match
  /// official UAE mosque timings.
  static const String dubaiTuneParams = '0,1,-3,0,1,1,0,0,0';

  static String _tuneQueryParam(int method) {
    // Only send tune offsets for the default Dubai (method 16) configuration;
    // the offsets are calibrated for Abu Dhabi/UAE official timings.
    return method == 16 ? '&tune=$dubaiTuneParams' : '';
  }

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

  /// Best-effort fixed UTC offsets (in minutes) for the timezone names this
  /// app can store. Used only to detect a mismatch between the device
  /// timezone and the configured location's timezone.
  ///
  /// LIMITATION: without the `timezone` package we can only compare fixed
  /// standard-time offsets and cannot account for DST transitions. A DST
  /// mismatch at worst makes us prefer the API (which returns correct,
  /// city-local times), so this errs on the safe side.
  static const Map<String, int> _knownTimezoneOffsetsMinutes = {
    'Asia/Dubai': 240,
    'Asia/Muscat': 240,
    'Asia/Riyadh': 180,
    'Asia/Kuwait': 180,
    'Asia/Qatar': 180,
    'Asia/Bahrain': 180,
    'Africa/Cairo': 120,
    'Europe/Istanbul': 180,
    'Europe/London': 0,
    'America/New_York': -300,
    'America/Toronto': -300,
    'America/Los_Angeles': -480,
  };

  static int? _offsetMinutesForTimezone(String timezone) {
    final known = _knownTimezoneOffsetsMinutes[timezone];
    if (known != null) return known;

    // 'UTC+4' / 'UTC-5' style strings produced by LocationService
    final match = RegExp(r'^UTC([+-]\d{1,2})$').firstMatch(timezone);
    if (match != null) {
      return int.parse(match.group(1)!) * 60;
    }
    return null;
  }

  /// Whether the device timezone offset matches the configured location's
  /// timezone. The local Adhan calculation formats times in the DEVICE
  /// timezone, so when the configured city is in a different timezone the
  /// locally calculated wall-clock times would be wrong. In that case we
  /// prefer the Aladhan API, which returns times local to the queried city.
  ///
  /// Unknown timezone strings are treated as matching (previous behavior).
  static bool _deviceTimezoneMatchesLocation(app_models.LocationSettings settings) {
    final locationOffset = _offsetMinutesForTimezone(settings.timezone);
    if (locationOffset == null) return true;

    final deviceOffset = DateTime.now().timeZoneOffset.inMinutes;
    return deviceOffset == locationOffset;
  }

  /// Calculate prayer times using Adhan library.
  ///
  /// Returns RAW timings — user prayer adjustments are NOT applied here.
  /// Callers must apply them exactly once at read time via
  /// [applyAdjustmentsToTimings].
  ///
  /// NOTE: the Adhan library returns times in the DEVICE timezone. If the
  /// configured location is in a different timezone these wall-clock times
  /// will be wrong; use the Aladhan API in that case (see
  /// [_deviceTimezoneMatchesLocation]).
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

      // Format RAW times (no user adjustments — applied once at read time)
      final timings = {
        'Fajr': _formatTime(prayerTimes.fajr),
        'Sunrise': _formatTime(prayerTimes.sunrise),
        'Dhuhr': _formatTime(prayerTimes.dhuhr),
        'Asr': _formatTime(prayerTimes.asr),
        'Maghrib': _formatTime(prayerTimes.maghrib),
        'Isha': _formatTime(prayerTimes.isha),
        'Midnight': _formatTime(sunnahTimes.middleOfTheNight),
      };

      return {
        'success': true,
        'timings': timings,
        'date': {
          'gregorian': {
            // Canonical DD-MM-YYYY format (same as the Aladhan API), so
            // cache date validation can compare it reliably.
            'date': StorageHelper.formatDateKey(date),
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

  /// Apply user prayer adjustments to RAW timings.
  ///
  /// Must be called exactly once per read — never on timings that already
  /// include adjustments (the operation is not idempotent), and never before
  /// caching (the cache stores RAW timings). Public for testing.
  static Map<String, dynamic> applyAdjustmentsToTimings(Map<String, dynamic> timings, Map<String, int> adjustments) {
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

  /// Return a copy of a raw result with user adjustments applied to its
  /// timings (the single point where adjustments are applied).
  static Map<String, dynamic> _withAdjustments(Map<String, dynamic> rawResult, app_models.LocationSettings locationSettings) {
    final adjusted = Map<String, dynamic>.from(rawResult);
    if (rawResult['timings'] != null) {
      adjusted['timings'] = applyAdjustmentsToTimings(
        rawResult['timings'] as Map<String, dynamic>,
        locationSettings.prayerAdjustments,
      );
    }
    return adjusted;
  }

  /// Look up cached RAW timings for [date], validating that the cache entry
  /// is actually for that date (never serve another day's times). Returns a
  /// ready-to-use result with adjustments applied, or null if no valid cache.
  static Future<Map<String, dynamic>?> _cachedResultForDate(
    DateTime date,
    app_models.LocationSettings locationSettings,
    String networkStatus,
  ) async {
    final dateKey = StorageHelper.formatDateKey(date);

    // Prefer the per-date cache entry
    Map<String, dynamic>? cachedData = await StorageHelper.getCachedPrayerTimesForDate(dateKey);

    // Fall back to the legacy single-entry cache, but only if its stored
    // date matches the requested date
    if (cachedData == null) {
      final legacyCache = await StorageHelper.getCachedPrayerTimes();
      if (legacyCache != null && await StorageHelper.isCachedDataForDate(date)) {
        cachedData = legacyCache;
      }
    }

    if (cachedData == null || cachedData['timings'] == null) return null;

    return {
      'success': true,
      // Cached timings are RAW — adjustments applied exactly once here
      'timings': applyAdjustmentsToTimings(
        cachedData['timings'] as Map<String, dynamic>,
        locationSettings.prayerAdjustments,
      ),
      'date': cachedData['date'],
      'meta': cachedData['meta'],
      'isFromCache': true,
      'lastUpdate': await StorageHelper.getLastUpdateTime(),
      'networkStatus': networkStatus,
    };
  }

  /// Fallback used when the API is unreachable: date-validated cache first,
  /// then local Adhan calculation as a last resort.
  static Future<Map<String, dynamic>> _fallbackForDate(
    DateTime date,
    app_models.LocationSettings locationSettings, {
    required String networkStatus,
    required String errorMessage,
    required String errorType,
  }) async {
    // Serve cached data only if it is valid for the requested date —
    // a stale cache must never be presented as that day's times
    final cached = await _cachedResultForDate(date, locationSettings, networkStatus);
    if (cached != null) return cached;

    // Cache missing or for the wrong date — fall back to local calculation.
    // LIMITATION: if the configured location is in a different timezone than
    // the device, these times are expressed in the device timezone and may
    // be wrong; the API result is preferred whenever the network is up.
    final localResult = await calculatePrayerTimesLocally(date);
    if (localResult['success'] == true) {
      final result = _withAdjustments(localResult, locationSettings);
      result['networkStatus'] = networkStatus;
      return result;
    }

    return {
      'success': false,
      'error': errorMessage,
      'errorType': errorType,
    };
  }

  /// Get prayer times for today with fallback to API
  static Future<Map<String, dynamic>> getTodayPrayerTimes() async {
    final locationSettings = await LocationService.getLocationSettings();
    final now = DateTime.now();

    // Prefer the Aladhan API when the configured location's timezone differs
    // from the device timezone: the local Adhan calculation produces times in
    // the DEVICE timezone, which would be wrong for a cross-timezone city.
    // The API returns times local to the queried city. (Minimal approach —
    // full timezone support would require the `timezone` package.)
    final preferApi = !_deviceTimezoneMatchesLocation(locationSettings);

    if (!preferApi) {
      // Try local calculation first
      final localResult = await calculatePrayerTimesLocally(now);
      if (localResult['success'] == true) {
        // Cache RAW timings (adjustments are applied once, on return)
        await StorageHelper.savePrayerTimes({
          'timings': localResult['timings'],
          'date': localResult['date'],
          'meta': localResult['meta'],
        });
        return _withAdjustments(localResult, locationSettings);
      }
    }

    // API path (also used when local calculation fails)
    final city = Uri.encodeComponent(locationSettings.customCity ?? 'Abu Dhabi');
    final country = Uri.encodeComponent(locationSettings.customCountry ?? 'United Arab Emirates');
    final method = locationSettings.calculationMethod ?? _getCalculationMethodForLocation(locationSettings.latitude ?? 24.4539, locationSettings.longitude ?? 54.3773);

    try {
      // Date is a path segment (DD-MM-YYYY); tune offsets sent for the
      // default Dubai/Abu Dhabi configuration
      final dateSegment = StorageHelper.formatDateKey(now);
      final response = await http.get(
        Uri.parse('$baseUrl/timingsByCity/$dateSegment?city=$city&country=$country&method=$method${_tuneQueryParam(method)}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Save RAW timings to cache for offline use
        await StorageHelper.savePrayerTimes({
          'timings': data['data']['timings'],
          'date': data['data']['date'],
          'meta': data['data']['meta'],
        });

        // Apply adjustments exactly once, on the returned copy
        return {
          'success': true,
          'timings': applyAdjustmentsToTimings(
            data['data']['timings'] as Map<String, dynamic>,
            locationSettings.prayerAdjustments,
          ),
          'date': data['data']['date'],
          'meta': data['data']['meta'],
          'isFromCache': false,
        };
      } else {
        throw HttpException('Server returned status code: ${response.statusCode}');
      }
    } on SocketException {
      return _fallbackForDate(
        now,
        locationSettings,
        networkStatus: 'offline',
        errorMessage: 'No internet connection. Please check your network settings.',
        errorType: 'network',
      );
    } on TimeoutException {
      return _fallbackForDate(
        now,
        locationSettings,
        networkStatus: 'timeout',
        errorMessage: 'Connection timeout. Please try again.',
        errorType: 'timeout',
      );
    } catch (e) {
      return _fallbackForDate(
        now,
        locationSettings,
        networkStatus: 'error',
        errorMessage: 'An unexpected error occurred: ${e.toString()}',
        errorType: 'unknown',
      );
    }
  }

  /// Get prayer times for a specific date
  /// date format: DD-MM-YYYY
  static Future<Map<String, dynamic>> getPrayerTimesForDate(String date) async {
    final locationSettings = await LocationService.getLocationSettings();
    final preferApi = !_deviceTimezoneMatchesLocation(locationSettings);

    // Parse date string
    DateTime? dateTime;
    final parts = date.split('-');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        dateTime = DateTime(year, month, day);
      }
    }

    if (dateTime != null && !preferApi) {
      // Try local calculation first
      final localResult = await calculatePrayerTimesLocally(dateTime);
      if (localResult['success'] == true) {
        // Cache RAW timings under a per-date key for offline use
        await StorageHelper.savePrayerTimesForDate(StorageHelper.formatDateKey(dateTime), {
          'timings': localResult['timings'],
          'date': localResult['date'],
          'meta': localResult['meta'],
        });
        return _withAdjustments(localResult, locationSettings);
      }
    }

    // API path (also used when local calculation fails).
    // The Aladhan API takes the date as a path segment, not a query param.
    final city = Uri.encodeComponent(locationSettings.customCity ?? 'Abu Dhabi');
    final country = Uri.encodeComponent(locationSettings.customCountry ?? 'United Arab Emirates');
    final method = locationSettings.calculationMethod ?? _getCalculationMethodForLocation(locationSettings.latitude ?? 24.4539, locationSettings.longitude ?? 54.3773);

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/timingsByCity/$date?city=$city&country=$country&method=$method${_tuneQueryParam(method)}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Cache RAW timings per-date for offline use
        if (dateTime != null) {
          await StorageHelper.savePrayerTimesForDate(StorageHelper.formatDateKey(dateTime), {
            'timings': data['data']['timings'],
            'date': data['data']['date'],
            'meta': data['data']['meta'],
          });
        }

        // Apply adjustments exactly once, on the returned copy
        return {
          'success': true,
          'timings': applyAdjustmentsToTimings(
            data['data']['timings'] as Map<String, dynamic>,
            locationSettings.prayerAdjustments,
          ),
          'date': data['data']['date'],
          'meta': data['data']['meta'],
        };
      } else {
        throw Exception('Failed to load prayer times');
      }
    } catch (e) {
      // Offline fallback: date-validated cache, then local calculation
      if (dateTime != null) {
        return _fallbackForDate(
          dateTime,
          locationSettings,
          networkStatus: 'error',
          errorMessage: e.toString(),
          errorType: 'unknown',
        );
      }
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
        ? await getPrayerTimesForDate(StorageHelper.formatDateKey(date))
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
        ? await getPrayerTimesForDate(StorageHelper.formatDateKey(date))
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
