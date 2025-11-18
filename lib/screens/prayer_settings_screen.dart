import 'package:flutter/material.dart';
import '../models/prayer_duration.dart';
import '../models/task.dart';
import '../core/services/prayer_duration_service.dart';
import '../core/services/prayer_time_service.dart';
import '../core/theme/app_theme.dart';

class PrayerSettingsScreen extends StatefulWidget {
  final PrayerName? initialPrayer;
  final bool singlePrayerMode;
  final DateTime? specificDate;
  
  const PrayerSettingsScreen({
    super.key,
    this.initialPrayer,
    this.singlePrayerMode = false,
    this.specificDate,
  });

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> with SingleTickerProviderStateMixin {
  Map<PrayerName, PrayerDuration> _durations = {};
  Map<PrayerName, PrayerDuration> _globalDurations = {}; // Store global defaults for reference
  Map<String, String> _prayerTimes = {};
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final ScrollController _scrollController = ScrollController();
  
  // Text controllers for each prayer's before/after values
  final Map<PrayerName, TextEditingController> _beforeControllers = {};
  final Map<PrayerName, TextEditingController> _afterControllers = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppTheme.animationMedium,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppTheme.animationCurve,
    ));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppTheme.animationCurve,
    ));
    
    // Initialize controllers for all prayers
    for (final prayer in PrayerName.values) {
      _beforeControllers[prayer] = TextEditingController();
      _afterControllers[prayer] = TextEditingController();
    }
    
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Always load global durations for reference
      _globalDurations = await PrayerDurationService.getAllDurations();
      
      if (widget.singlePrayerMode && widget.specificDate != null && widget.initialPrayer != null) {
        // Load day-specific override or fall back to global
        final duration = await PrayerDurationService.getDurationForDate(widget.initialPrayer!, widget.specificDate!);
        _durations = {widget.initialPrayer!: duration};
      } else {
        _durations = Map.from(_globalDurations);
      }
      _prayerTimes = await PrayerTimeService.getPrayerTimes();
      
      // Update controllers with loaded values
      for (final entry in _durations.entries) {
        _beforeControllers[entry.key]?.text = entry.value.minutesBefore.toString();
        _afterControllers[entry.key]?.text = entry.value.minutesAfter.toString();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: AppTheme.space8),
              Expanded(child: Text('Error loading data: $e')),
            ],
          ),
          backgroundColor: AppTheme.error,
        ),
      );
    }
    
    setState(() => _isLoading = false);
    _animationController.forward();
    
    // Scroll to initial prayer if provided
    if (widget.initialPrayer != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToInitialPrayer();
      });
    }
  }
  
  void _scrollToInitialPrayer() {
    if (!_scrollController.hasClients) return;
    
    final prayers = [PrayerName.fajr, PrayerName.dhuhr, PrayerName.asr, PrayerName.maghrib, PrayerName.isha];
    final index = prayers.indexOf(widget.initialPrayer!);
    
    if (index != -1) {
      // Approximate position (each card is about 160 pixels)
      final scrollPosition = index * 160.0;
      
      _scrollController.animateTo(
        scrollPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _resetToDefault(PrayerName prayer) async {
    final defaultDuration = PrayerDuration(
      prayer: prayer,
      minutesBefore: _getDefaultMinutesBefore(prayer),
      minutesAfter: _getDefaultMinutesAfter(prayer),
    );
    
    setState(() {
      _durations[prayer] = defaultDuration;
      // Update the text controllers to reflect the new values
      _beforeControllers[prayer]?.text = defaultDuration.minutesBefore.toString();
      _afterControllers[prayer]?.text = defaultDuration.minutesAfter.toString();
    });
    
    if (widget.singlePrayerMode && widget.specificDate != null) {
      // Clear the day-specific override by saving the default value
      await PrayerDurationService.saveDayOverride(prayer, widget.specificDate!, defaultDuration);
    } else {
      // Save globally
      await PrayerDurationService.updateDuration(defaultDuration);
    }
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reset ${prayer.toString().split('.').last} to default values'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _updateDuration(PrayerName prayer, int? minutesBefore, int? minutesAfter) async {
    final current = _durations[prayer]!;
    final updated = current.copyWith(
      minutesBefore: minutesBefore ?? current.minutesBefore,
      minutesAfter: minutesAfter ?? current.minutesAfter,
    );
    
    setState(() {
      _durations[prayer] = updated;
    });
    
    if (widget.singlePrayerMode && widget.specificDate != null) {
      // Save as day-specific override
      await PrayerDurationService.saveDayOverride(prayer, widget.specificDate!, updated);
    } else {
      // Save globally
      await PrayerDurationService.updateDuration(updated);
    }
  }

  bool _isDefaultValue(PrayerName prayer) {
    final current = _durations[prayer];
    if (current == null) return true;
    
    return current.minutesBefore == _getDefaultMinutesBefore(prayer) &&
           current.minutesAfter == _getDefaultMinutesAfter(prayer);
  }

  int _getDefaultMinutesBefore(PrayerName prayer) {
    final defaults = {
      PrayerName.fajr: 15,
      PrayerName.sunrise: 0,
      PrayerName.dhuhr: 10,
      PrayerName.asr: 10,
      PrayerName.maghrib: 10,
      PrayerName.isha: 10,
    };
    return defaults[prayer] ?? 10;
  }

  int _getDefaultMinutesAfter(PrayerName prayer) {
    final defaults = {
      PrayerName.fajr: 20,
      PrayerName.sunrise: 15,
      PrayerName.dhuhr: 20,
      PrayerName.asr: 15,
      PrayerName.maghrib: 15,
      PrayerName.isha: 20,
    };
    return defaults[prayer] ?? 15;
  }

  String _getPrayerTime(PrayerName prayer) {
    final prayerKey = prayer.toString().split('.').last;
    final capitalizedKey = prayerKey.substring(0, 1).toUpperCase() + prayerKey.substring(1);
    return _prayerTimes[capitalizedKey] ?? 'N/A';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'today';
    } else if (date.year == now.year && date.month == now.month && date.day == now.day + 1) {
      return 'tomorrow';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _getTimeRange(PrayerName prayer) {
    final duration = _durations[prayer];
    if (duration == null) return '';
    
    final prayerTime = _getPrayerTime(prayer);
    if (prayerTime == 'N/A') return '';
    
    final parts = prayerTime.split(':');
    if (parts.length != 2) return '';
    
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return '';
    
    final actualTime = DateTime(2024, 1, 1, hour, minute);
    final startTime = actualTime.subtract(Duration(minutes: duration.minutesBefore));
    final endTime = actualTime.add(Duration(minutes: duration.minutesAfter));
    
    final startStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final endStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    
    return '$startStr - $endStr';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.singlePrayerMode && widget.initialPrayer != null
            ? '${widget.initialPrayer.toString().split('.').last.substring(0, 1).toUpperCase()}${widget.initialPrayer.toString().split('.').last.substring(1)} Settings'
            : 'Prayer Time Settings'),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppTheme.backgroundDark, AppTheme.surfaceDark]
                : [AppTheme.background, AppTheme.surfaceVariant.withAlpha(51)],
          ),
        ),
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: AppTheme.space16),
                    Text(
                      'Loading prayer settings...',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              )
            : FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppTheme.space16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.space16),
                        decoration: AppTheme.cardDecoration(
                          color: isDark ? AppTheme.surfaceDark : AppTheme.surface,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppTheme.space8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.info.withAlpha(26),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  ),
                                  child: Icon(
                                    Icons.info_outline,
                                    color: AppTheme.info,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.space12),
                                Expanded(
                                  child: Text(
                                    widget.singlePrayerMode && widget.initialPrayer != null
                                        ? 'Adjust duration settings for ${widget.initialPrayer.toString().split('.').last.substring(0, 1).toUpperCase()}${widget.initialPrayer.toString().split('.').last.substring(1)}'
                                        : 'Set how much time you need before and after each prayer',
                                    style: AppTheme.titleMedium.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.space12),
                            Text(
                              widget.singlePrayerMode && widget.specificDate != null
                                  ? 'Changes apply only to ${_formatDate(widget.specificDate!)}'
                                  : widget.singlePrayerMode
                                      ? 'Changes will apply to all future occurrences of this prayer'
                                      : 'This helps calculate your actual prayer time blocks and free time',
                              style: AppTheme.bodyMedium.copyWith(
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.space16),
                      ...(widget.singlePrayerMode && widget.initialPrayer != null 
                          ? [widget.initialPrayer!]
                          : PrayerName.values).map((prayer) {
                        final duration = _durations[prayer]!;
                        final prayerName = prayer.toString().split('.').last;
                        final displayName = prayerName.substring(0, 1).toUpperCase() + prayerName.substring(1);
                        final index = PrayerName.values.indexOf(prayer);
                        
                        final isHighlighted = widget.initialPrayer == prayer;
                        
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 300 + (index * 100)),
                          curve: AppTheme.animationCurve,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Opacity(
                                opacity: value,
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: AppTheme.space16),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.surfaceDark : AppTheme.surface,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              boxShadow: AppTheme.shadowMedium,
                              border: isHighlighted 
                                  ? Border.all(
                                      color: _getPrayerColor(prayer),
                                      width: 2.0,
                                    )
                                  : null,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.space16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(AppTheme.space8),
                                        decoration: BoxDecoration(
                                          color: _getPrayerColor(prayer).withAlpha(26),
                                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                        ),
                                        child: Icon(
                                          Icons.mosque,
                                          color: _getPrayerColor(prayer),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.space12),
                                      Text(
                                        displayName,
                                        style: AppTheme.titleLarge.copyWith(
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppTheme.space12,
                                          vertical: AppTheme.space4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getPrayerColor(prayer).withAlpha(26),
                                          borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
                                        ),
                                        child: Text(
                                          _getPrayerTime(prayer),
                                          style: AppTheme.titleMedium.copyWith(
                                            color: _getPrayerColor(prayer),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.space12),
                                  Container(
                                    padding: const EdgeInsets.all(AppTheme.space12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withAlpha(13)
                                          : AppTheme.primary.withAlpha(13),
                                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withAlpha(26)
                                            : AppTheme.primary.withAlpha(26),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.schedule,
                                          size: 16,
                                          color: AppTheme.primary,
                                        ),
                                        const SizedBox(width: AppTheme.space8),
                                        Text(
                                          'Time block: ${_getTimeRange(prayer)}',
                                          style: AppTheme.bodyMedium.copyWith(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.space16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Minutes Before',
                                              style: AppTheme.labelLarge.copyWith(
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: AppTheme.space8),
                                            TextFormField(
                                              controller: _beforeControllers[prayer],
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                filled: true,
                                                fillColor: isDark
                                                    ? Colors.white.withAlpha(13)
                                                    : AppTheme.surfaceVariant,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                                  borderSide: BorderSide.none,
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                                  borderSide: BorderSide.none,
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                                  borderSide: BorderSide(
                                                    color: _getPrayerColor(prayer),
                                                    width: 2,
                                                  ),
                                                ),
                                                contentPadding: const EdgeInsets.all(AppTheme.space12),
                                              ),
                                              onChanged: (value) {
                                                final minutes = int.tryParse(value);
                                                if (minutes != null && minutes >= 0) {
                                                  _updateDuration(prayer, minutes, null);
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.space16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Minutes After',
                                              style: AppTheme.labelLarge.copyWith(
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: AppTheme.space8),
                                            TextFormField(
                                              controller: _afterControllers[prayer],
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                filled: true,
                                                fillColor: isDark
                                                    ? Colors.white.withAlpha(13)
                                                    : AppTheme.surfaceVariant,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                                  borderSide: BorderSide.none,
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                                  borderSide: BorderSide.none,
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                                  borderSide: BorderSide(
                                                    color: _getPrayerColor(prayer),
                                                    width: 2,
                                                  ),
                                                ),
                                                contentPadding: const EdgeInsets.all(AppTheme.space12),
                                              ),
                                              onChanged: (value) {
                                                final minutes = int.tryParse(value);
                                                if (minutes != null && minutes >= 0) {
                                                  _updateDuration(prayer, null, minutes);
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.space8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.timer,
                                        size: 14,
                                        color: Theme.of(context).textTheme.bodySmall?.color,
                                      ),
                                      const SizedBox(width: AppTheme.space4),
                                      Text(
                                        'Total duration: ${duration.totalDuration} minutes',
                                        style: AppTheme.bodySmall.copyWith(
                                          color: Theme.of(context).textTheme.bodySmall?.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Show reset button only when values are not default
                                  if (!_isDefaultValue(prayer)) ...[
                                    const SizedBox(height: AppTheme.space12),
                                    Container(
                                      padding: const EdgeInsets.all(AppTheme.space12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.info.withAlpha(13),
                                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                        border: Border.all(
                                          color: AppTheme.info.withAlpha(51),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.info_outline,
                                                size: 16,
                                                color: AppTheme.info,
                                              ),
                                              const SizedBox(width: AppTheme.space8),
                                              Text(
                                                'Default: ${_getDefaultMinutesBefore(prayer)} min before, ${_getDefaultMinutesAfter(prayer)} min after',
                                                style: AppTheme.bodySmall.copyWith(
                                                  color: AppTheme.info,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: AppTheme.space8),
                                          SizedBox(
                                            width: double.infinity,
                                            child: TextButton.icon(
                                              onPressed: () => _resetToDefault(prayer),
                                              icon: const Icon(Icons.restore, size: 18),
                                              label: const Text('Reset to Default'),
                                              style: TextButton.styleFrom(
                                                foregroundColor: AppTheme.info,
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
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
  
  Color _getPrayerColor(PrayerName prayer) {
    switch (prayer) {
      case PrayerName.fajr:
        return AppTheme.fajrColor;
      case PrayerName.sunrise:
        return AppTheme.sunriseColor;
      case PrayerName.dhuhr:
        return AppTheme.dhuhrColor;
      case PrayerName.asr:
        return AppTheme.asrColor;
      case PrayerName.maghrib:
        return AppTheme.maghribColor;
      case PrayerName.isha:
        return AppTheme.ishaColor;
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    
    // Dispose all text controllers
    for (final controller in _beforeControllers.values) {
      controller.dispose();
    }
    for (final controller in _afterControllers.values) {
      controller.dispose();
    }
    
    super.dispose();
  }
}