import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/services/location_service.dart';
import '../core/theme/app_theme.dart';

class MapLocationScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const MapLocationScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<MapLocationScreen> createState() => _MapLocationScreenState();
}

class _MapLocationScreenState extends State<MapLocationScreen> {
  late MapController _mapController;
  LatLng? _selectedLocation;
  String _locationName = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isLoadingLocation = false;
  
  // Common cities in the region
  final List<Map<String, dynamic>> _quickCities = [
    {'name': 'Abu Dhabi, UAE', 'lat': 24.4539, 'lng': 54.3773},
    {'name': 'Dubai, UAE', 'lat': 25.2048, 'lng': 55.2708},
    {'name': 'Mecca, Saudi Arabia', 'lat': 21.4225, 'lng': 39.8262},
    {'name': 'Medina, Saudi Arabia', 'lat': 24.5247, 'lng': 39.5692},
    {'name': 'Riyadh, Saudi Arabia', 'lat': 24.7136, 'lng': 46.6753},
    {'name': 'Kuwait City, Kuwait', 'lat': 29.3759, 'lng': 47.9774},
    {'name': 'Doha, Qatar', 'lat': 25.2854, 'lng': 51.5310},
    {'name': 'Cairo, Egypt', 'lat': 30.0444, 'lng': 31.2357},
    {'name': 'Istanbul, Turkey', 'lat': 41.0082, 'lng': 28.9784},
    {'name': 'London, UK', 'lat': 51.5074, 'lng': -0.1278},
    {'name': 'New York, USA', 'lat': 40.7128, 'lng': -74.0060},
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
      _updateLocationName();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateLocationName() async {
    if (_selectedLocation == null) return;
    
    setState(() => _isLoadingLocation = true);
    
    final cityInfo = await LocationService.getCityFromCoordinates(
      _selectedLocation!.latitude,
      _selectedLocation!.longitude,
    );
    
    if (mounted) {
      setState(() {
        _locationName = cityInfo?['display_name'] ?? 
                       '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    setState(() => _isSearching = true);
    
    try {
      // Simple geocoding - in a real app, you'd use a proper geocoding API
      // For now, check if it matches any of our quick cities
      final matchingCity = _quickCities.firstWhere(
        (city) => city['name'].toLowerCase().contains(query.toLowerCase()),
        orElse: () => <String, dynamic>{},
      );
      
      if (matchingCity.isNotEmpty) {
        final latLng = LatLng(matchingCity['lat'], matchingCity['lng']);
        setState(() {
          _selectedLocation = latLng;
          _locationName = matchingCity['name'];
        });
        _mapController.move(latLng, 12);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location not found')),
          );
        }
      }
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng position) {
    setState(() {
      _selectedLocation = position;
    });
    _updateLocationName();
  }

  void _selectLocation() {
    if (_selectedLocation != null) {
      Navigator.pop(context, {
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'name': _locationName,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Location'),
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: _selectLocation,
              child: Text(
                'SELECT',
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation ?? 
                            LatLng(widget.initialLatitude ?? 24.4539, 
                                  widget.initialLongitude ?? 54.3773),
              initialZoom: _selectedLocation != null ? 12 : 5,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.prayer.taskflow_pro',
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 80,
                      height: 80,
                      child: Icon(
                        Icons.location_pin,
                        color: AppTheme.error,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          // Search Box
          Positioned(
            top: AppTheme.space16,
            left: AppTheme.space16,
            right: AppTheme.space16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppTheme.space16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search for a location...',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _searchLocation(),
                      ),
                    ),
                    if (_isSearching)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _searchLocation,
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          // Quick Cities
          Positioned(
            top: 80,
            left: AppTheme.space16,
            right: AppTheme.space16,
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _quickCities.length,
                itemBuilder: (context, index) {
                  final city = _quickCities[index];
                  return Padding(
                    padding: EdgeInsets.only(right: AppTheme.space8),
                    child: ActionChip(
                      label: Text(city['name'].split(',')[0]),
                      onPressed: () {
                        final latLng = LatLng(city['lat'], city['lng']);
                        setState(() {
                          _selectedLocation = latLng;
                          _locationName = city['name'];
                        });
                        _mapController.move(latLng, 12);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Location Info
          if (_selectedLocation != null)
            Positioned(
              bottom: AppTheme.space16,
              left: AppTheme.space16,
              right: AppTheme.space16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.space16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoadingLocation)
                        const CircularProgressIndicator()
                      else
                        Text(
                          _locationName,
                          style: AppTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      SizedBox(height: AppTheme.space8),
                      Text(
                        'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                        'Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                        style: AppTheme.labelSmall,
                      ),
                      SizedBox(height: AppTheme.space12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _selectLocation,
                          icon: const Icon(Icons.check),
                          label: const Text('Select This Location'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: AppTheme.space12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final position = await LocationService.getCurrentLocation();
          if (position != null) {
            final latLng = LatLng(position.latitude, position.longitude);
            setState(() {
              _selectedLocation = latLng;
            });
            _mapController.move(latLng, 14);
            _updateLocationName();
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Unable to get current location. Please check location permissions.'),
                ),
              );
            }
          }
        },
        tooltip: 'Use current location',
        child: const Icon(Icons.my_location),
      ),
    );
  }
}