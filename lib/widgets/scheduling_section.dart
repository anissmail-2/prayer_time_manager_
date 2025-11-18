import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../core/services/prayer_time_service.dart';
import '../models/task.dart';

class SchedulingSection extends StatefulWidget {
  final bool isOptional;
  final bool initialHasSchedule;
  final DateTime? initialTaskDate;
  final bool includeRecurrence;
  final bool hideDatePicker; // Hide date picker when recurrence is included
  final bool showPrayerRelativeOptions; // Show prayer-relative scheduling options

  // Start time
  final ScheduleType initialStartScheduleType;
  final DateTime? initialStartTime;
  final PrayerName? initialStartPrayer;
  final bool initialStartIsBeforePrayer;
  final int initialStartMinutesOffset;

  // End time
  final ScheduleType initialEndScheduleType;
  final DateTime? initialEndTime;
  final PrayerName? initialEndPrayer;
  final bool initialEndIsBeforePrayer;
  final int initialEndMinutesOffset;

  // Recurrence
  final TaskRecurrence initialRecurrence;
  final List<int> initialWeeklyDays;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  final Map<String, String> prayerTimes;
  final Function(SchedulingData) onScheduleChanged;

  const SchedulingSection({
    super.key,
    this.isOptional = false,
    this.initialHasSchedule = true,
    this.initialTaskDate,
    this.includeRecurrence = false,
    this.hideDatePicker = false,
    this.showPrayerRelativeOptions = true,
    this.initialStartScheduleType = ScheduleType.absolute,
    this.initialStartTime,
    this.initialStartPrayer,
    this.initialStartIsBeforePrayer = true,
    this.initialStartMinutesOffset = 0,
    this.initialEndScheduleType = ScheduleType.absolute,
    this.initialEndTime,
    this.initialEndPrayer,
    this.initialEndIsBeforePrayer = false,
    this.initialEndMinutesOffset = 30,
    this.initialRecurrence = TaskRecurrence.once,
    this.initialWeeklyDays = const [],
    this.initialStartDate,
    this.initialEndDate,
    required this.prayerTimes,
    required this.onScheduleChanged,
  });

  @override
  State<SchedulingSection> createState() => _SchedulingSectionState();
}

class _SchedulingSectionState extends State<SchedulingSection> {
  late bool _hasSchedule;
  late DateTime? _taskDate;
  
  // Start time
  late ScheduleType _startScheduleType;
  late DateTime? _startTime;
  late PrayerName? _startPrayer;
  late bool _startIsBeforePrayer;
  late int _startMinutesOffset;
  
  // End time
  late ScheduleType _endScheduleType;
  late DateTime? _endTime;
  late PrayerName? _endPrayer;
  late bool _endIsBeforePrayer;
  late int _endMinutesOffset;
  
  // Recurrence
  late TaskRecurrence _recurrenceType;
  late List<int> _selectedWeekDays;
  late DateTime? _startDate;
  late DateTime? _endDate;
  
  @override
  void initState() {
    super.initState();
    _hasSchedule = widget.initialHasSchedule;
    _taskDate = widget.initialTaskDate ?? DateTime.now();
    
    _startScheduleType = widget.initialStartScheduleType;
    _startTime = widget.initialStartTime;
    _startPrayer = widget.initialStartPrayer;
    _startIsBeforePrayer = widget.initialStartIsBeforePrayer;
    _startMinutesOffset = widget.initialStartMinutesOffset;
    
    _endScheduleType = widget.initialEndScheduleType;
    _endTime = widget.initialEndTime;
    _endPrayer = widget.initialEndPrayer;
    _endIsBeforePrayer = widget.initialEndIsBeforePrayer;
    _endMinutesOffset = widget.initialEndMinutesOffset;
    
    _recurrenceType = widget.initialRecurrence;
    _selectedWeekDays = List.from(widget.initialWeeklyDays);
    _startDate = widget.initialStartDate ?? DateTime.now();
    _endDate = widget.initialEndDate;
  }
  
