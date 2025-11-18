import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity.dart';
import '../models/task.dart';
import '../models/space.dart';
import '../core/services/activity_service.dart';
import '../core/services/space_service.dart';
import '../core/services/prayer_time_service.dart';
import '../core/theme/app_theme.dart';

class AddEditActivityScreen extends StatefulWidget {
  final Activity? activity;
  final DateTime? initialStartTime;
  final DateTime? initialEndTime;

  const AddEditActivityScreen({
    super.key,
    this.activity,
    this.initialStartTime,
    this.initialEndTime,
  });

  @override
  State<AddEditActivityScreen> createState() => _AddEditActivityScreenState();
}

class _AddEditActivityScreenState extends State<AddEditActivityScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _attendeesController = TextEditingController();
  
  ActivityType _selectedType = ActivityType.meeting;
  ScheduleType _scheduleType = ScheduleType.absolute;
  DateTime? _startTime;
  DateTime? _endTime;
  
  // Prayer relative fields
  PrayerName? _selectedPrayer;
  bool _isBeforePrayer = true;
  int _minutesOffset = 0;
  PrayerName? _endSelectedPrayer;
  final bool _endIsBeforePrayer = false;
  int _endMinutesOffset = 30;
  Map<String, String> _prayerTimes = {};
  
  bool _isAllDay = false;
  ActivityRecurrence _recurrence = ActivityRecurrence.once;
  List<int> _selectedWeekDays = [];
  DateTime? _recurrenceEndDate;
  Space? _selectedSpace;
  List<Space> _spaces = [];
  String? _selectedColor;
  
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
    
    _loadSpaces();
    _loadPrayerTimes();
    
    if (widget.activity != null) {
      // Edit mode
      _titleController.text = widget.activity!.title;
      _descriptionController.text = widget.activity!.description ?? '';
      _locationController.text = widget.activity!.location ?? '';
      _notesController.text = widget.activity!.notes ?? '';
      _attendeesController.text = widget.activity!.attendees.join(', ');
      _selectedType = widget.activity!.type;
      _startTime = widget.activity!.startTime;
      _endTime = widget.activity!.endTime;
      _isAllDay = widget.activity!.isAllDay;
      _recurrence = widget.activity!.recurrence;
      _selectedWeekDays = widget.activity!.weeklyDays ?? [];
      _recurrenceEndDate = widget.activity!.recurrenceEndDate;
      _selectedColor = widget.activity!.color;
      // TODO: Load prayer-relative data from activity metadata if stored
    } else {
      // Add mode
      final now = DateTime.now();
      _startTime = widget.initialStartTime ?? 
          DateTime(now.year, now.month, now.day, now.hour + 1, 0);
      _endTime = widget.initialEndTime ?? 
          _startTime!.add(const Duration(hours: 1));
    }
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _attendeesController.dispose();
    super.dispose();
  }

  Future<void> _loadSpaces() async {
    try {
      final spaces = await SpaceService.getAllSpaces();
      setState(() {
        _spaces = spaces;
        if (widget.activity?.spaceId != null) {
          _selectedSpace = spaces.firstWhere(
            (s) => s.id == widget.activity!.spaceId,
            orElse: () => spaces.first,
          );
        }
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadPrayerTimes() async {
    try {
      _prayerTimes = await PrayerTimeService.getPrayerTimes();
      setState(() {});
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _selectDate(bool isStart) async {
    final initialDate = isStart ? _startTime : _endTime;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    
    if (date != null) {
      setState(() {
        if (isStart) {
          _startTime = DateTime(
            date.year,
            date.month,
            date.day,
            _startTime?.hour ?? 9,
            _startTime?.minute ?? 0,
          );
          // Update end time if needed
          if (_endTime == null || _endTime!.isBefore(_startTime!)) {
            _endTime = _startTime!.add(const Duration(hours: 1));
          }
        } else {
          _endTime = DateTime(
            date.year,
            date.month,
            date.day,
            _endTime?.hour ?? 10,
            _endTime?.minute ?? 0,
          );
        }
      });
    }
  }

  Future<void> _selectTime(bool isStart) async {
    if (_isAllDay) return;
    
    final initialTime = isStart ? _startTime : _endTime;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialTime ?? DateTime.now()),
    );
    
    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = DateTime(
            _startTime?.year ?? DateTime.now().year,
            _startTime?.month ?? DateTime.now().month,
            _startTime?.day ?? DateTime.now().day,
            time.hour,
            time.minute,
          );
          // Update end time if needed
          if (_endTime == null || _endTime!.isBefore(_startTime!)) {
            _endTime = _startTime!.add(const Duration(hours: 1));
          }
        } else {
          final newEndTime = DateTime(
            _endTime?.year ?? _startTime?.year ?? DateTime.now().year,
            _endTime?.month ?? _startTime?.month ?? DateTime.now().month,
            _endTime?.day ?? _startTime?.day ?? DateTime.now().day,
            time.hour,
            time.minute,
          );
          
          if (_startTime != null && newEndTime.isBefore(_startTime!)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('End time must be after start time')),
            );
            return;
          }
          
          _endTime = newEndTime;
        }
      });
    }
  }

  Future<void> _selectRecurrenceEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: _startTime ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    
    if (date != null) {
      setState(() {
        _recurrenceEndDate = date;
      });
    }
  }

  List<String> _parseAttendees() {
    return _attendeesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _saveActivity() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Calculate times based on schedule type
    DateTime? calculatedStartTime;
    DateTime? calculatedEndTime;
    
    if (_scheduleType == ScheduleType.absolute) {
      if (_startTime == null || _endTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select start and end times')),
        );
        return;
      }
      calculatedStartTime = _startTime;
      calculatedEndTime = _endTime;
    } else {
      // Prayer relative
      if (_selectedPrayer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a prayer')),
        );
        return;
      }
      
      // Calculate start time based on prayer
      final today = DateTime.now();
      final prayerTime = await _calculatePrayerTime(_selectedPrayer!, today);
      if (prayerTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not calculate prayer time')),
        );
        return;
      }
      
      calculatedStartTime = _isBeforePrayer
          ? prayerTime.subtract(Duration(minutes: _minutesOffset))
          : prayerTime.add(Duration(minutes: _minutesOffset));
      
      // Calculate end time based on duration
      calculatedEndTime = calculatedStartTime.add(Duration(minutes: _endMinutesOffset));
    }

    // Build metadata for prayer-relative scheduling
    final metadata = <String, dynamic>{};
    if (_scheduleType == ScheduleType.prayerRelative) {
      metadata['scheduleType'] = 'prayerRelative';
      metadata['relatedPrayer'] = _selectedPrayer.toString();
      metadata['isBeforePrayer'] = _isBeforePrayer;
      metadata['minutesOffset'] = _minutesOffset;
      metadata['duration'] = _endMinutesOffset;
    }

    try {
      if (widget.activity != null) {
        // Update existing activity
        final updatedActivity = widget.activity!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          type: _selectedType,
          startTime: calculatedStartTime!,
          endTime: calculatedEndTime!,
          location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
          attendees: _parseAttendees(),
          spaceId: _selectedSpace?.id,
          recurrence: _recurrence,
          weeklyDays: _recurrence == ActivityRecurrence.weekly ? _selectedWeekDays : null,
          recurrenceEndDate: _recurrenceEndDate,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          isAllDay: _isAllDay,
          color: _selectedColor,
          metadata: metadata.isNotEmpty ? metadata : null,
        );
        await ActivityService.updateActivity(updatedActivity);
      } else {
        // Create new activity
        await ActivityService.createActivity(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          type: _selectedType,
          startTime: calculatedStartTime!,
          endTime: calculatedEndTime!,
          location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
          attendees: _parseAttendees(),
          spaceId: _selectedSpace?.id,
          recurrence: _recurrence,
          weeklyDays: _recurrence == ActivityRecurrence.weekly ? _selectedWeekDays : null,
          recurrenceEndDate: _recurrenceEndDate,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          isAllDay: _isAllDay,
          color: _selectedColor,
          metadata: metadata.isNotEmpty ? metadata : null,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving activity: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<DateTime?> _calculatePrayerTime(PrayerName prayer, DateTime date) async {
    try {
      final prayerTimes = await PrayerTimeService.getPrayerTimes();
      final prayerStr = prayer.toString().split('.').last;
      final displayName = prayerStr.substring(0, 1).toUpperCase() + prayerStr.substring(1);
      final timeStr = prayerTimes[displayName];
      
      if (timeStr != null) {
        final parts = timeStr.split(':');
        if (parts.length == 2) {
          return DateTime(
            date.year,
            date.month,
            date.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
        }
      }
    } catch (e) {
      // Handle error
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surface,
        elevation: 0,
        title: Text(
          widget.activity != null ? 'Edit Activity' : 'New Activity',
          style: AppTheme.headlineSmall.copyWith(
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saveActivity,
            child: Text(
              'Save',
              style: AppTheme.titleMedium.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.space24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title field
                TextFormField(
                  controller: _titleController,
                  style: AppTheme.bodyLarge.copyWith(
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter activity title',
                    prefixIcon: Icon(Icons.event, color: AppTheme.primary),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.transparent,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide(
                        color: AppTheme.primary,
                        width: 2,
                      ),
                    ),
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white70 : AppTheme.textSecondary,
                    ),
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : AppTheme.textTertiary,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.space24),

                // Activity type
                Text(
                  'Activity Type',
                  style: AppTheme.titleMedium.copyWith(
                    color: isDark ? Colors.white70 : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
                _buildTypeSelector(isDark),
                const SizedBox(height: AppTheme.space24),

                // Schedule Type
                Text(
                  'Schedule Type',
                  style: AppTheme.titleMedium.copyWith(
                    color: isDark ? Colors.white70 : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildScheduleTypeOption(
                          type: ScheduleType.absolute,
                          icon: Icons.access_time,
                          label: 'Specific Time',
                          isSelected: _scheduleType == ScheduleType.absolute,
                          isDark: isDark,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 50,
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                      ),
                      Expanded(
                        child: _buildScheduleTypeOption(
                          type: ScheduleType.prayerRelative,
                          icon: Icons.mosque,
                          label: 'Prayer Related',
                          isSelected: _scheduleType == ScheduleType.prayerRelative,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space24),

                // Date and time
                AnimatedSwitcher(
                  duration: AppTheme.animationFast,
                  child: _scheduleType == ScheduleType.absolute
                      ? _buildDateTimeSection(isDark)
                      : _buildPrayerRelativeSection(isDark),
                ),
                const SizedBox(height: AppTheme.space24),

                // Location field
                TextFormField(
                  controller: _locationController,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Location (optional)',
                    hintText: 'Enter location',
                    prefixIcon: Icon(Icons.location_on, color: AppTheme.primary),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.transparent,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide(
                        color: AppTheme.primary,
                        width: 2,
                      ),
                    ),
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white70 : AppTheme.textSecondary,
                    ),
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : AppTheme.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.space24),

                // Attendees field
                TextFormField(
                  controller: _attendeesController,
                  decoration: const InputDecoration(
                    labelText: 'Attendees (optional)',
                    hintText: 'Enter names separated by commas',
                    prefixIcon: Icon(Icons.people),
                  ),
                ),
                const SizedBox(height: AppTheme.space24),

                // Space selection
                if (_spaces.isNotEmpty) ...[
                  Text(
                    'Space (optional)',
                    style: AppTheme.titleMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space12),
                  _buildSpaceSelector(),
                  const SizedBox(height: AppTheme.space24),
                ],

                // Recurrence
                _buildRecurrenceSection(),
                const SizedBox(height: AppTheme.space24),

                // Description field
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Enter activity description',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppTheme.space24),

                // Notes field
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Add any additional notes',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppTheme.space24),

                // Color selection
                _buildColorSelector(),
                const SizedBox(height: AppTheme.space48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(bool isDark) {
    return Wrap(
      spacing: AppTheme.space8,
      runSpacing: AppTheme.space8,
      children: ActivityType.values.map((type) {
        final isSelected = _selectedType == type;
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                type.icon,
                size: 18,
                color: isSelected ? Colors.white : type.defaultColor,
              ),
              const SizedBox(width: AppTheme.space4),
              Text(type.displayName),
            ],
          ),
          selected: isSelected,
          selectedColor: type.defaultColor,
          backgroundColor: isDark 
              ? (isSelected ? type.defaultColor : Colors.white.withOpacity(0.05))
              : type.defaultColor.withOpacity(0.1),
          labelStyle: TextStyle(
            color: isSelected 
                ? Colors.white 
                : (isDark ? Colors.white70 : AppTheme.textPrimary),
            fontWeight: isSelected ? FontWeight.w600 : null,
          ),
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedType = type;
                // Update color to match type if no custom color
                _selectedColor ??= '#${type.defaultColor.value.toRadixString(16).substring(2)}';
              });
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildDateTimeSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // All day toggle
        SwitchListTile(
          title: const Text('All day'),
          value: _isAllDay,
          onChanged: (value) {
            setState(() {
              _isAllDay = value;
              if (value && _startTime != null) {
                // Set to beginning and end of day
                _startTime = DateTime(_startTime!.year, _startTime!.month, _startTime!.day, 0, 0);
                _endTime = DateTime(_startTime!.year, _startTime!.month, _startTime!.day, 23, 59);
              }
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppTheme.space12),
        
        // Start date/time
        Row(
          children: [
            Expanded(
              child: _buildDateTimeField(
                label: 'Start',
                date: _startTime,
                onTapDate: () => _selectDate(true),
                onTapTime: _isAllDay ? null : () => _selectTime(true),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space16),
        
        // End date/time
        Row(
          children: [
            Expanded(
              child: _buildDateTimeField(
                label: 'End',
                date: _endTime,
                onTapDate: () => _selectDate(false),
                onTapTime: _isAllDay ? null : () => _selectTime(false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateTimeField({
    required String label,
    required DateTime? date,
    required VoidCallback onTapDate,
    VoidCallback? onTapTime,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.labelMedium.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onTapDate,
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.space12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.borderLight),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(width: AppTheme.space8),
                      Text(
                        date != null
                            ? DateFormat('MMM d, yyyy').format(date)
                            : 'Select date',
                        style: AppTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (onTapTime != null) ...[
              const SizedBox(width: AppTheme.space12),
              InkWell(
                onTap: onTapTime,
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.space12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.borderLight),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 20),
                      const SizedBox(width: AppTheme.space8),
                      Text(
                        date != null
                            ? DateFormat('h:mm a').format(date)
                            : 'Time',
                        style: AppTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSpaceSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderLight),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Space?>(
          value: _selectedSpace,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space12,
            vertical: AppTheme.space4,
          ),
          items: [
            const DropdownMenuItem<Space?>(
              value: null,
              child: Text('No space'),
            ),
            ..._spaces.map((space) => DropdownMenuItem(
              value: space,
              child: Row(
                children: [
                  if (space.color != null)
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: AppTheme.space12),
                      decoration: BoxDecoration(
                        color: _parseColor(space.color!).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  Text(space.name),
                ],
              ),
            )),
          ],
          onChanged: (space) {
            setState(() {
              _selectedSpace = space;
            });
          },
        ),
      ),
    );
  }

  Widget _buildRecurrenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Repeat',
          style: AppTheme.titleMedium.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.space12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderLight),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ActivityRecurrence>(
              value: _recurrence,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space12,
                vertical: AppTheme.space4,
              ),
              items: ActivityRecurrence.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getRecurrenceName(type)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _recurrence = value!;
                  if (value != ActivityRecurrence.weekly) {
                    _selectedWeekDays.clear();
                  }
                });
              },
            ),
          ),
        ),
        
        if (_recurrence == ActivityRecurrence.weekly) ...[
          const SizedBox(height: AppTheme.space16),
          Text(
            'Repeat on',
            style: AppTheme.labelMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          _buildWeekDaySelector(),
        ],
        
        if (_recurrence != ActivityRecurrence.once) ...[
          const SizedBox(height: AppTheme.space16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('End repeat'),
            subtitle: Text(
              _recurrenceEndDate != null
                  ? DateFormat('MMM d, yyyy').format(_recurrenceEndDate!)
                  : 'Never',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _selectRecurrenceEndDate,
          ),
        ],
      ],
    );
  }

  Widget _buildWeekDaySelector() {
    const weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (index) {
        final dayNumber = index + 1; // 1-7 for Mon-Sun
        final isSelected = _selectedWeekDays.contains(dayNumber);
        
        return InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedWeekDays.remove(dayNumber);
              } else {
                _selectedWeekDays.add(dayNumber);
              }
              _selectedWeekDays.sort();
            });
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary : AppTheme.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                weekDays[index],
                style: AppTheme.labelMedium.copyWith(
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildColorSelector() {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.brown,
      Colors.grey,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color',
          style: AppTheme.titleMedium.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.space12),
        Wrap(
          spacing: AppTheme.space8,
          runSpacing: AppTheme.space8,
          children: [
            // Default (activity type color)
            InkWell(
              onTap: () {
                setState(() {
                  _selectedColor = null;
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _selectedType.defaultColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _selectedColor == null ? AppTheme.primary : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: _selectedColor == null
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            ),
            // Custom colors
            ...colors.map((color) {
              final colorHex = '#${color.value.toRadixString(16).substring(2)}';
              final isSelected = _selectedColor == colorHex;
              
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedColor = colorHex;
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  String _getRecurrenceName(ActivityRecurrence type) {
    switch (type) {
      case ActivityRecurrence.once:
        return 'Does not repeat';
      case ActivityRecurrence.daily:
        return 'Daily';
      case ActivityRecurrence.weekly:
        return 'Weekly';
      case ActivityRecurrence.monthly:
        return 'Monthly';
    }
  }

  Color _parseColor(String colorString) {
    try {
      if (colorString.startsWith('#')) {
        // Format: #RRGGBB
        return Color(int.parse(colorString.replaceFirst('#', '0xff')));
      } else if (colorString.startsWith('0x') || colorString.startsWith('0X')) {
        // Format: 0xRRGGBB or 0xAARRGGBB
        return Color(int.parse(colorString));
      } else if (colorString.length == 6) {
        // Format: RRGGBB
        return Color(int.parse('0xff$colorString', radix: 16));
      } else if (colorString.length == 8 && colorString.toUpperCase().startsWith('FF')) {
        // Format: FFRRGGBB (opaque color)
        return Color(int.parse('0x$colorString', radix: 16));
      } else {
        // Try parsing as is
        return Color(int.parse('0xff$colorString', radix: 16));
      }
    } catch (e) {
      // Return a default color if parsing fails
      return AppTheme.primary;
    }
  }

  Widget _buildScheduleTypeOption({
    required ScheduleType type,
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _scheduleType = type;
          if (type == ScheduleType.prayerRelative && _selectedPrayer == null) {
            _selectedPrayer = PrayerName.fajr;
          }
        });
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primary : (isDark ? Colors.white54 : AppTheme.textSecondary),
              size: 24,
            ),
            const SizedBox(height: AppTheme.space4),
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: isSelected ? AppTheme.primary : (isDark ? Colors.white54 : AppTheme.textSecondary),
                fontWeight: isSelected ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerRelativeSection(bool isDark) {
    return Column(
      key: const ValueKey('prayer_relative'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prayer selection
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.transparent,
            ),
          ),
          child: DropdownButtonFormField<PrayerName>(
            decoration: InputDecoration(
              labelText: 'Select Prayer',
              prefixIcon: Icon(Icons.mosque, color: AppTheme.primary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: AppTheme.space12,
              ),
              labelStyle: TextStyle(
                color: isDark ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
            initialValue: _selectedPrayer,
            dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
            items: PrayerName.values.map((prayer) {
              final prayerStr = prayer.toString().split('.').last;
              final displayName = prayerStr.substring(0, 1).toUpperCase() + 
                                prayerStr.substring(1);
              final time = _prayerTimes[displayName] ?? '';
              return DropdownMenuItem(
                value: prayer,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(displayName),
                    if (time.isNotEmpty)
                      Text(
                        time,
                        style: AppTheme.labelSmall.copyWith(
                          color: AppTheme.primary,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPrayer = value;
              });
            },
          ),
        ),
        
        const SizedBox(height: AppTheme.space16),
        
        // Before/After toggle
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _isBeforePrayer = true),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.radiusMedium),
                    bottomLeft: Radius.circular(AppTheme.radiusMedium),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
                    decoration: BoxDecoration(
                      color: _isBeforePrayer
                          ? AppTheme.primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppTheme.radiusMedium),
                        bottomLeft: Radius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Before',
                        style: AppTheme.bodyMedium.copyWith(
                          color: _isBeforePrayer 
                              ? AppTheme.primary 
                              : (isDark ? Colors.white54 : AppTheme.textSecondary),
                          fontWeight: _isBeforePrayer ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _isBeforePrayer = false),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(AppTheme.radiusMedium),
                    bottomRight: Radius.circular(AppTheme.radiusMedium),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
                    decoration: BoxDecoration(
                      color: !_isBeforePrayer
                          ? AppTheme.primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(AppTheme.radiusMedium),
                        bottomRight: Radius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'After',
                        style: AppTheme.bodyMedium.copyWith(
                          color: !_isBeforePrayer 
                              ? AppTheme.primary 
                              : (isDark ? Colors.white54 : AppTheme.textSecondary),
                          fontWeight: !_isBeforePrayer ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: AppTheme.space16),
        
        // Minutes offset
        TextFormField(
          style: TextStyle(
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            labelText: 'Minutes',
            hintText: 'Enter minutes',
            helperText: 'Activity starts ${_isBeforePrayer ? "before" : "after"} ${_selectedPrayer != null ? _selectedPrayer.toString().split('.').last : "prayer"}',
            prefixIcon: Icon(Icons.timer_outlined, color: AppTheme.primary),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.transparent,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide(
                color: AppTheme.primary,
                width: 2,
              ),
            ),
            labelStyle: TextStyle(
              color: isDark ? Colors.white70 : AppTheme.textSecondary,
            ),
            hintStyle: TextStyle(
              color: isDark ? Colors.white38 : AppTheme.textTertiary,
            ),
            helperStyle: TextStyle(
              color: isDark ? Colors.white54 : AppTheme.textSecondary,
            ),
          ),
          keyboardType: TextInputType.number,
          initialValue: _minutesOffset.toString(),
          onChanged: (value) {
            final minutes = int.tryParse(value);
            if (minutes != null && minutes >= 0) {
              setState(() {
                _minutesOffset = minutes;
              });
            }
          },
        ),
        
        const SizedBox(height: AppTheme.space24),
        
        // Duration info
        Text(
          'Activity Duration',
          style: AppTheme.titleMedium.copyWith(
            color: isDark ? Colors.white70 : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.space12),
        TextFormField(
          style: TextStyle(
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            labelText: 'Duration (minutes)',
            hintText: 'How long will the activity last?',
            prefixIcon: Icon(Icons.hourglass_empty, color: AppTheme.primary),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.transparent,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide(
                color: AppTheme.primary,
                width: 2,
              ),
            ),
            labelStyle: TextStyle(
              color: isDark ? Colors.white70 : AppTheme.textSecondary,
            ),
            hintStyle: TextStyle(
              color: isDark ? Colors.white38 : AppTheme.textTertiary,
            ),
          ),
          keyboardType: TextInputType.number,
          initialValue: _endMinutesOffset.toString(),
          onChanged: (value) {
            final minutes = int.tryParse(value);
            if (minutes != null && minutes > 0) {
              setState(() {
                _endMinutesOffset = minutes;
              });
            }
          },
        ),
      ],
    );
  }
}