/// Prayer Time API Helper
/// 
/// This helper demonstrates how to fetch prayer times for Abu Dhabi
/// using the Aladhan API (free, no authentication required)
/// 
/// Example usage:
/// ```dart
/// // Add http package to pubspec.yaml first:
/// // dependencies:
/// //   http: ^1.1.0
/// 
/// import 'package:http/http.dart' as http;
/// import 'dart:convert';
/// 
/// class PrayerTimeApi {
///   static const String baseUrl = 'https://api.aladhan.com/v1';
///   
///   /// Get prayer times for Abu Dhabi
///   /// Returns a map with prayer times for the current day
///   static Future<Map<String, dynamic>> getPrayerTimes() async {
///     try {
///       final response = await http.get(
///         Uri.parse('$baseUrl/timingsByCity?city=Abu%20Dhabi&country=UAE&method=2'),
///       );
///       
///       if (response.statusCode == 200) {
///         final data = json.decode(response.body);
///         return data['data']['timings'];
///       } else {
///         throw Exception('Failed to load prayer times');
///       }
///     } catch (e) {
///       throw Exception('Error fetching prayer times: $e');
///     }
///   }
///   
///   /// Get prayer times for a specific date
///   /// date format: DD-MM-YYYY
///   static Future<Map<String, dynamic>> getPrayerTimesForDate(String date) async {
///     try {
///       final response = await http.get(
///         Uri.parse('$baseUrl/timingsByCity?city=Abu%20Dhabi&country=UAE&method=2&date=$date'),
///       );
///       
///       if (response.statusCode == 200) {
///         final data = json.decode(response.body);
///         return data['data']['timings'];
///       } else {
///         throw Exception('Failed to load prayer times');
///       }
///     } catch (e) {
///       throw Exception('Error fetching prayer times: $e');
///     }
///   }
/// }
/// ```
/// 
/// Response format:
/// {
///   "Fajr": "05:35",
///   "Sunrise": "06:57",
///   "Dhuhr": "12:30",
///   "Asr": "15:45",
///   "Sunset": "18:03",
///   "Maghrib": "18:03",
///   "Isha": "19:33",
///   "Imsak": "05:25",
///   "Midnight": "00:30"
/// }
/// 
/// Methods available:
/// 0 - Shia Ithna-Ansari
/// 1 - University of Islamic Sciences, Karachi
/// 2 - Islamic Society of North America
/// 3 - Muslim World League
/// 4 - Umm Al-Qura University, Makkah
/// 5 - Egyptian General Authority of Survey
/// 7 - Institute of Geophysics, University of Tehran
/// 8 - Gulf Region
/// 9 - Kuwait
/// 10 - Qatar
/// 11 - Majlis Ugama Islam Singapura, Singapore
/// 12 - Union Organization islamic de France
/// 13 - Diyanet İşleri Başkanlığı, Turkey
/// 14 - Spiritual Administration of Muslims of Russia
/// 
/// For UAE/Abu Dhabi, use method 16 (Dubai) with tune parameters: 0,1,-3,0,1,1,0,0,0
/// This gives accurate times matching official UAE mosque timings.
library;

class PrayerTimeApiExample {
  // This class serves as documentation for the prayer time API
  // Implementation should be added when http package is included
}