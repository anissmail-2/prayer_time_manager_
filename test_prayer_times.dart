import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  // Test fetching prayer times for different dates
  final dates = [
    DateTime(2025, 1, 8),   // January
    DateTime(2025, 7, 8),   // July (Today)
    DateTime(2025, 10, 14), // October
    DateTime(2025, 12, 8),  // December
  ];
  
  for (final date in dates) {
    // Try different date formats
    final dateStr1 = '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}'; // DD-MM-YYYY
    final dateStr2 = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'; // YYYY-MM-DD
    final dateStr3 = '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}-${date.year}'; // MM-DD-YYYY
    
    print('\nTrying different formats for ${date.toString().split(' ')[0]}:');
    
    // Try DD-MM-YYYY format
    print('Format DD-MM-YYYY: $dateStr1');
    try {
      final url = 'https://api.aladhan.com/v1/timingsByCity?city=Abu%20Dhabi&country=United%20Arab%20Emirates&method=16&tune=0,1,-3,0,1,1,0,0,0&date=$dateStr1';
      print('URL: $url');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final timings = data['data']['timings'];
        final dateInfo = data['data']['date'];
        
        print('Response date: ${dateInfo['readable']} (Gregorian: ${dateInfo['gregorian']['date']})');
        print('Prayer times:');
        print('  Fajr: ${timings['Fajr']}');
        print('  Sunrise: ${timings['Sunrise']}');
        print('  Dhuhr: ${timings['Dhuhr']}');
        print('  Asr: ${timings['Asr']}');
        print('  Maghrib: ${timings['Maghrib']}');
        print('  Isha: ${timings['Isha']}');
      } else {
        print('Error: Status code ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
  
  exit(0);
}