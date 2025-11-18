class LocationSettings {
  final bool useGPS;
  final String? customCity;
  final String? customCountry;
  final double? latitude;
  final double? longitude;
  final String timezone;
  final int calculationMethod;
  final Map<String, int> prayerAdjustments;
  final String? lastDetectedCity;
  final DateTime? lastLocationUpdate;
  
  LocationSettings({
    this.useGPS = true,
    this.customCity,
    this.customCountry,
    this.latitude,
    this.longitude,
    this.timezone = 'Asia/Dubai',
    this.calculationMethod = 16, // Dubai method by default
    Map<String, int>? prayerAdjustments,
    this.lastDetectedCity,
    this.lastLocationUpdate,
  }) : prayerAdjustments = prayerAdjustments ?? {
    'fajr': 0,
    'sunrise': 0,
    'dhuhr': 0,
    'asr': 0,
    'maghrib': 0,
    'isha': 0,
  };
  
  Map<String, dynamic> toJson() => {
    'useGPS': useGPS,
    'customCity': customCity,
    'customCountry': customCountry,
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
    'calculationMethod': calculationMethod,
    'prayerAdjustments': prayerAdjustments,
    'lastDetectedCity': lastDetectedCity,
    'lastLocationUpdate': lastLocationUpdate?.toIso8601String(),
  };
  
  factory LocationSettings.fromJson(Map<String, dynamic> json) {
    return LocationSettings(
      useGPS: json['useGPS'] ?? true,
      customCity: json['customCity'],
      customCountry: json['customCountry'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      timezone: json['timezone'] ?? 'Asia/Dubai',
      calculationMethod: json['calculationMethod'] ?? 16,
      prayerAdjustments: Map<String, int>.from(json['prayerAdjustments'] ?? {}),
      lastDetectedCity: json['lastDetectedCity'],
      lastLocationUpdate: json['lastLocationUpdate'] != null 
          ? DateTime.parse(json['lastLocationUpdate']) 
          : null,
    );
  }
  
  LocationSettings copyWith({
    bool? useGPS,
    String? customCity,
    String? customCountry,
    double? latitude,
    double? longitude,
    String? timezone,
    int? calculationMethod,
    Map<String, int>? prayerAdjustments,
    String? lastDetectedCity,
    DateTime? lastLocationUpdate,
  }) {
    return LocationSettings(
      useGPS: useGPS ?? this.useGPS,
      customCity: customCity ?? this.customCity,
      customCountry: customCountry ?? this.customCountry,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timezone: timezone ?? this.timezone,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      prayerAdjustments: prayerAdjustments ?? this.prayerAdjustments,
      lastDetectedCity: lastDetectedCity ?? this.lastDetectedCity,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
    );
  }
}

// Prayer calculation methods
class CalculationMethod {
  final int id;
  final String name;
  final String description;
  
  const CalculationMethod({
    required this.id,
    required this.name,
    required this.description,
  });
}

const List<CalculationMethod> availableCalculationMethods = [
  CalculationMethod(
    id: 1,
    name: 'University of Islamic Sciences, Karachi',
    description: 'Fajr: 18°, Isha: 18°',
  ),
  CalculationMethod(
    id: 2,
    name: 'Islamic Society of North America (ISNA)',
    description: 'Fajr: 15°, Isha: 15°',
  ),
  CalculationMethod(
    id: 3,
    name: 'Muslim World League',
    description: 'Fajr: 18°, Isha: 17°',
  ),
  CalculationMethod(
    id: 4,
    name: 'Umm Al-Qura University, Makkah',
    description: 'Fajr: 18.5°, Isha: 90 min after Maghrib',
  ),
  CalculationMethod(
    id: 5,
    name: 'Egyptian General Authority of Survey',
    description: 'Fajr: 19.5°, Isha: 17.5°',
  ),
  CalculationMethod(
    id: 7,
    name: 'Institute of Geophysics, University of Tehran',
    description: 'Fajr: 17.7°, Isha: 14°',
  ),
  CalculationMethod(
    id: 8,
    name: 'Gulf Region',
    description: 'Fajr: 19.5°, Isha: 90 min after Maghrib',
  ),
  CalculationMethod(
    id: 9,
    name: 'Kuwait',
    description: 'Fajr: 18°, Isha: 17.5°',
  ),
  CalculationMethod(
    id: 10,
    name: 'Qatar',
    description: 'Fajr: 18°, Isha: 90 min after Maghrib',
  ),
  CalculationMethod(
    id: 11,
    name: 'Majlis Ugama Islam Singapura, Singapore',
    description: 'Fajr: 20°, Isha: 18°',
  ),
  CalculationMethod(
    id: 12,
    name: 'Union Organization Islamic de France',
    description: 'Fajr: 12°, Isha: 12°',
  ),
  CalculationMethod(
    id: 13,
    name: 'Diyanet İşleri Başkanlığı, Turkey',
    description: 'Fajr: 18°, Isha: 17°',
  ),
  CalculationMethod(
    id: 14,
    name: 'Spiritual Administration of Muslims of Russia',
    description: 'Fajr: 16°, Isha: 15°',
  ),
  CalculationMethod(
    id: 15,
    name: 'Moonsighting Committee Worldwide',
    description: 'Uses traditional moonsighting',
  ),
  CalculationMethod(
    id: 16,
    name: 'Dubai',
    description: 'Fajr: 18.2°, Isha: 18.2°',
  ),
];