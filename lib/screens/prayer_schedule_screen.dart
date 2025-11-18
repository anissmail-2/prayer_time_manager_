import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/services/prayer_time_service.dart';
import '../models/prayer_duration.dart';
import '../models/task.dart';
import '../core/services/prayer_duration_service.dart';
import '../core/services/location_service.dart';
import '../core/theme/app_theme.dart';
import 'prayer_settings_screen.dart';
import 'location_settings_screen.dart';

class PrayerScheduleScreen extends StatefulWidget {
  const PrayerScheduleScreen({super.key});

  @override
  State<PrayerScheduleScreen> createState() => _PrayerScheduleScreenState();
}

class _PrayerScheduleScreenState extends State<PrayerScheduleScreen> {
  Map<String, String> _prayerTimes = {};
  Map<PrayerName, PrayerDuration> _prayerDurations = {};
  bool _isLoading = true;
  bool _isOffline = false;
  DateTime? _lastUpdated;
  String? _nextPrayer;
  Duration? _timeToNextPrayer;
  String _currentLocation = 'Loading...';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 30));
      if (!mounted) return false;
      _updateNextPrayer();
      return true;
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Get current location settings
      final locationSettings = await LocationService.getLocationSettings();
      setState(() {
        _currentLocation = '${locationSettings.customCity ?? 'Unknown'}, ${locationSettings.customCountry ?? ''}';
      });
      
      final result = await PrayerTimeService.getPrayerTimesWithStatus(date: _selectedDate);
      _prayerTimes = result['times'] as Map<String, String>;
      _isOffline = result['isOffline'] as bool;
      _lastUpdated = result['lastUpdated'] as DateTime?;
      
      _prayerDurations = await PrayerDurationService.getAllDurations();
      _updateNextPrayer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading prayer times: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _updateNextPrayer() {
    if (_prayerTimes.isEmpty) return;
    
    final now = DateTime.now();
    final currentTime = TimeOfDay.now();
    
    String? nextPrayerName;
    TimeOfDay? nextPrayerTimeOfDay;
    
    for (final entry in _prayerTimes.entries) {
      if (entry.key == 'Sunrise') continue;
      
      final parts = entry.value.split(':');
      if (parts.length != 2) continue;
      
      final prayerTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
      
      if (_isTimeAfter(prayerTime, currentTime)) {
        nextPrayerName = entry.key;
        nextPrayerTimeOfDay = prayerTime;
        break;
      }
    }
    
    if (nextPrayerName == null) {
      nextPrayerName = 'Fajr';
      final fajrTime = _prayerTimes['Fajr']!.split(':');
      nextPrayerTimeOfDay = TimeOfDay(
        hour: int.parse(fajrTime[0]),
        minute: int.parse(fajrTime[1]),
      );
    }
    
    if (nextPrayerTimeOfDay != null) {
      final nextDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        nextPrayerTimeOfDay.hour,
        nextPrayerTimeOfDay.minute,
      );
      
      Duration diff = nextDateTime.difference(now);
      if (diff.isNegative) {
        diff = nextDateTime.add(const Duration(days: 1)).difference(now);
      }
      
      setState(() {
        _nextPrayer = nextPrayerName;
        _timeToNextPrayer = diff;
      });
    }
  }

  bool _isTimeAfter(TimeOfDay time1, TimeOfDay time2) {
    if (time1.hour > time2.hour) return true;
    if (time1.hour == time2.hour && time1.minute > time2.minute) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.space24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: AppTheme.space24),
                    if (_isOffline || _lastUpdated != null) _buildStatusBanner(),
                    if (_nextPrayer != null) ...[
                      _buildNextPrayerCard(),
                      const SizedBox(height: AppTheme.space24),
                    ],
                    _buildPrayerTimesList(),
                    const SizedBox(height: AppTheme.space24),
                    _buildSettingsButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prayer Schedule',
          style: AppTheme.headlineLarge.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LocationSettingsScreen(),
              ),
            );
            // Reload data when returning from location settings
            _loadData();
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space8,
              vertical: AppTheme.space4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: AppTheme.space4),
                Flexible(
                  child: Text(
                    _currentLocation,
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                Icon(
                  Icons.edit,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            
            if (picked != null && picked != _selectedDate) {
              setState(() {
                _selectedDate = picked;
              });
              _loadData();
            }
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space8,
              vertical: AppTheme.space4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: AppTheme.space4),
                Text(
                  DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: AppTheme.space4),
                if (_selectedDate.day == DateTime.now().day &&
                    _selectedDate.month == DateTime.now().month &&
                    _selectedDate.year == DateTime.now().year)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space8,
                      vertical: AppTheme.space4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Text(
                      'Today',
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTheme.space16),
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: _isOffline ? AppTheme.warning.withOpacity(0.1) : AppTheme.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(
          color: _isOffline ? AppTheme.warning.withOpacity(0.3) : AppTheme.info.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isOffline ? Icons.wifi_off : Icons.update,
            color: _isOffline ? AppTheme.warning : AppTheme.info,
            size: 20,
          ),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(
              _isOffline
                  ? 'Offline - Showing cached prayer times'
                  : 'Last updated: ${_lastUpdated != null ? DateFormat('MMM d, h:mm a').format(_lastUpdated!) : 'Unknown'}',
              style: AppTheme.bodySmall.copyWith(
                color: _isOffline ? AppTheme.warning : AppTheme.info,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextPrayerCard() {
    if (_nextPrayer == null || _timeToNextPrayer == null) {
      return const SizedBox.shrink();
    }

    final hours = _timeToNextPrayer!.inHours;
    final minutes = _timeToNextPrayer!.inMinutes % 60;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary,
            AppTheme.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.shadowLarge,
      ),
      child: Column(
        children: [
          Text(
            'Next Prayer',
            style: AppTheme.bodyLarge.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            _nextPrayer!,
            style: AppTheme.displaySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            _prayerTimes[_nextPrayer!] ?? '',
            style: AppTheme.headlineMedium.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space20,
              vertical: AppTheme.space12,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
            ),
            child: Text(
              hours > 0 ? '$hours hr $minutes min' : '$minutes minutes',
              style: AppTheme.titleLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTimesList() {
    final prayers = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Prayer Times',
          style: AppTheme.titleLarge.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.space16),
        ...prayers.map((prayerName) {
          final time = _prayerTimes[prayerName] ?? 'N/A';
          final prayer = prayerName == 'Sunrise' 
              ? null 
              : PrayerName.values.firstWhere(
                  (p) => p.toString().split('.').last.toLowerCase() == prayerName.toLowerCase(),
                  orElse: () => PrayerName.fajr,
                );
          
          return _buildPrayerTimeCard(
            name: prayerName,
            time: time,
            prayer: prayer,
          );
        }),
      ],
    );
  }

  Widget _buildPrayerTimeCard({
    required String name,
    required String time,
    PrayerName? prayer,
  }) {
    final isNextPrayer = name == _nextPrayer;
    final duration = prayer != null ? _prayerDurations[prayer] : null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space12),
      decoration: AppTheme.cardDecoration(
        color: isNextPrayer ? AppTheme.primary.withOpacity(0.05) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppTheme.space16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getPrayerColor(name).withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(
            name == 'Sunrise' ? Icons.wb_sunny : Icons.access_time,
            color: _getPrayerColor(name),
          ),
        ),
        title: Text(
          name,
          style: AppTheme.titleMedium.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: isNextPrayer ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        subtitle: duration != null
            ? Text(
                'Duration: ${duration.totalDuration} min',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              )
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: AppTheme.headlineSmall.copyWith(
                color: isNextPrayer ? AppTheme.primary : AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isNextPrayer)
              Container(
                margin: const EdgeInsets.only(top: AppTheme.space4),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space8,
                  vertical: AppTheme.space4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
                ),
                child: Text(
                  'NEXT',
                  style: AppTheme.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PrayerSettingsScreen(),
            ),
          );
          await _loadData();
        },
        icon: const Icon(Icons.settings),
        label: const Text('Prayer Time Settings'),
        style: AppTheme.secondaryButtonStyle(
          padding: const EdgeInsets.all(AppTheme.space16),
        ),
      ),
    );
  }

  Color _getPrayerColor(String prayerName) {
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        return AppTheme.fajrColor;
      case 'sunrise':
        return AppTheme.sunriseColor;
      case 'dhuhr':
        return AppTheme.dhuhrColor;
      case 'asr':
        return AppTheme.asrColor;
      case 'maghrib':
        return AppTheme.maghribColor;
      case 'isha':
        return AppTheme.ishaColor;
      default:
        return AppTheme.primary;
    }
  }
}