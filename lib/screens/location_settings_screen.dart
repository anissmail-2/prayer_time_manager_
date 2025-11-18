import 'package:flutter/material.dart';
import '../models/location_settings.dart' as app_models;
import '../core/services/location_service.dart';
import '../core/theme/app_theme.dart';
import 'map_location_screen.dart';

class LocationSettingsScreen extends StatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  State<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  app_models.LocationSettings _settings = app_models.LocationSettings();
  bool _isLoading = true;
  bool _isDetectingLocation = false;
  
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppTheme.animationMedium,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: AppTheme.animationCurve,
    );
    _loadSettings();
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSettings() async {
    final settings = await LocationService.getLocationSettings();
    setState(() {
      _settings = settings;
      _cityController.text = settings.customCity ?? '';
      _countryController.text = settings.customCountry ?? '';
      _isLoading = false;
    });
  }
  
  Future<void> _saveSettings() async {
    await LocationService.saveLocationSettings(_settings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Location settings saved'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
        ),
      );
    }
  }
  
  int _getCalculationMethodForLocation(double latitude, double longitude) {
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
  
  Future<void> _detectLocation() async {
    setState(() => _isDetectingLocation = true);
    
    try {
      final updatedSettings = await LocationService.updateLocationAutomatically();
      
      if (updatedSettings != null) {
        // Auto-detect calculation method based on coordinates
        final autoMethod = _getCalculationMethodForLocation(
          updatedSettings.latitude ?? 24.4539,
          updatedSettings.longitude ?? 54.3773,
        );
        
        setState(() {
          _settings = updatedSettings.copyWith(calculationMethod: autoMethod);
          _cityController.text = updatedSettings.customCity ?? '';
          _countryController.text = updatedSettings.customCountry ?? '';
        });
        
        await _saveSettings();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location detected: ${updatedSettings.lastDetectedCity ?? "Unknown"}'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not detect location. Please check permissions and try again.'),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isDetectingLocation = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Location Settings',
          style: AppTheme.headlineSmall.copyWith(
            color: isDark ? Colors.white : AppTheme.primary,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : AppTheme.primary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : AppTheme.primary,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: Text(
              'Save',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.space16),
          children: [
            // GPS Toggle Section
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.1) : AppTheme.borderLight,
                ),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      'Use GPS Location',
                      style: AppTheme.titleMedium,
                    ),
                    subtitle: Text(
                      'Automatically detect your location for accurate prayer times',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    value: _settings.useGPS,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(useGPS: value);
                      });
                    },
                    activeThumbColor: AppTheme.primary,
                  ),
                  
                  if (_settings.useGPS) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.space16),
                      child: Column(
                        children: [
                          if (_settings.latitude != null && _settings.longitude != null) ...[
                            Container(
                              padding: const EdgeInsets.all(AppTheme.space12),
                              decoration: BoxDecoration(
                                color: isDark 
                                    ? Colors.white.withOpacity(0.05)
                                    : AppTheme.backgroundLight,
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: AppTheme.success,
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppTheme.space8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Current Coordinates',
                                          style: AppTheme.labelSmall.copyWith(
                                            color: AppTheme.textTertiary,
                                          ),
                                        ),
                                        Text(
                                          '${_settings.latitude!.toStringAsFixed(4)}, ${_settings.longitude!.toStringAsFixed(4)}',
                                          style: AppTheme.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (_settings.lastDetectedCity != null) ...[
                                          const SizedBox(height: AppTheme.space4),
                                          Text(
                                            _settings.lastDetectedCity!,
                                            style: AppTheme.labelSmall.copyWith(
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppTheme.space12),
                          ],
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isDetectingLocation ? null : _detectLocation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(AppTheme.space16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                ),
                              ),
                              icon: _isDetectingLocation
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.my_location),
                              label: Text(
                                _isDetectingLocation ? 'Detecting...' : 'Detect My Location',
                                style: AppTheme.titleMedium.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.space12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push<Map<String, dynamic>>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MapLocationScreen(
                                      initialLatitude: _settings.latitude,
                                      initialLongitude: _settings.longitude,
                                    ),
                                  ),
                                );
                                
                                if (result != null) {
                                  // Auto-detect calculation method based on selected coordinates
                                  final autoMethod = _getCalculationMethodForLocation(
                                    result['latitude'],
                                    result['longitude'],
                                  );
                                  
                                  setState(() {
                                    _settings = _settings.copyWith(
                                      latitude: result['latitude'],
                                      longitude: result['longitude'],
                                      lastDetectedCity: result['name'],
                                      lastLocationUpdate: DateTime.now(),
                                      customCity: result['name']?.split(',')[0].trim() ?? _settings.customCity,
                                      customCountry: result['name']?.contains(',') == true 
                                          ? result['name'].split(',').last.trim()
                                          : _settings.customCountry,
                                      calculationMethod: autoMethod,
                                    );
                                    _cityController.text = _settings.customCity ?? '';
                                    _countryController.text = _settings.customCountry ?? '';
                                  });
                                  
                                  await _saveSettings();
                                  
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Location selected: ${result['name']}'),
                                        backgroundColor: AppTheme.success,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                padding: const EdgeInsets.all(AppTheme.space16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                ),
                                side: BorderSide(color: AppTheme.primary),
                              ),
                              icon: const Icon(Icons.map),
                              label: Text(
                                'Choose on Map',
                                style: AppTheme.titleMedium.copyWith(
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: AppTheme.space24),
            
            // Manual Location Section
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.1) : AppTheme.borderLight,
                ),
              ),
              padding: const EdgeInsets.all(AppTheme.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.space8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Icon(
                          Icons.edit_location,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Text(
                        'Manual Location',
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space16),
                  
                  TextField(
                    controller: _cityController,
                    decoration: InputDecoration(
                      labelText: 'City',
                      hintText: 'Enter your city',
                      prefixIcon: Icon(Icons.location_city, color: AppTheme.primary),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : AppTheme.backgroundLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white.withOpacity(0.1) : AppTheme.borderLight,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide: BorderSide(
                          color: AppTheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      _settings = _settings.copyWith(customCity: value);
                    },
                  ),
                  
                  const SizedBox(height: AppTheme.space16),
                  
                  TextField(
                    controller: _countryController,
                    decoration: InputDecoration(
                      labelText: 'Country',
                      hintText: 'Enter your country',
                      prefixIcon: Icon(Icons.flag, color: AppTheme.primary),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : AppTheme.backgroundLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white.withOpacity(0.1) : AppTheme.borderLight,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide: BorderSide(
                          color: AppTheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      _settings = _settings.copyWith(customCountry: value);
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppTheme.space24),
            
            // Common Cities
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.1) : AppTheme.borderLight,
                ),
              ),
              padding: const EdgeInsets.all(AppTheme.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.space8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Icon(
                          Icons.location_searching,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Text(
                        'Common Cities',
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space16),
                  
                  Wrap(
                    spacing: AppTheme.space8,
                    runSpacing: AppTheme.space8,
                    children: LocationService.getCommonCities()
                        .take(8)
                        .map((cityData) => InkWell(
                          onTap: () {
                            // Auto-detect calculation method based on city coordinates
                            final autoMethod = _getCalculationMethodForLocation(
                              cityData['lat'],
                              cityData['lng'],
                            );
                            
                            setState(() {
                              _cityController.text = cityData['city'];
                              _countryController.text = cityData['country'];
                              _settings = _settings.copyWith(
                                customCity: cityData['city'],
                                customCountry: cityData['country'],
                                latitude: cityData['lat'],
                                longitude: cityData['lng'],
                                timezone: cityData['timezone'],
                                calculationMethod: autoMethod,
                              );
                            });
                          },
                          borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.space12,
                              vertical: AppTheme.space8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? Colors.white.withOpacity(0.05)
                                  : AppTheme.backgroundLight,
                              borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
                              border: Border.all(
                                color: isDark 
                                    ? Colors.white.withOpacity(0.1)
                                    : AppTheme.borderLight,
                              ),
                            ),
                            child: Text(
                              cityData['city'],
                              style: AppTheme.labelLarge.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ))
                        .toList(),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppTheme.space24),
            
            // Calculation Method Section
            _buildCalculationMethodSection(isDark),
            
            const SizedBox(height: AppTheme.space24),
            
            // Prayer Time Adjustments
            _buildPrayerAdjustmentsSection(isDark),
            
            const SizedBox(height: AppTheme.space32),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCalculationMethodSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : AppTheme.borderLight,
        ),
      ),
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.space8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  Icons.calculate,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Text(
                'Calculation Method',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : AppTheme.borderLight,
              ),
            ),
            child: DropdownButtonFormField<int>(
              initialValue: _settings.calculationMethod,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space16,
                  vertical: AppTheme.space12,
                ),
              ),
              dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
              items: app_models.availableCalculationMethods.map((method) {
                return DropdownMenuItem(
                  value: method.id,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        method.name,
                        style: AppTheme.bodyMedium,
                      ),
                      Text(
                        method.description,
                        style: AppTheme.labelSmall.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _settings = _settings.copyWith(calculationMethod: value);
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPrayerAdjustmentsSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : AppTheme.borderLight,
        ),
      ),
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.space8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  Icons.tune,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prayer Time Adjustments',
                      style: AppTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Fine-tune prayer times (in minutes)',
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          
          ...['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'].map((prayer) {
            final adjustmentKey = prayer.toLowerCase();
            final currentValue = _settings.prayerAdjustments[adjustmentKey] ?? 0;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space12),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      prayer,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              final newAdjustments = Map<String, int>.from(_settings.prayerAdjustments);
                              newAdjustments[adjustmentKey] = currentValue - 1;
                              _settings = _settings.copyWith(prayerAdjustments: newAdjustments);
                            });
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(AppTheme.space4),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.remove,
                              size: 16,
                              color: AppTheme.error,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? Colors.white.withOpacity(0.05)
                                  : AppTheme.backgroundLight,
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: Center(
                              child: Text(
                                currentValue > 0 ? '+$currentValue' : currentValue.toString(),
                                style: AppTheme.titleMedium.copyWith(
                                  color: currentValue == 0 
                                      ? AppTheme.textSecondary
                                      : currentValue > 0 
                                          ? AppTheme.success
                                          : AppTheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              final newAdjustments = Map<String, int>.from(_settings.prayerAdjustments);
                              newAdjustments[adjustmentKey] = currentValue + 1;
                              _settings = _settings.copyWith(prayerAdjustments: newAdjustments);
                            });
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(AppTheme.space4),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add,
                              size: 16,
                              color: AppTheme.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}