  void _updateParent() {
    widget.onScheduleChanged(SchedulingData(
      hasSchedule: _hasSchedule,
      taskDate: _taskDate,
      startScheduleType: _startScheduleType,
      startTime: _startTime,
      startPrayer: _startPrayer,
      startIsBeforePrayer: _startIsBeforePrayer,
      startMinutesOffset: _startMinutesOffset,
      endScheduleType: _endScheduleType,
      endTime: _endTime,
      endPrayer: _endPrayer,
      endIsBeforePrayer: _endIsBeforePrayer,
      endMinutesOffset: _endMinutesOffset,
      recurrence: _recurrenceType,
      weeklyDays: _selectedWeekDays,
      startDateRecurrence: _startDate,
      endDateRecurrence: _endDate,
    ));
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (widget.isOptional) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Schedule Toggle
          _buildSectionHeader('Schedule', Icons.schedule, 
            trailing: Switch(
              value: _hasSchedule,
              onChanged: (value) {
                setState(() {
                  _hasSchedule = value;
                  _updateParent();
                });
              },
              activeThumbColor: AppTheme.primary,
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _hasSchedule 
                ? _buildSchedulingContent(isDark)
                : const SizedBox.shrink(),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Time Schedule', Icons.schedule),
          const SizedBox(height: AppTheme.space16),
          _buildSchedulingContent(isDark),
        ],
      );
    }
  }
  
  Widget _buildSchedulingContent(bool isDark) {
    return Column(
      children: [
        // Start Time
        _buildTimeSection(
          context: context,
          isDark: isDark,
          title: 'Start Time',
          icon: Icons.play_arrow_rounded,
          scheduleType: _startScheduleType,
          onScheduleTypeChanged: (type) {
            setState(() {
              _startScheduleType = type;
              _updateParent();
            });
          },
          selectedTime: _startTime,
          onTimeSelected: (time) {
            setState(() {
              _startTime = time;
              _updateParent();
            });
          },
          selectedPrayer: _startPrayer,
          onPrayerSelected: (prayer) {
            setState(() {
              _startPrayer = prayer;
              _updateParent();
            });
          },
          isBeforePrayer: _startIsBeforePrayer,
          onBeforeAfterChanged: (isBefore) {
            setState(() {
              _startIsBeforePrayer = isBefore;
              _updateParent();
            });
          },
          minutesOffset: _startMinutesOffset,
          onMinutesChanged: (minutes) {
            setState(() {
              _startMinutesOffset = minutes;
              _updateParent();
            });
          },
          isStartTime: true,
        ),
        
        const SizedBox(height: AppTheme.space24),
        
        // End Time
        _buildTimeSection(
          context: context,
          isDark: isDark,
          title: 'End Time',
          icon: Icons.stop_rounded,
          scheduleType: _endScheduleType,
          onScheduleTypeChanged: (type) {
            setState(() {
              _endScheduleType = type;
              _updateParent();
            });
          },
          selectedTime: _endTime,
          onTimeSelected: (time) {
            setState(() {
              _endTime = time;
              _updateParent();
            });
          },
          selectedPrayer: _endPrayer,
          onPrayerSelected: (prayer) {
            setState(() {
              _endPrayer = prayer;
              _updateParent();
            });
          },
          isBeforePrayer: _endIsBeforePrayer,
          onBeforeAfterChanged: (isBefore) {
            setState(() {
              _endIsBeforePrayer = isBefore;
              _updateParent();
            });
          },
          minutesOffset: _endMinutesOffset,
          onMinutesChanged: (minutes) {
            setState(() {
              _endMinutesOffset = minutes;
              _updateParent();
            });
          },
          isStartTime: false,
        ),
        
        // Recurrence options (only show if included)
        if (widget.includeRecurrence) ...[
          const SizedBox(height: AppTheme.space24),
          _buildRecurrenceSection(isDark),
        ],
      ],
    );
  }
  
  Widget _buildDatePicker(bool isDark) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _taskDate ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
        );
        if (date != null) {
          setState(() {
            _taskDate = date;
            _updateParent();
          });
        }
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: AppTheme.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date',
                    style: AppTheme.labelMedium.copyWith(
                      color: isDark ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    _getDateDisplay(_taskDate ?? DateTime.now()),
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTimeSection({
    required BuildContext context,
    required bool isDark,
    required String title,
    required IconData icon,
    required ScheduleType scheduleType,
    required Function(ScheduleType) onScheduleTypeChanged,
    required DateTime? selectedTime,
    required Function(DateTime) onTimeSelected,
    required PrayerName? selectedPrayer,
    required Function(PrayerName) onPrayerSelected,
    required bool isBeforePrayer,
    required Function(bool) onBeforeAfterChanged,
    required int minutesOffset,
    required Function(int) onMinutesChanged,
    required bool isStartTime,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.transparent,
        ),
      ),
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.space8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Text(
                title,
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Schedule Type Toggle (only show if prayer relative options are enabled)
              if (widget.showPrayerRelativeOptions)
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.1) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMiniToggle(
                        icon: Icons.access_time,
                        isSelected: scheduleType == ScheduleType.absolute,
                        onTap: () => onScheduleTypeChanged(ScheduleType.absolute),
                        tooltip: 'Specific Time',
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                      ),
                      _buildMiniToggle(
                        icon: Icons.mosque,
                        isSelected: scheduleType == ScheduleType.prayerRelative,
                        onTap: () => onScheduleTypeChanged(ScheduleType.prayerRelative),
                        tooltip: 'Prayer Related',
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          
          // Time Content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: (!widget.showPrayerRelativeOptions || scheduleType == ScheduleType.absolute)
                ? _buildAbsoluteTimeContent(
                    context: context,
                    isDark: isDark,
                    selectedTime: selectedTime,
                    onTimeSelected: onTimeSelected,
                    isStartTime: isStartTime,
                  )
                : _buildPrayerRelativeContent(
                    context: context,
                    isDark: isDark,
                    selectedPrayer: selectedPrayer,
                    onPrayerSelected: onPrayerSelected,
                    isBeforePrayer: isBeforePrayer,
                    onBeforeAfterChanged: onBeforeAfterChanged,
                    minutesOffset: minutesOffset,
                    onMinutesChanged: onMinutesChanged,
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAbsoluteTimeContent({
    required BuildContext context,
    required bool isDark,
    required DateTime? selectedTime,
    required Function(DateTime) onTimeSelected,
    required bool isStartTime,
  }) {
    return InkWell(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: selectedTime != null 
              ? TimeOfDay.fromDateTime(selectedTime)
              : TimeOfDay.now(),
        );
        
        if (time != null && _taskDate != null) {
          onTimeSelected(DateTime(
            _taskDate!.year,
            _taskDate!.month,
            _taskDate!.day,
            time.hour,
            time.minute,
          ));
        }
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space16,
          vertical: AppTheme.space12,
        ),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time,
              color: AppTheme.primary,
              size: 20,
            ),
            const SizedBox(width: AppTheme.space12),
            Text(
              selectedTime != null
                  ? DateFormat('h:mm a').format(selectedTime)
                  : isStartTime ? 'Select start time' : 'Select end time',
              style: AppTheme.bodyLarge.copyWith(
                color: selectedTime != null 
                    ? (isDark ? Colors.white : Colors.black87)
                    : Colors.grey,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.edit,
              color: Colors.grey,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPrayerRelativeContent({
    required BuildContext context,
    required bool isDark,
    required PrayerName? selectedPrayer,
    required Function(PrayerName) onPrayerSelected,
    required bool isBeforePrayer,
    required Function(bool) onBeforeAfterChanged,
    required int minutesOffset,
    required Function(int) onMinutesChanged,
  }) {
    return Column(
      children: [
        // Prayer Selection
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: AppTheme.primary.withOpacity(0.3),
            ),
          ),
          child: DropdownButtonFormField<PrayerName>(
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.mosque, color: AppTheme.primary, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: 0,
              ),
            ),
            initialValue: selectedPrayer,
            hint: const Text('Select prayer'),
            dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
            items: PrayerName.values.map((prayer) {
              final prayerStr = prayer.toString().split('.').last;
              final displayName = prayerStr.substring(0, 1).toUpperCase() + 
                                prayerStr.substring(1);
              final time = widget.prayerTimes[displayName] ?? '';
              return DropdownMenuItem(
                value: prayer,
                child: Row(
                  children: [
                    Text(displayName),
                    const Spacer(),
                    if (time.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          time,
                          style: AppTheme.labelSmall.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) onPrayerSelected(value);
            },
          ),
        ),
        
        const SizedBox(height: AppTheme.space12),
        
        // Before/After and Minutes
        Row(
          children: [
            // Before/After Toggle
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppTheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildBeforeAfterOption(
                        context,
                        label: 'Before',
                        isSelected: isBeforePrayer,
                        onTap: () => onBeforeAfterChanged(true),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                    ),
                    Expanded(
                      child: _buildBeforeAfterOption(
                        context,
                        label: 'After',
                        isSelected: !isBeforePrayer,
                        onTap: () => onBeforeAfterChanged(false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            // Minutes Input
            Container(
              width: 100,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.3),
                ),
              ),
              child: TextFormField(
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: 'min',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space12,
                    vertical: AppTheme.space12,
                  ),
                ),
                keyboardType: TextInputType.number,
                initialValue: minutesOffset.toString(),
                onChanged: (value) {
                  final minutes = int.tryParse(value) ?? 0;
                  onMinutesChanged(minutes);
                },
              ),
            ),
          ],
        ),
        
        // Show calculated time
        if (selectedPrayer != null) ...[
          const SizedBox(height: AppTheme.space12),
          _buildCalculatedTimeDisplay(
            prayer: selectedPrayer,
            isBefore: isBeforePrayer,
            minutes: minutesOffset,
            label: 'Scheduled for',
            color: AppTheme.primary,
          ),
        ],
      ],
    );
  }
  
  Widget _buildCalculatedTimeDisplay({
    required PrayerName prayer,
    required bool isBefore,
    required int minutes,
    required String label,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prayerStr = prayer.toString().split('.').last;
    final displayName = prayerStr.substring(0, 1).toUpperCase() + prayerStr.substring(1);
    
    // Calculate the actual time
    // Use start date if available (from recurrence), otherwise use task date
    final baseDate = _startDate ?? _taskDate ?? DateTime.now();
    final calculatedTime = PrayerTimeService.calculatePrayerRelativeTime(
      prayerTimes: widget.prayerTimes,
      prayerName: displayName,
      isBefore: isBefore,
      minutesOffset: minutes,
      baseDate: baseDate,
    );
    
    if (calculatedTime == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            color: color,
            size: 18,
          ),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(
              '$label ${DateFormat('h:mm a').format(calculatedTime)} on ${_getDateDisplay(calculatedTime)}',
              style: AppTheme.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMiniToggle({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space12,
            vertical: AppTheme.space8,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected ? AppTheme.primary : Colors.grey,
          ),
        ),
      ),
    );
  }
  
  Widget _buildBeforeAfterOption(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primary.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Center(
          child: Text(
            label,
            style: AppTheme.labelLarge.copyWith(
              color: isSelected ? AppTheme.primary : (isDark ? Colors.white54 : Colors.grey[600]),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon, {Widget? trailing}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.space8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: AppTheme.space12),
        Text(
          title,
          style: AppTheme.titleLarge.copyWith(
            color: isDark ? Colors.white : AppTheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    );
  }
  
  String _getDateDisplay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    
    if (taskDate == today) {
      return 'Today';
    } else if (taskDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else if (taskDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('EEE, MMM d').format(date);
    }
  }
  
  Widget _buildRecurrenceSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Repeat', Icons.repeat),
        const SizedBox(height: AppTheme.space16),
        
        // Recurrence type selector
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          padding: const EdgeInsets.all(AppTheme.space4),
          child: Column(
            children: [
              // First row: Once, Daily, Weekly
              Row(
                children: [
                  Expanded(
                    child: _buildRecurrenceOption(
                      context,
                      type: TaskRecurrence.once,
                      isSelected: _recurrenceType == TaskRecurrence.once,
                    ),
                  ),
                  Expanded(
                    child: _buildRecurrenceOption(
                      context,
                      type: TaskRecurrence.daily,
                      isSelected: _recurrenceType == TaskRecurrence.daily,
                    ),
                  ),
                  Expanded(
                    child: _buildRecurrenceOption(
                      context,
                      type: TaskRecurrence.weekly,
                      isSelected: _recurrenceType == TaskRecurrence.weekly,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space4),
              // Second row: Monthly, Yearly
              Row(
                children: [
                  Expanded(
                    child: _buildRecurrenceOption(
                      context,
                      type: TaskRecurrence.monthly,
                      isSelected: _recurrenceType == TaskRecurrence.monthly,
                    ),
                  ),
                  Expanded(
                    child: _buildRecurrenceOption(
                      context,
                      type: TaskRecurrence.yearly,
                      isSelected: _recurrenceType == TaskRecurrence.yearly,
                    ),
                  ),
                  Expanded(
                    child: const SizedBox(), // Empty space for balance
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Show date picker for once or date range for recurring tasks
        if (_recurrenceType == TaskRecurrence.once) ...[
          const SizedBox(height: AppTheme.space16),
          _buildDatePicker(isDark),
        ] else ...[
          const SizedBox(height: AppTheme.space16),
          _buildDateRangeSection(isDark),
        ],
      ],
    );
  }
  
  Widget _buildRecurrenceOption(
    BuildContext context, {
    required TaskRecurrence type,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () {
        setState(() {
          _recurrenceType = type;
          _updateParent();
        });
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space12,
          vertical: AppTheme.space12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Center(
          child: Text(
            _getRecurrenceLabel(type),
            style: AppTheme.labelMedium.copyWith(
              color: isSelected ? AppTheme.primary : (isDark ? Colors.white70 : Colors.grey[700]),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
  
  String _getRecurrenceLabel(TaskRecurrence type) {
    switch (type) {
      case TaskRecurrence.once:
        return 'Once';
      case TaskRecurrence.daily:
        return 'Daily';
      case TaskRecurrence.weekly:
        return 'Weekly';
      case TaskRecurrence.monthly:
        return 'Monthly';
      case TaskRecurrence.yearly:
        return 'Yearly';
    }
  }
  
  Widget _buildDateRangeSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date Range',
          style: AppTheme.labelLarge.copyWith(
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        Row(
          children: [
            // Start Date
            Expanded(
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (date != null) {
                    setState(() {
                      _startDate = date;
                      _taskDate = date; // Update task date to start date
                      _updateParent();
                    });
                  }
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.space12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From',
                        style: AppTheme.labelSmall.copyWith(
                          color: isDark ? Colors.white54 : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        _startDate != null 
                            ? DateFormat('MMM d, yyyy').format(_startDate!)
                            : 'Today',
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            // End Date
            Expanded(
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: _startDate ?? DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (date != null) {
                    setState(() {
                      _endDate = date;
                      _updateParent();
                    });
                  }
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.space12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'To',
                        style: AppTheme.labelSmall.copyWith(
                          color: isDark ? Colors.white54 : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        _endDate != null 
                            ? DateFormat('MMM d, yyyy').format(_endDate!)
                            : 'No end date',
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Data class to pass scheduling information back to parent
class SchedulingData {
  final bool hasSchedule;
  final DateTime? taskDate;
  final ScheduleType startScheduleType;
  final DateTime? startTime;
  final PrayerName? startPrayer;
  final bool startIsBeforePrayer;
  final int startMinutesOffset;
  final ScheduleType endScheduleType;
  final DateTime? endTime;
  final PrayerName? endPrayer;
  final bool endIsBeforePrayer;
  final int endMinutesOffset;
  final TaskRecurrence recurrence;
  final List<int> weeklyDays;
  final DateTime? startDateRecurrence;
  final DateTime? endDateRecurrence;
  
  SchedulingData({
    required this.hasSchedule,
    this.taskDate,
    required this.startScheduleType,
    this.startTime,
    this.startPrayer,
    required this.startIsBeforePrayer,
    required this.startMinutesOffset,
    required this.endScheduleType,
    this.endTime,
    this.endPrayer,
    required this.endIsBeforePrayer,
    required this.endMinutesOffset,
    this.recurrence = TaskRecurrence.once,
    this.weeklyDays = const [],
    this.startDateRecurrence,
    this.endDateRecurrence,
  });
}