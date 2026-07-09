import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/enhanced_task.dart';
import '../models/task.dart';
import '../core/services/prayer_time_service.dart';
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
    
    if (widget.editingItem != null) {
      _loadExistingItem(widget.editingItem!);
    }
    
    _animationController.forward();
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

  Widget _buildSectionHeader(String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.space8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
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
              ? color.withValues(alpha: 0.1)
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
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
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
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
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
                color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
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
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
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
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
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
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
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
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
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
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
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
}