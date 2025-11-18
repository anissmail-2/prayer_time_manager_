import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/enhanced_task.dart';
import '../models/task.dart';
import '../core/services/prayer_time_service.dart';
import '../core/services/user_preferences_service.dart';
import 'scheduling_section.dart';

class EnhancedItemForm extends StatefulWidget {
  final String spaceId;
  final Function(EnhancedTask) onSubmit;
  final EnhancedTask? editingItem;

  const EnhancedItemForm({
    super.key,
    required this.spaceId,
    required this.onSubmit,
    this.editingItem,
  });

  @override
  State<EnhancedItemForm> createState() => _EnhancedItemFormState();
}

class _EnhancedItemFormState extends State<EnhancedItemForm> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Focus nodes
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();
  final _tagFocusNode = FocusNode();
  
  TaskPriority _priority = TaskPriority.medium;
  List<String> _tags = [];
  final _tagController = TextEditingController();
  
  // Scheduling fields
  bool _hasSchedule = false;
  DateTime? _taskDate = DateTime.now(); // Single date for the entire task, default to today
  
  // Start time fields
  ScheduleType _startScheduleType = ScheduleType.absolute;
  TimeOfDay? _startTime;
  PrayerName? _startPrayer;
  bool _startIsBeforePrayer = true;
  int _startMinutesOffset = 0;
  
  // End time fields  
  ScheduleType _endScheduleType = ScheduleType.absolute;
  TimeOfDay? _endTime;
  PrayerName? _endPrayer;
  bool _endIsBeforePrayer = false;
  int _endMinutesOffset = 0;
  
  // Recurrence
  TaskRecurrence _recurrenceType = TaskRecurrence.once;
  List<int> _selectedWeekDays = [];
  DateTime? _startDate; // Start date for recurring tasks
  DateTime? _endDate;
  
  // Advanced recurrence options
  int _weeklyInterval = 1; // Every X weeks
  List<int> _monthlyDates = []; // Specific dates in month
  String? _monthlyPattern; // "first_monday", etc.
  
  Map<String, dynamic>? _prayerTimes;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Error message state
  String? _errorMessage;

  // Prayer mode state
  bool _isPrayerModeEnabled = true;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _loadPrayerTimes();
    _loadPrayerMode();

    if (widget.editingItem != null) {
      _loadExistingItem(widget.editingItem!);
    }

    _animationController.forward();
  }

  Future<void> _loadPrayerMode() async {
    final enabled = await UserPreferencesService.isPrayerModeEnabled();
    if (mounted) {
      setState(() {
        _isPrayerModeEnabled = enabled;
      });
    }
  }

  void _loadExistingItem(EnhancedTask item) {
    _titleController.text = item.title;
    _descriptionController.text = item.description ?? '';
    _notesController.text = item.notes ?? '';
    _priority = item.priority;
    _tags = List.from(item.tags);
    _recurrenceType = item.recurrence;
    _selectedWeekDays = List.from(item.weeklyDays ?? []);
    _startDate = item.startDate;
    _endDate = item.endDate;
    _weeklyInterval = item.weeklyInterval ?? 1;
    _monthlyDates = List.from(item.monthlyDates ?? []);
    _monthlyPattern = item.monthlyPattern;
    
    if (item.isScheduled) {
      _hasSchedule = true;
      
      // Determine start schedule type
      if (item.relatedPrayer != null) {
        _startScheduleType = ScheduleType.prayerRelative;
        _startPrayer = item.relatedPrayer;
        _startIsBeforePrayer = item.isBeforePrayer ?? true;
        _startMinutesOffset = item.minutesOffset ?? 0;
      } else if (item.absoluteTime != null) {
        _startScheduleType = ScheduleType.absolute;
        _taskDate = DateTime(item.absoluteTime!.year, item.absoluteTime!.month, item.absoluteTime!.day);
        _startTime = TimeOfDay.fromDateTime(item.absoluteTime!);
      }
      
      // Determine end schedule type
      if (item.endRelatedPrayer != null) {
        _endScheduleType = ScheduleType.prayerRelative;
        _endPrayer = item.endRelatedPrayer;
        _endIsBeforePrayer = item.endIsBeforePrayer ?? false;
        _endMinutesOffset = item.endMinutesOffset ?? 0;
      } else if (item.endTime != null) {
        _endScheduleType = ScheduleType.absolute;
        _endTime = TimeOfDay.fromDateTime(item.endTime!);
      }
    }
  }

  Future<void> _loadPrayerTimes() async {
    final times = await PrayerTimeService.getTodayPrayerTimes();
    if (mounted) {
      setState(() {
        _prayerTimes = times['timings'];
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _tagController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _notesFocusNode.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }
  
  void _clearAllFocus() {
    // Unfocus all text fields
    _titleFocusNode.unfocus();
    _descriptionFocusNode.unfocus();
    _notesFocusNode.unfocus();
    _tagFocusNode.unfocus();
    
    // Also unfocus any other field that might have focus
    FocusScope.of(context).unfocus();
    
    // Request focus on a non-existent node to ensure no field gets focus
    FocusScope.of(context).requestFocus(FocusNode());
  }
  
  Map<String, String> _convertPrayerTimes() {
    final converted = <String, String>{};
    if (_prayerTimes != null) {
      _prayerTimes!.forEach((key, value) {
        converted[key] = value.toString();
      });
    }
    return converted;
  }

  bool _validateTimeBlock() {
    setState(() {
      _errorMessage = null;
    });
    
    if (!_hasSchedule) return true;
    
    if (_startScheduleType == ScheduleType.absolute || _endScheduleType == ScheduleType.absolute) {
      // Both times must be set for absolute scheduling
      if (_startTime == null || _endTime == null) {
        setState(() {
          _errorMessage = 'Please set both start and end times';
        });
        return false;
      }
      
      // Default to today if no date selected
      _taskDate ??= DateTime.now();
      
      // End time must be after start time
      final start = DateTime(_taskDate!.year, _taskDate!.month, _taskDate!.day,
          _startTime!.hour, _startTime!.minute);
      final end = DateTime(_taskDate!.year, _taskDate!.month, _taskDate!.day,
          _endTime!.hour, _endTime!.minute);
      
      if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
        setState(() {
          _errorMessage = 'End time must be after start time';
        });
        return false;
      }
    } else {
      // Prayer-relative scheduling requires at least start prayer
      if (_startPrayer == null) {
        setState(() {
          _errorMessage = 'Please select a prayer for the start time';
        });
        return false;
      }
    }
    
    // Validate weekly recurrence
    if (_recurrenceType == TaskRecurrence.weekly && _selectedWeekDays.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one day for weekly recurrence';
      });
      return false;
    }
    
    return true;
  }

  void _submit() {
    if (_formKey.currentState!.validate() && _validateTimeBlock()) {
      DateTime? absoluteStartTime;
      DateTime? absoluteEndTime;
      
      if (_hasSchedule && _taskDate != null) {
        if (_startScheduleType == ScheduleType.absolute && _startTime != null) {
          absoluteStartTime = DateTime(
            _taskDate!.year, _taskDate!.month, _taskDate!.day,
            _startTime!.hour, _startTime!.minute,
          );
        }
        if (_endScheduleType == ScheduleType.absolute && _endTime != null) {
          absoluteEndTime = DateTime(
            _taskDate!.year, _taskDate!.month, _taskDate!.day,
            _endTime!.hour, _endTime!.minute,
          );
        }
      }
      
      final item = EnhancedTask(
        id: widget.editingItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        createdAt: widget.editingItem?.createdAt ?? DateTime.now(),
        priority: _priority,
        tags: _tags,
        spaceId: widget.spaceId,
        status: widget.editingItem?.status ?? TaskStatus.todo,
        scheduleType: _hasSchedule ? _startScheduleType : ScheduleType.absolute,
        absoluteTime: absoluteStartTime,
        endTime: absoluteEndTime,
        relatedPrayer: _hasSchedule && _startScheduleType == ScheduleType.prayerRelative ? _startPrayer : null,
        isBeforePrayer: _hasSchedule && _startScheduleType == ScheduleType.prayerRelative ? _startIsBeforePrayer : null,
        minutesOffset: _hasSchedule && _startScheduleType == ScheduleType.prayerRelative ? _startMinutesOffset : null,
        endRelatedPrayer: _hasSchedule && _endScheduleType == ScheduleType.prayerRelative ? _endPrayer : null,
        endIsBeforePrayer: _hasSchedule && _endScheduleType == ScheduleType.prayerRelative ? _endIsBeforePrayer : null,
        endMinutesOffset: _hasSchedule && _endScheduleType == ScheduleType.prayerRelative ? _endMinutesOffset : null,
        recurrence: _hasSchedule ? _recurrenceType : TaskRecurrence.once,
        weeklyDays: _hasSchedule && _recurrenceType == TaskRecurrence.weekly ? _selectedWeekDays : null,
        startDate: _hasSchedule ? _startDate : null,
        endDate: _hasSchedule ? _endDate : null,
        weeklyInterval: _hasSchedule && _recurrenceType == TaskRecurrence.weekly ? _weeklyInterval : null,
        monthlyDates: _hasSchedule && _recurrenceType == TaskRecurrence.monthly ? _monthlyDates : null,
        monthlyPattern: _hasSchedule ? _monthlyPattern : null,
        attachments: widget.editingItem?.attachments ?? [],
        customFields: widget.editingItem?.customFields,
      );
      
      widget.onSubmit(item);
    }
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

  Widget _buildSectionHeader(String title, IconData icon) {
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
      ],
    );
  }
  
  Widget _buildPriorityOption(
    BuildContext context, {
    required TaskPriority priority,
    required String label,
    required Color color,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () => setState(() => _priority = priority),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space16),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Center(
          child: Text(
            label,
            style: AppTheme.labelLarge.copyWith(
              color: isSelected ? color : (isDark ? Colors.white54 : Colors.grey[600]),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildScheduleTypeOption(
    BuildContext context, {
    required ScheduleType type,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () => setState(() => _startScheduleType = type),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space16),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primary.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primary : (isDark ? Colors.white54 : Colors.grey),
              size: 24,
            ),
            const SizedBox(height: AppTheme.space4),
            Text(
              label,
              style: AppTheme.labelMedium.copyWith(
                color: isSelected ? AppTheme.primary : (isDark ? Colors.white54 : Colors.grey[600]),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCalculatedTimeDisplay({
    required PrayerName prayer,
    required bool isBefore,
    required int minutes,
    required Map<String, dynamic> prayerTimes,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prayerStr = prayer.toString().split('.').last;
    final displayName = prayerStr.substring(0, 1).toUpperCase() + prayerStr.substring(1);
    
    // Convert prayer times to the expected format
    final convertedTimes = <String, String>{};
    prayerTimes.forEach((key, value) {
      convertedTimes[key] = value.toString();
    });
    
    // Calculate the actual time
    final calculatedTime = PrayerTimeService.calculatePrayerRelativeTime(
      prayerTimes: convertedTimes,
      prayerName: displayName,
      isBefore: isBefore,
      minutesOffset: minutes,
      baseDate: _taskDate,
    );
    
    if (calculatedTime == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            color: AppTheme.primary,
            size: 18,
          ),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(
              'Scheduled for ${DateFormat('h:mm a').format(calculatedTime)} on ${_getDateDisplay(calculatedTime)}',
              style: AppTheme.labelMedium.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
  
  Widget _buildRecurrenceOption(
    BuildContext context, {
    required TaskRecurrence type,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = type.toString().split('.').last.toUpperCase();
    
    return InkWell(
      onTap: () => setState(() => _recurrenceType = type),
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTheme.labelMedium.copyWith(
              color: isSelected ? AppTheme.primary : (isDark ? Colors.white54 : Colors.grey[600]),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildDayChip(
    BuildContext context,
    String shortName,
    String fullName,
    int day,
    bool isSelected,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Tooltip(
      message: fullName,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedWeekDays.remove(day);
            } else {
              _selectedWeekDays.add(day);
            }
          });
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isSelected 
                ? AppTheme.primary
                : isDark ? Colors.white.withOpacity(0.05) : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: isSelected 
                  ? AppTheme.primary
                  : isDark ? Colors.white.withOpacity(0.1) : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              shortName,
              style: AppTheme.labelLarge.copyWith(
                color: isSelected 
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey[700]),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: () {
          // Clear focus when tapping outside of text fields
          _clearAllFocus();
        },
        behavior: HitTestBehavior.opaque,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Task Details Section
            _buildSectionHeader('Task Details', Icons.edit_note),
            const SizedBox(height: AppTheme.space16),
            
            // Title field (required)
            TextFormField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              style: AppTheme.bodyLarge,
              decoration: InputDecoration(
                labelText: 'Task Title',
                hintText: 'Enter task title',
                prefixIcon: Icon(Icons.task_alt, color: AppTheme.primary),
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
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(
                    color: AppTheme.error,
                    width: 2,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
              autofocus: widget.editingItem == null,
            ),
            const SizedBox(height: AppTheme.space16),
          
            // Description field (optional)
            TextFormField(
              controller: _descriptionController,
              focusNode: _descriptionFocusNode,
              style: AppTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Add more details about this task',
                prefixIcon: Icon(Icons.description_outlined, color: AppTheme.primary),
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
              ),
              maxLines: 3,
            ),
            const SizedBox(height: AppTheme.space24),
          
            // Priority Section
            _buildSectionHeader('Priority', Icons.flag),
            const SizedBox(height: AppTheme.space16),
            
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildPriorityOption(
                      context,
                      priority: TaskPriority.low,
                      label: 'LOW',
                      color: AppTheme.success,
                      isSelected: _priority == TaskPriority.low,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                  ),
                  Expanded(
                    child: _buildPriorityOption(
                      context,
                      priority: TaskPriority.medium,
                      label: 'MEDIUM',
                      color: AppTheme.warning,
                      isSelected: _priority == TaskPriority.medium,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                  ),
                  Expanded(
                    child: _buildPriorityOption(
                      context,
                      priority: TaskPriority.high,
                      label: 'HIGH',
                      color: AppTheme.error,
                      isSelected: _priority == TaskPriority.high,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space24),
          
            // Tags Section
            _buildSectionHeader('Tags', Icons.label),
            const SizedBox(height: AppTheme.space16),
            
            TextField(
              controller: _tagController,
              focusNode: _tagFocusNode,
              style: AppTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: 'Add Tags',
                hintText: 'Type tag and press enter',
                prefixIcon: Icon(Icons.label_outline, color: AppTheme.primary),
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
                suffixIcon: IconButton(
                  icon: Icon(Icons.add_circle, color: AppTheme.primary),
                  onPressed: _addTag,
                ),
              ),
              onSubmitted: (_) => _addTag(),
            ),
            if (_tags.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space8),
              Wrap(
                spacing: AppTheme.space8,
                runSpacing: AppTheme.space8,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text(
                      tag,
                      style: AppTheme.labelMedium,
                    ),
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    deleteIcon: Icon(
                      Icons.close,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    onDeleted: () => _removeTag(tag),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: AppTheme.space24),
            
            // Schedule Section using shared widget
            SchedulingSection(
              isOptional: true, // Optional for Space
              includeRecurrence: true, // Include recurrence in schedule
              hideDatePicker: true, // Hide date picker since recurrence handles dates
              showPrayerRelativeOptions: _isPrayerModeEnabled, // Show prayer options based on mode
              initialHasSchedule: _hasSchedule,
              initialTaskDate: _taskDate,
              initialStartScheduleType: _startScheduleType,
              initialStartTime: _startTime != null && _taskDate != null
                  ? DateTime(_taskDate!.year, _taskDate!.month, _taskDate!.day, _startTime!.hour, _startTime!.minute)
                  : null,
              initialStartPrayer: _startPrayer,
              initialStartIsBeforePrayer: _startIsBeforePrayer,
              initialStartMinutesOffset: _startMinutesOffset,
              initialEndScheduleType: _endScheduleType,
              initialEndTime: _endTime != null && _taskDate != null
                  ? DateTime(_taskDate!.year, _taskDate!.month, _taskDate!.day, _endTime!.hour, _endTime!.minute)
                  : null,
              initialEndPrayer: _endPrayer,
              initialEndIsBeforePrayer: _endIsBeforePrayer,
              initialEndMinutesOffset: _endMinutesOffset,
              initialRecurrence: _recurrenceType,
              initialWeeklyDays: _selectedWeekDays,
              initialStartDate: _startDate,
              initialEndDate: _endDate,
              prayerTimes: _convertPrayerTimes(),
              onScheduleChanged: (data) {
                setState(() {
                  _hasSchedule = data.hasSchedule;
                  _taskDate = data.taskDate;
                  _startScheduleType = data.startScheduleType;
                  _startTime = data.startTime != null ? TimeOfDay.fromDateTime(data.startTime!) : null;
                  _startPrayer = data.startPrayer;
                  _startIsBeforePrayer = data.startIsBeforePrayer;
                  _startMinutesOffset = data.startMinutesOffset;
                  _endScheduleType = data.endScheduleType;
                  _endTime = data.endTime != null ? TimeOfDay.fromDateTime(data.endTime!) : null;
                  _endPrayer = data.endPrayer;
                  _endIsBeforePrayer = data.endIsBeforePrayer;
                  _endMinutesOffset = data.endMinutesOffset;
                  _recurrenceType = data.recurrence;
                  _selectedWeekDays = data.weeklyDays;
                  _startDate = data.startDateRecurrence;
                  _endDate = data.endDateRecurrence;
                });
              },
            ),
          
            
            const SizedBox(height: AppTheme.space24),
            
            // Notes Section
            _buildSectionHeader('Notes', Icons.note),
            const SizedBox(height: AppTheme.space16),
            
            TextFormField(
              controller: _notesController,
              focusNode: _notesFocusNode,
              style: AppTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: 'Additional Notes',
                hintText: 'Add any extra details or reminders',
                prefixIcon: Icon(Icons.note_alt_outlined, color: AppTheme.primary),
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
              ),
              maxLines: 4,
              minLines: 3,
            ),
            
            const SizedBox(height: AppTheme.space24),
            
            // Error message display
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: AppTheme.space16),
                padding: const EdgeInsets.all(AppTheme.space12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppTheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.space8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Submit button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  widget.editingItem != null ? 'Update Task' : 'Create Task',
                  style: AppTheme.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: AppTheme.space16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAbsoluteTimeSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      key: const ValueKey('absolute'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Picker
        InkWell(
          onTap: () async {
            // Clear all focus before showing date picker
            _clearAllFocus();
            await Future.delayed(const Duration(milliseconds: 150));
            
            // Default to today if no date is set
            final currentDate = _taskDate ?? DateTime.now();
            final date = await showDatePicker(
              context: context,
              initialDate: currentDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
            );
            if (date != null && mounted) {
              setState(() {
                _taskDate = date;
              });
              // Ensure focus doesn't return
              _clearAllFocus();
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
                        _taskDate != null
                            ? _getDateDisplay(_taskDate!)
                            : 'Today',
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
        ),
        
        const SizedBox(height: AppTheme.space16),
        
        // Start Time
        InkWell(
          onTap: () async {
            // Clear all focus before showing time picker
            _clearAllFocus();
            await Future.delayed(const Duration(milliseconds: 150));
            
            final time = await showTimePicker(
              context: context,
              initialTime: _startTime ?? TimeOfDay.now(),
            );
            if (time != null && mounted) {
              setState(() {
                _startTime = time;
              });
              // Ensure focus doesn't return
              _clearAllFocus();
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
                    Icons.access_time,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: AppTheme.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Start Time',
                            style: AppTheme.labelMedium.copyWith(
                              color: isDark ? Colors.white70 : Colors.grey[700],
                            ),
                          ),
                          Text(
                            ' *',
                            style: AppTheme.labelMedium.copyWith(
                              color: AppTheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        _startTime != null
                            ? _startTime!.format(context)
                            : 'Select start time',
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
        ),
        
        const SizedBox(height: AppTheme.space16),
        
        // End Time
        InkWell(
          onTap: () async {
            // Clear all focus before showing time picker
            _clearAllFocus();
            await Future.delayed(const Duration(milliseconds: 150));
            
            final time = await showTimePicker(
              context: context,
              initialTime: _endTime ?? TimeOfDay.now(),
            );
            if (time != null && mounted) {
              setState(() {
                _endTime = time;
              });
              // Ensure focus doesn't return
              _clearAllFocus();
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
                    color: AppTheme.secondary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.access_time_filled,
                    color: AppTheme.secondary,
                  ),
                ),
                const SizedBox(width: AppTheme.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'End Time',
                            style: AppTheme.labelMedium.copyWith(
                              color: isDark ? Colors.white70 : Colors.grey[700],
                            ),
                          ),
                          Text(
                            ' *',
                            style: AppTheme.labelMedium.copyWith(
                              color: AppTheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        _endTime != null
                            ? _endTime!.format(context)
                            : 'Select end time',
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _endTime != null 
                              ? null 
                              : AppTheme.error,
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
        ),
      ],
    );
  }

  Widget _buildPrayerRelativeSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      key: const ValueKey('prayer'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        // Start Time Section
        _buildSectionHeader('Start Time', Icons.access_time),
        const SizedBox(height: AppTheme.space16),
        
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
              labelText: 'Select Prayer *',
              prefixIcon: Icon(Icons.mosque, color: AppTheme.primary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: AppTheme.space12,
              ),
            ),
            initialValue: _startPrayer,
            dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
            items: PrayerName.values.where((p) => p != PrayerName.sunrise).map((prayer) {
              final prayerKey = prayer.toString().split('.').last;
              final displayName = prayerKey.substring(0, 1).toUpperCase() + prayerKey.substring(1);
              final apiKey = displayName;
              final timeStr = _prayerTimes != null && _prayerTimes![apiKey] != null
                  ? ' (${_prayerTimes![apiKey]})'
                  : '';
              return DropdownMenuItem(
                value: prayer,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(displayName),
                    Text(
                      timeStr,
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _startPrayer = value),
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
                child: _buildBeforeAfterOption(
                  context,
                  label: 'Before',
                  isSelected: _startIsBeforePrayer,
                  onTap: () => setState(() => _startIsBeforePrayer = true),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
              ),
              Expanded(
                child: _buildBeforeAfterOption(
                  context,
                  label: 'After',
                  isSelected: !_startIsBeforePrayer,
                  onTap: () => setState(() => _startIsBeforePrayer = false),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: AppTheme.space16),
        
        // Minutes offset
        TextFormField(
          decoration: InputDecoration(
            labelText: 'Minutes',
            hintText: 'Enter minutes',
            helperText: 'How many minutes ${_startIsBeforePrayer ? "before" : "after"} the prayer',
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
          ),
          keyboardType: TextInputType.number,
          initialValue: _startMinutesOffset.toString(),
          onChanged: (value) {
            final minutes = int.tryParse(value) ?? 0;
            setState(() => _startMinutesOffset = minutes);
          },
        ),
        
        const SizedBox(height: AppTheme.space24),
        
        // End Time Section
        _buildSectionHeader('End Time (Optional)', Icons.access_time_filled),
        const SizedBox(height: AppTheme.space16),
        
        // End Prayer selection
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.transparent,
            ),
          ),
          child: DropdownButtonFormField<PrayerName?>(
            decoration: InputDecoration(
              labelText: 'Select End Prayer (optional)',
              prefixIcon: Icon(Icons.mosque, color: AppTheme.secondary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: AppTheme.space12,
              ),
            ),
            initialValue: _endPrayer,
            dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('No end time'),
              ),
              ...PrayerName.values.where((p) => p != PrayerName.sunrise).map((prayer) {
                final prayerKey = prayer.toString().split('.').last;
                final displayName = prayerKey.substring(0, 1).toUpperCase() + prayerKey.substring(1);
                final apiKey = displayName;
                final timeStr = _prayerTimes != null && _prayerTimes![apiKey] != null
                    ? ' (${_prayerTimes![apiKey]})'
                    : '';
                return DropdownMenuItem(
                  value: prayer,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(displayName),
                      Text(
                        timeStr,
                        style: AppTheme.labelSmall.copyWith(
                          color: AppTheme.secondary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            onChanged: (value) => setState(() => _endPrayer = value),
          ),
        ),
        
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: _endPrayer != null
              ? Column(
                  children: [
                    const SizedBox(height: AppTheme.space16),
                    
                    // End Before/After toggle
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildBeforeAfterOption(
                              context,
                              label: 'Before',
                              isSelected: _endIsBeforePrayer,
                              onTap: () => setState(() => _endIsBeforePrayer = true),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                          ),
                          Expanded(
                            child: _buildBeforeAfterOption(
                              context,
                              label: 'After',
                              isSelected: !_endIsBeforePrayer,
                              onTap: () => setState(() => _endIsBeforePrayer = false),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.space16),
                    
                    // End Minutes offset
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'End Minutes',
                        hintText: 'Enter minutes',
                        helperText: 'How many minutes ${_endIsBeforePrayer ? "before" : "after"} the prayer to end',
                        prefixIcon: Icon(Icons.timer_off_outlined, color: AppTheme.secondary),
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
                            color: AppTheme.secondary,
                            width: 2,
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: _endMinutesOffset.toString(),
                      onChanged: (value) {
                        final minutes = int.tryParse(value) ?? 0;
                        setState(() => _endMinutesOffset = minutes);
                      },
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildTimeSection({
    required BuildContext context,
    required bool isDark,
    required String title,
    required IconData icon,
    required ScheduleType scheduleType,
    required Function(ScheduleType) onScheduleTypeChanged,
    required TimeOfDay? selectedTime,
    required Function(TimeOfDay) onTimeSelected,
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
              // Schedule Type Toggle
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
            child: scheduleType == ScheduleType.absolute
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

  Widget _buildAbsoluteTimeContent({
    required BuildContext context,
    required bool isDark,
    required TimeOfDay? selectedTime,
    required Function(TimeOfDay) onTimeSelected,
    required bool isStartTime,
  }) {
    return InkWell(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: selectedTime ?? TimeOfDay.now(),
        );
        
        if (time != null) {
          onTimeSelected(time);
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
                  ? selectedTime.format(context)
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
              final time = _prayerTimes?[displayName] ?? '';
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
        if (selectedPrayer != null && _prayerTimes != null) ...[
          const SizedBox(height: AppTheme.space12),
          _buildCalculatedTimeDisplay(
            prayer: selectedPrayer,
            isBefore: isBeforePrayer,
            minutes: minutesOffset,
            prayerTimes: _prayerTimes!,
          ),
        ],
      ],
    );
  }

  Future<void> _selectStartDate() async {
    _clearAllFocus();
    await Future.delayed(const Duration(milliseconds: 150));
    
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null && mounted) {
      setState(() {
        _startDate = date;
        // If task date is not set, use start date as the task date
        _taskDate ??= date;
      });
      _clearAllFocus();
    }
  }

  Future<void> _selectEndDate() async {
    _clearAllFocus();
    await Future.delayed(const Duration(milliseconds: 150));
    
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null && mounted) {
      setState(() {
        _endDate = date;
      });
      _clearAllFocus();
    }
  }

  Widget _buildRecurrenceDetails(BuildContext context, bool isDark) {
    if (_recurrenceType == TaskRecurrence.once) {
      // For "Once" - show task date with calendar picker
      return Column(
        children: [
          const SizedBox(height: AppTheme.space16),
          Text(
            'Task Date',
            style: AppTheme.labelLarge.copyWith(
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          InkWell(
            onTap: () async {
              _clearAllFocus();
              await Future.delayed(const Duration(milliseconds: 150));
              
              final date = await showDatePicker(
                context: context,
                initialDate: _taskDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              
              if (date != null && mounted) {
                setState(() {
                  _taskDate = date;
                  // Update start date to match task date for "once" tasks
                  _startDate = date;
                });
                _clearAllFocus();
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
                  Icon(
                    Icons.calendar_today,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: AppTheme.space16),
                  Expanded(
                    child: Text(
                      _taskDate != null
                          ? DateFormat('EEEE, MMMM d, yyyy').format(_taskDate!)
                          : 'Today - ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
                      style: AppTheme.bodyLarge,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // For recurring tasks
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTheme.space24),
        
        // Start Date
        Text(
          'Start Date',
          style: AppTheme.labelLarge.copyWith(
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        InkWell(
          onTap: _selectStartDate,
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
                Icon(
                  Icons.calendar_today,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: AppTheme.space16),
                Expanded(
                  child: Text(
                    _startDate != null
                        ? DateFormat('EEEE, MMMM d, yyyy').format(_startDate!)
                        : 'Today - ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
                    style: AppTheme.bodyLarge,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        
        // Weekly options
        if (_recurrenceType == TaskRecurrence.weekly) ...[
          const SizedBox(height: AppTheme.space24),
          Text(
            'Repeat Every',
            style: AppTheme.labelLarge.copyWith(
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              Container(
                width: 80,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.transparent,
                  ),
                ),
                child: DropdownButtonFormField<int>(
                  initialValue: _weeklyInterval,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.space12),
                  ),
                  items: List.generate(4, (index) => index + 1)
                      .map((weeks) => DropdownMenuItem(
                            value: weeks,
                            child: Text(weeks.toString()),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _weeklyInterval = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Text(
                _weeklyInterval == 1 ? 'week' : 'weeks',
                style: AppTheme.bodyLarge,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          Text(
            'On Days',
            style: AppTheme.labelLarge.copyWith(
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          Row(
            children: List.generate(7, (index) {
              final day = index + 1;
              const dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              const fullDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
                  child: _buildDayChip(
                    context,
                    dayNames[index],
                    fullDayNames[index],
                    day,
                    _selectedWeekDays.contains(day),
                  ),
                ),
              );
            }),
          ),
        ],
        
        // Monthly options
        if (_recurrenceType == TaskRecurrence.monthly) ...[
          const SizedBox(height: AppTheme.space24),
          Text(
            'Select Days of Month',
            style: AppTheme.labelLarge.copyWith(
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          // Monthly day selection grid
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.transparent,
              ),
            ),
            padding: const EdgeInsets.all(AppTheme.space12),
            child: Column(
              children: [
                // Days 1-7
                Row(
                  children: List.generate(7, (index) {
                    final day = index + 1;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: _buildMonthDayChip(context, day),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: AppTheme.space4),
                // Days 8-14
                Row(
                  children: List.generate(7, (index) {
                    final day = index + 8;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: _buildMonthDayChip(context, day),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: AppTheme.space4),
                // Days 15-21
                Row(
                  children: List.generate(7, (index) {
                    final day = index + 15;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: _buildMonthDayChip(context, day),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: AppTheme.space4),
                // Days 22-28
                Row(
                  children: List.generate(7, (index) {
                    final day = index + 22;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: _buildMonthDayChip(context, day),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: AppTheme.space4),
                // Days 29-31 and Last Day option
                Row(
                  children: [
                    ...List.generate(3, (index) {
                      final day = index + 29;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: day <= 31 ? _buildMonthDayChip(context, day) : const SizedBox(),
                        ),
                      );
                    }),
                    const Spacer(flex: 4),
                  ],
                ),
              ],
            ),
          ),
        ],
        
        // End Date (for all recurring)
        const SizedBox(height: AppTheme.space24),
        Text(
          'End Date',
          style: AppTheme.labelLarge.copyWith(
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        InkWell(
          onTap: _selectEndDate,
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
                Icon(
                  Icons.event_busy,
                  color: _endDate != null ? AppTheme.primary : Colors.grey,
                ),
                const SizedBox(width: AppTheme.space16),
                Expanded(
                  child: Text(
                    _endDate != null
                        ? DateFormat('EEEE, MMMM d, yyyy').format(_endDate!)
                        : 'No end date',
                    style: AppTheme.bodyLarge.copyWith(
                      color: _endDate != null ? null : Colors.grey,
                    ),
                  ),
                ),
                if (_endDate != null)
                  IconButton(
                    icon: Icon(Icons.clear, color: AppTheme.error),
                    onPressed: () => setState(() => _endDate = null),
                  )
                else
                  Icon(
                    Icons.arrow_drop_down,
                    color: Colors.grey,
                  ),
              ],
            ),
          ),
        ),
        
        // Recurrence Summary
        const SizedBox(height: AppTheme.space16),
        Container(
          padding: const EdgeInsets.all(AppTheme.space12),
          decoration: BoxDecoration(
            color: AppTheme.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.info,
                size: 20,
              ),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: Text(
                  _getRecurrenceSummary(),
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.info,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getRecurrenceSummary() {
    String summary = 'Repeats ';
    
    switch (_recurrenceType) {
      case TaskRecurrence.daily:
        summary += 'every day';
        break;
      case TaskRecurrence.weekly:
        if (_weeklyInterval > 1) {
          summary += 'every $_weeklyInterval weeks';
        } else {
          summary += 'every week';
        }
        if (_selectedWeekDays.isNotEmpty) {
          const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          final days = _selectedWeekDays.map((d) => dayNames[d - 1]).join(', ');
          summary += ' on $days';
        }
        break;
      case TaskRecurrence.monthly:
        if (_monthlyDates.isNotEmpty) {
          final days = _monthlyDates.map((d) => d.toString()).join(', ');
          summary += 'monthly on days: $days';
        } else {
          summary += 'monthly on day ${_startDate?.day ?? _taskDate?.day ?? DateTime.now().day}';
        }
        break;
      case TaskRecurrence.yearly:
        final date = _startDate ?? _taskDate ?? DateTime.now();
        final month = DateFormat('MMMM').format(date);
        summary += 'every year on $month ${date.day}';
        break;
      default:
        return '';
    }
    
    if (_endDate != null) {
      summary += ' until ${DateFormat('MMM d, yyyy').format(_endDate!)}';
    }
    
    return summary;
  }

  Widget _buildMonthDayChip(BuildContext context, int day) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _monthlyDates.contains(day);
    
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _monthlyDates.remove(day);
          } else {
            _monthlyDates.add(day);
            _monthlyDates.sort();
          }
        });
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primary
              : (isDark ? Colors.white.withOpacity(0.05) : AppTheme.surface),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: isSelected 
                ? AppTheme.primary
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.3)),
          ),
        ),
        child: Center(
          child: Text(
            day.toString(),
            style: AppTheme.labelMedium.copyWith(
              color: isSelected 
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}