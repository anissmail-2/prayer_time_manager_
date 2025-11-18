import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  // Test date: October 14, 2025
  final formats = {
    'DD-MM-YYYY': '14-10-2025',
    'YYYY-MM-DD': '2025-10-14',
    'MM-DD-YYYY': '10-14-2025',
    'D-M-YYYY': '14-10-2025',
    'timestamp': '1760371200', // Unix timestamp for Oct 14, 2025
  };
  
  for (final entry in formats.entries) {
    print('\nTrying format ${entry.key}: ${entry.value}');
    
    try {
      final url = 'https://api.aladhan.com/v1/timingsByCity?city=Abu%20Dhabi&country=United%20Arab%20Emirates&method=16&tune=0,1,-3,0,1,1,0,0,0&date=${entry.value}';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final dateInfo = data['data']['date'];
        print('Response date: ${dateInfo['readable']} (Gregorian: ${dateInfo['gregorian']['date']})');
        
        final timings = data['data']['timings'];
        print('Fajr: ${timings['Fajr']}, Dhuhr: ${timings['Dhuhr']}, Maghrib: ${timings['Maghrib']}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
  
  exit(0);
}