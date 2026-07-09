import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Storage Helper for managing offline prayer time data
///
/// Convention: cached prayer timings are always RAW (no user adjustments
/// applied). User prayer adjustments are applied exactly once, at read time,
/// by PrayerTimeService. Never store adjusted timings here, otherwise
/// adjustments would be applied twice when reading from the cache.
///
/// Dates are always stored in the canonical `DD-MM-YYYY` format (the same
/// format the Aladhan API uses for its gregorian date field).
class StorageHelper {
  static const String _prayerTimesKey = 'cached_prayer_times';
  static const String _lastUpdateKey = 'last_update_time';
  static const String _cachedDateKey = 'cached_date';
  static const String _prayerTimesByDatePrefix = 'cached_prayer_times_';

  /// Per-date cache entries older than this many days are pruned.
  static const int _maxCachedDays = 30;

  /// Format a date as the canonical cache date key (DD-MM-YYYY).
  static String formatDateKey(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  /// Normalize a date string to the canonical DD-MM-YYYY format.
  ///
  /// Accepts DD-MM-YYYY (returned unchanged) or anything `DateTime.parse`
  /// understands (e.g. a legacy `DateTime.toString()` value). Returns null
  /// if the string cannot be interpreted as a date.
  static String? normalizeDateKey(String? rawDate) {
    if (rawDate == null) return null;
    if (RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(rawDate)) return rawDate;
    try {
      return formatDateKey(DateTime.parse(rawDate));
    } catch (e) {
      return null;
    }
  }

  /// Save prayer times data to local storage.
  ///
  /// The timings inside [prayerData] must be RAW (no user adjustments).
  /// The date (if present at `prayerData['date']['gregorian']['date']`) is
  /// normalized to DD-MM-YYYY, and the entry is also cached under a
  /// per-date key so specific dates can be served offline.
  static Future<void> savePrayerTimes(Map<String, dynamic> prayerData) async {
    final prefs = await SharedPreferences.getInstance();

    // Save prayer data
    await prefs.setString(_prayerTimesKey, json.encode(prayerData));

    // Save update timestamp
    await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());

    // Save the date for which these times are cached (normalized format)
    String? dateKey;
    if (prayerData['date'] != null && prayerData['date']['gregorian'] != null) {
      dateKey = normalizeDateKey(prayerData['date']['gregorian']['date']?.toString());
    }
    if (dateKey != null) {
      await prefs.setString(_cachedDateKey, dateKey);
      // Also store under a per-date key for offline date-specific lookups
      await prefs.setString('$_prayerTimesByDatePrefix$dateKey', json.encode(prayerData));
      await _pruneOldDateEntries(prefs);
    }
  }

  /// Save prayer times for a specific date (per-date cache).
  ///
  /// [dateKey] must be DD-MM-YYYY (other parseable formats are normalized).
  /// Timings must be RAW (no user adjustments applied).
  static Future<void> savePrayerTimesForDate(String dateKey, Map<String, dynamic> prayerData) async {
    final normalized = normalizeDateKey(dateKey);
    if (normalized == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prayerTimesByDatePrefix$normalized', json.encode(prayerData));
    await _pruneOldDateEntries(prefs);
  }

  /// Get cached prayer times for a specific date (DD-MM-YYYY).
  /// Returns null if there is no valid cache entry for that date.
  static Future<Map<String, dynamic>?> getCachedPrayerTimesForDate(String dateKey) async {
    final normalized = normalizeDateKey(dateKey);
    if (normalized == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('$_prayerTimesByDatePrefix$normalized');

    if (cachedData != null) {
      try {
        return json.decode(cachedData);
      } catch (e) {
        // If data is corrupted, return null
        return null;
      }
    }
    return null;
  }

  /// Get cached prayer times from local storage
  static Future<Map<String, dynamic>?> getCachedPrayerTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_prayerTimesKey);

    if (cachedData != null) {
      try {
        return json.decode(cachedData);
      } catch (e) {
        // If data is corrupted, return null
        return null;
      }
    }
    return null;
  }

  /// Get the last update time
  static Future<DateTime?> getLastUpdateTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdate = prefs.getString(_lastUpdateKey);

    if (lastUpdate != null) {
      try {
        return DateTime.parse(lastUpdate);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Check whether the main cached data (getCachedPrayerTimes) is for the
  /// given date. Handles legacy date formats by normalizing before comparing.
  static Future<bool> isCachedDataForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedDate = prefs.getString(_cachedDateKey);

    if (cachedDate != null) {
      return normalizeDateKey(cachedDate) == formatDateKey(date);
    }
    return false;
  }

  /// Check if cached data is for today
  static Future<bool> isCachedDataForToday() {
    return isCachedDataForDate(DateTime.now());
  }

  /// Remove per-date cache entries that are older than [_maxCachedDays]
  /// (or whose key cannot be parsed as a date).
  static Future<void> _pruneOldDateEntries(SharedPreferences prefs) async {
    final cutoff = DateTime.now().subtract(const Duration(days: _maxCachedDays));

    for (final key in prefs.getKeys().toList()) {
      if (!key.startsWith(_prayerTimesByDatePrefix)) continue;

      final dateStr = key.substring(_prayerTimesByDatePrefix.length);
      final parts = dateStr.split('-');
      DateTime? date;
      if (parts.length == 3) {
        // DD-MM-YYYY -> ISO for parsing
        date = DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}');
      }

      if (date == null || date.isBefore(cutoff)) {
        await prefs.remove(key);
      }
    }
  }

  /// Clear all cached data
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prayerTimesKey);
    await prefs.remove(_lastUpdateKey);
    await prefs.remove(_cachedDateKey);

    // Also clear all per-date cache entries
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_prayerTimesByDatePrefix)) {
        await prefs.remove(key);
      }
    }
  }
}
