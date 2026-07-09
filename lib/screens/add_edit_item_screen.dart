import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../core/services/todo_service.dart';
import '../core/services/prayer_time_service.dart';
import '../core/theme/app_theme.dart';
import '../widgets/scheduling_section.dart';

class AddEditItemScreen extends StatefulWidget {
  final Task? task;
  final Map<String, String> prayerTimes;
  final DateTime? initialTime;
  final DateTime? initialEndTime;

  const AddEditItemScreen({
    super.key,
    this.task,
    required this.prayerTimes,
    this.initialTime,
    this.initialEndTime,
  });

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // Start time fields
  ScheduleType _startScheduleType = ScheduleType.absolute;
  DateTime? _selectedTime;
  PrayerName? _selectedPrayer;
  bool _isBeforePrayer = true;
  int _minutesOffset = 0;
  
  // End time fields
  ScheduleType _endScheduleType = ScheduleType.absolute;
  DateTime? _selectedEndTime;
  PrayerName? _endSelectedPrayer;
  bool _endIsBeforePrayer = false;
  int _endMinutesOffset = 30;
  
  TaskRecurrence _recurrenceType = TaskRecurrence.once;
  TaskPriority _priority = TaskPriority.medium;
  ItemType _itemType = ItemType.task;
  List<int> _selectedWeekDays = [];
  DateTime? _startDate; // Start date for recurring tasks
  DateTime? _endDate;
  int? _estimatedMinutes;
  
  // Advanced recurrence options
  int _weeklyInterval = 1; // Every X weeks
  List<int> _monthlyDates = []; // Specific dates in month
  String? _monthlyPattern; // "first_monday", etc.

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
    
    if (widget.task != null) {
      // Edit mode
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description ?? '';
      // Determine start schedule type
      _startScheduleType = widget.task!.relatedPrayer != null 
          ? ScheduleType.prayerRelative 
          : ScheduleType.absolute;
      _selectedTime = widget.task!.absoluteTime;
      _selectedPrayer = widget.task!.relatedPrayer;
      _isBeforePrayer = widget.task!.isBeforePrayer ?? true;
      _minutesOffset = widget.task!.minutesOffset ?? 0;
      
      // Determine end schedule type
      _endScheduleType = widget.task!.endRelatedPrayer != null
          ? ScheduleType.prayerRelative
          : ScheduleType.absolute;
      _selectedEndTime = widget.task!.endTime;
      _endSelectedPrayer = widget.task!.endRelatedPrayer;
      _endIsBeforePrayer = widget.task!.endIsBeforePrayer ?? false;
      _endMinutesOffset = widget.task!.endMinutesOffset ?? 30;
      _recurrenceType = widget.task!.recurrence;
      _priority = widget.task!.priority;
      _itemType = widget.task!.itemType;
      _selectedWeekDays = widget.task!.weeklyDays ?? [];
      _startDate = widget.task!.startDate;
      _endDate = widget.task!.endDate;
      _weeklyInterval = widget.task!.weeklyInterval ?? 1;
      _monthlyDates = widget.task!.monthlyDates ?? [];
      _monthlyPattern = widget.task!.monthlyPattern;
      _estimatedMinutes = widget.task!.estimatedMinutes;
    } else {
      // Add mode
      _startScheduleType = ScheduleType.absolute;
      _endScheduleType = ScheduleType.absolute;
      _selectedTime = widget.initialTime ?? DateTime.now().add(const Duration(hours: 1));
      _selectedEndTime = widget.initialEndTime;
      _recurrenceType = TaskRecurrence.once;
      _priority = TaskPriority.medium;
      // Anchor the task date on the pre-filled time (e.g. a free slot picked
      // on another date in the timeline) so the date flows through.
      if (widget.initialTime != null) {
        _startDate = DateTime(
          widget.initialTime!.year,
          widget.initialTime!.month,
          widget.initialTime!.day,
        );
      }
    }
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectEndDate() async {
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
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Validate start time
    if (_startScheduleType == ScheduleType.absolute && _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a start time')),
      );
      return;
    }
    
    if (_startScheduleType == ScheduleType.prayerRelative && _selectedPrayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a prayer for start time')),
      );
      return;
    }
    
    // Validate end time
    if (_endScheduleType == ScheduleType.absolute && _selectedEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an end time')),
      );
      return;
    }
    
    if (_endScheduleType == ScheduleType.prayerRelative && _endSelectedPrayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a prayer for end time')),
      );
      return;
    }
    
    // Validate that end time is after start time (only for absolute times)
    if (_startScheduleType == ScheduleType.absolute && 
        _endScheduleType == ScheduleType.absolute &&
        _selectedTime != null && 
        _selectedEndTime != null &&
        _selectedEndTime!.isBefore(_selectedTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }
    
    if (_recurrenceType == TaskRecurrence.weekly && _selectedWeekDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }
    
    try {
      // Determine overall schedule type based on start time
      final scheduleType = _startScheduleType;
      
      final task = Task(
        id: widget.task?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        createdAt: widget.task?.createdAt ?? DateTime.now(),
        // Stamp the edit time so last-write-wins sync never reverts this
        // save with an older cloud copy (toJson falls back to createdAt
        // when updatedAt is null).
        updatedAt: DateTime.now(),
        scheduleType: scheduleType,
        // Start time fields
        absoluteTime: _startScheduleType == ScheduleType.absolute ? _selectedTime : null,
        relatedPrayer: _startScheduleType == ScheduleType.prayerRelative ? _selectedPrayer : null,
        isBeforePrayer: _startScheduleType == ScheduleType.prayerRelative ? _isBeforePrayer : null,
        minutesOffset: _startScheduleType == ScheduleType.prayerRelative ? _minutesOffset : null,
        // End time fields
        endTime: _endScheduleType == ScheduleType.absolute ? _selectedEndTime : null,
        endRelatedPrayer: _endScheduleType == ScheduleType.prayerRelative ? _endSelectedPrayer : null,
        endIsBeforePrayer: _endScheduleType == ScheduleType.prayerRelative ? _endIsBeforePrayer : null,
        endMinutesOffset: _endScheduleType == ScheduleType.prayerRelative ? _endMinutesOffset : null,
        recurrence: _recurrenceType,
        priority: _priority,
        itemType: _itemType,
        weeklyDays: _recurrenceType == TaskRecurrence.weekly ? _selectedWeekDays : null,
        startDate: _startDate,
        endDate: _endDate,
        weeklyInterval: _recurrenceType == TaskRecurrence.weekly ? _weeklyInterval : null,
        monthlyDates: _recurrenceType == TaskRecurrence.monthly ? _monthlyDates : null,
        monthlyPattern: _monthlyPattern,
        estimatedMinutes: _estimatedMinutes,
      );
      
      if (widget.task != null) {
        await TodoService.updateTask(task);
      } else {
        await TodoService.addTask(task);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving item: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          widget.task != null ? 'Edit Item' : 'Create New Item',
          style: AppTheme.headlineSmall.copyWith(
            color: isDark ? Colors.white : AppTheme.primary,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : AppTheme.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : AppTheme.primary,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.space16),
            children: [
              // Title Section
              _buildSectionHeader('Item Details', Icons.edit_note),
              const SizedBox(height: AppTheme.space16),
              
              TextFormField(
                controller: _titleController,
                style: AppTheme.bodyLarge,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter title',
                  prefixIcon: Icon(Icons.task_alt, color: AppTheme.primary),
                  filled: true,
                  fillColor: AppTheme.surfaceVariantColor(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.borderDark : Colors.transparent,
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
              ),
              const SizedBox(height: AppTheme.space16),
              
              // Description
              TextFormField(
                controller: _descriptionController,
                style: AppTheme.bodyMedium,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Add more details',
                  prefixIcon: Icon(Icons.description_outlined, color: AppTheme.primary),
                  filled: true,
                  fillColor: AppTheme.surfaceVariantColor(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.borderDark : Colors.transparent,
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
              const SizedBox(height: AppTheme.space32),
            
              // Item Type
              _buildSectionHeader('Type', Icons.category),
              const SizedBox(height: AppTheme.space16),
              
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildItemTypeChip(context, ItemType.task, Icons.task_alt, 'Task'),
                    const SizedBox(width: AppTheme.space8),
                    _buildItemTypeChip(context, ItemType.activity, Icons.directions_run, 'Activity'),
                    const SizedBox(width: AppTheme.space8),
                    _buildItemTypeChip(context, ItemType.event, Icons.event, 'Event'),
                    const SizedBox(width: AppTheme.space8),
                    _buildItemTypeChip(context, ItemType.session, Icons.computer, 'Session'),
                    const SizedBox(width: AppTheme.space8),
                    _buildItemTypeChip(context, ItemType.routine, Icons.repeat, 'Routine'),
                    const SizedBox(width: AppTheme.space8),
                    _buildItemTypeChip(context, ItemType.appointment, Icons.people, 'Appointment'),
                    const SizedBox(width: AppTheme.space8),
                    _buildItemTypeChip(context, ItemType.reminder, Icons.notifications, 'Reminder'),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space32),
            
              // Time Schedule Section using shared widget
              SchedulingSection(
                isOptional: false, // Required for Agenda
                initialHasSchedule: true,
                hideDatePicker: true, // Date is picked via the Task Date / Start Date field below
                initialTaskDate: _startDate ?? _selectedTime,
                initialStartScheduleType: _startScheduleType,
                initialStartTime: _selectedTime,
                initialStartPrayer: _selectedPrayer,
                initialStartIsBeforePrayer: _isBeforePrayer,
                initialStartMinutesOffset: _minutesOffset,
                initialEndScheduleType: _endScheduleType,
                initialEndTime: _selectedEndTime,
                initialEndPrayer: _endSelectedPrayer,
                initialEndIsBeforePrayer: _endIsBeforePrayer,
                initialEndMinutesOffset: _endMinutesOffset,
                prayerTimes: widget.prayerTimes,
                onScheduleChanged: (data) {
                  setState(() {
                    _startDate = data.taskDate;
                    _startScheduleType = data.startScheduleType;
                    _selectedTime = data.startTime;
                    _selectedPrayer = data.startPrayer;
                    _isBeforePrayer = data.startIsBeforePrayer;
                    _minutesOffset = data.startMinutesOffset;
                    _endScheduleType = data.endScheduleType;
                    _selectedEndTime = data.endTime;
                    _endSelectedPrayer = data.endPrayer;
                    _endIsBeforePrayer = data.endIsBeforePrayer;
                    _endMinutesOffset = data.endMinutesOffset;
                  });
                },
              ),

              // Prayer-relative schedule rule with date preview
              if (_startScheduleType == ScheduleType.prayerRelative &&
                  _selectedPrayer != null) ...[
                const SizedBox(height: AppTheme.space16),
                Container(
                  padding: const EdgeInsets.all(AppTheme.space16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Expanded(
                        child: Text(
                          _buildRuleDescription(),
                          style: AppTheme.labelMedium.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space8),
                      _buildPreviewButton(context),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppTheme.space32),

              // Recurrence
              _buildSectionHeader('Repeat', Icons.repeat),
              const SizedBox(height: AppTheme.space16),
              
              // Recurrence type selector - redesigned for 5 options
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariantColor(context),
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
            
              // Recurrence Details Section
              AnimatedSize(
                duration: AppTheme.animationFast,
                child: _buildRecurrenceDetails(context, isDark),
              ),
              
              const SizedBox(height: AppTheme.space32),
              
              // Priority Selection
              _buildSectionHeader('Priority', Icons.flag),
              const SizedBox(height: AppTheme.space16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildPriorityOption(
                      context,
                      priority: TaskPriority.low,
                      icon: Icons.arrow_downward_rounded,
                      label: 'Low',
                      color: AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: _buildPriorityOption(
                      context,
                      priority: TaskPriority.medium,
                      icon: Icons.remove_rounded,
                      label: 'Medium',
                      color: AppTheme.warning,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: _buildPriorityOption(
                      context,
                      priority: TaskPriority.high,
                      icon: Icons.priority_high_rounded,
                      label: 'High',
                      color: AppTheme.error,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppTheme.space48),
            
              // Save button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.task != null ? 'Update Item' : 'Create Item',
                    style: AppTheme.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: AppTheme.space32),
            ],
          ),
        ),
      ),
    );
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
  
  
  
  
  
  Widget _buildRecurrenceOption(
    BuildContext context, {
    required TaskRecurrence type,
    required bool isSelected,
  }) {
    final label = type.toString().split('.').last.toUpperCase();
    
    return InkWell(
      onTap: () => setState(() => _recurrenceType = type),
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTheme.labelMedium.copyWith(
              color: isSelected ? AppTheme.primary : AppTheme.textSecondaryColor(context),
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
                : AppTheme.surfaceVariantColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: isSelected 
                  ? AppTheme.primary
                  : isDark ? AppTheme.borderDark : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              shortName,
              style: AppTheme.labelLarge.copyWith(
                color: isSelected 
                    ? Colors.white
                    : (AppTheme.textSecondaryColor(context)),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildItemTypeChip(
    BuildContext context,
    ItemType type,
    IconData icon,
    String label,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _itemType == type;
    
    return InkWell(
      onTap: () => setState(() => _itemType = type),
      borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space16,
          vertical: AppTheme.space8,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primary
              : AppTheme.surfaceVariantColor(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
          border: Border.all(
            color: isSelected 
                ? AppTheme.primary
                : isDark ? AppTheme.borderDark : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected 
                  ? Colors.white
                  : (AppTheme.textSecondaryColor(context)),
            ),
            const SizedBox(width: AppTheme.space8),
            Text(
              label,
              style: AppTheme.labelLarge.copyWith(
                color: isSelected 
                    ? Colors.white
                    : (AppTheme.textSecondaryColor(context)),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPriorityOption(
    BuildContext context, {
    required TaskPriority priority,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isSelected = _priority == priority;
    
    return InkWell(
      onTap: () => setState(() => _priority = priority),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.space12,
          horizontal: AppTheme.space16,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withValues(alpha: 0.15)
              : AppTheme.surfaceVariantColor(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isSelected
                ? color
                : AppTheme.borderColor(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? color : AppTheme.textSecondaryColor(context),
            ),
            const SizedBox(height: AppTheme.space4),
            Text(
              label,
              style: AppTheme.labelMedium.copyWith(
                color: isSelected ? color : AppTheme.textSecondaryColor(context),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  
  Widget _buildPreviewButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showDatePreview,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space12,
            vertical: AppTheme.space6,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppTheme.primary,
              ),
              const SizedBox(width: AppTheme.space6),
              Text(
                'Preview',
                style: AppTheme.labelSmall.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _showDatePreview() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: AppTheme.surfaceColor(context),
              onSurface: AppTheme.textPrimaryColor(context),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (date == null || !mounted) return;

    // Fetch prayer times for the selected date (falls back to cache offline)
    Map<String, String> prayerTimesForDate = {};
    try {
      prayerTimesForDate = await PrayerTimeService.getPrayerTimes(date: date);
    } catch (_) {
      // Leave empty - the dialog shows a fallback message
    }

    if (!mounted) return;
    _showPreviewDialog(date, prayerTimesForDate);
  }

  String _prayerDisplayName(PrayerName prayer) {
    final prayerStr = prayer.toString().split('.').last;
    return prayerStr.substring(0, 1).toUpperCase() + prayerStr.substring(1);
  }

  void _showPreviewDialog(DateTime date, Map<String, String> prayerTimesForDate) {
    // Compute the actual start/end times for the chosen date
    DateTime? startPreview;
    DateTime? endPreview;
    if (prayerTimesForDate.isNotEmpty && _selectedPrayer != null) {
      startPreview = PrayerTimeService.calculatePrayerRelativeTime(
        prayerTimes: prayerTimesForDate,
        prayerName: _prayerDisplayName(_selectedPrayer!),
        isBefore: _isBeforePrayer,
        minutesOffset: _minutesOffset,
        baseDate: date,
      );
      if (_endScheduleType == ScheduleType.prayerRelative &&
          _endSelectedPrayer != null) {
        endPreview = PrayerTimeService.calculatePrayerRelativeTime(
          prayerTimes: prayerTimesForDate,
          prayerName: _prayerDisplayName(_endSelectedPrayer!),
          isBefore: _endIsBeforePrayer,
          minutesOffset: _endMinutesOffset,
          baseDate: date,
        );
      }
    }
    _showPreviewDialogContent(date, startPreview, endPreview);
  }

  Widget _buildPreviewTimeRow({
    required String label,
    required DateTime time,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(Icons.access_time, color: color, size: 18),
        const SizedBox(width: AppTheme.space8),
        Text(
          label,
          style: AppTheme.labelMedium.copyWith(
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        const Spacer(),
        Text(
          DateFormat('h:mm a').format(time),
          style: AppTheme.titleMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showPreviewDialogContent(
    DateTime date,
    DateTime? startPreview,
    DateTime? endPreview,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.space8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.preview_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Schedule Preview',
                  style: AppTheme.titleMedium,
                ),
                Text(
                  DateFormat('EEEE, MMM d, yyyy').format(date),
                  style: AppTheme.labelSmall.copyWith(
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppTheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: startPreview != null
                  ? Column(
                      children: [
                        _buildPreviewTimeRow(
                          label: 'Starts',
                          time: startPreview,
                          color: AppTheme.success,
                        ),
                        if (endPreview != null) ...[
                          const SizedBox(height: AppTheme.space12),
                          _buildPreviewTimeRow(
                            label: 'Ends',
                            time: endPreview,
                            color: AppTheme.error,
                          ),
                        ],
                      ],
                    )
                  : Column(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppTheme.primary,
                          size: 48,
                        ),
                        const SizedBox(height: AppTheme.space12),
                        Text(
                          'Prayer times for ${DateFormat('MMM d').format(date)} are not available yet',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondaryColor(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.space8),
                        Text(
                          'Times will be calculated automatically when the date arrives',
                          style: AppTheme.labelSmall.copyWith(
                            color: AppTheme.textTertiaryColor(context),
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: AppTheme.space16),
            // Show the rule
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantColor(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Schedule Rule:',
                    style: AppTheme.labelSmall.copyWith(
                      color: AppTheme.textTertiaryColor(context),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    _buildRuleDescription(),
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: TextStyle(color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
  
  String _buildRuleDescription() {
    if (_selectedPrayer == null) return '';
    
    final prayerStr = _selectedPrayer.toString().split('.').last;
    final prayerName = prayerStr.substring(0, 1).toUpperCase() + prayerStr.substring(1);
    
    String rule = '$_minutesOffset min ${_isBeforePrayer ? "before" : "after"} $prayerName';
    
    if (_endSelectedPrayer != null) {
      final endPrayerStr = _endSelectedPrayer.toString().split('.').last;
      final endPrayerName = endPrayerStr.substring(0, 1).toUpperCase() + endPrayerStr.substring(1);
      rule += ' to $_endMinutesOffset min ${_endIsBeforePrayer ? "before" : "after"} $endPrayerName';
    }
    
    return rule;
  }
  
  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      setState(() {
        // The SchedulingSection picks this up via didUpdateWidget and
        // rebases any picked start/end times onto the new date.
        _startDate = date;
      });
    }
  }

  Widget _buildRecurrenceDetails(BuildContext context, bool isDark) {
    if (_recurrenceType == TaskRecurrence.once) {
      // For "Once" - show calendar picker to select the date
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppTheme.space24),
          Text(
            'Task Date',
            style: AppTheme.labelLarge.copyWith(
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          InkWell(
            onTap: _selectStartDate,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.space16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantColor(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: AppTheme.space16),
                  Expanded(
                    child: Text(
                      _startDate != null
                          ? DateFormat('EEEE, MMMM d, yyyy').format(_startDate!)
                          : 'Today - ${DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now())}',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: AppTheme.textTertiaryColor(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          Container(
            padding: const EdgeInsets.all(AppTheme.space12),
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.info,
                  size: 18,
                ),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: Text(
                    'This task will occur only once on ${_startDate != null ? DateFormat('MMMM d, yyyy').format(_startDate!) : 'today'}',
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

    // For recurring tasks
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTheme.space24),
        
        // Start Date
        Text(
          'Start Date',
          style: AppTheme.labelLarge.copyWith(
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        InkWell(
          onTap: _selectStartDate,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.space16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariantColor(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : Colors.transparent,
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
                  color: AppTheme.textTertiaryColor(context),
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
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              Container(
                width: 80,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariantColor(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: isDark ? AppTheme.borderDark : Colors.transparent,
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
              color: AppTheme.textSecondaryColor(context),
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
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          // Grid of days 1-31
          Container(
            padding: const EdgeInsets.all(AppTheme.space12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariantColor(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : Colors.transparent,
              ),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 31,
              itemBuilder: (context, index) {
                final day = index + 1;
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
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.surfaceColor(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.borderColor(context),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        day.toString(),
                        style: AppTheme.labelMedium.copyWith(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textPrimaryColor(context),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_monthlyDates.isEmpty) ...[
            const SizedBox(height: AppTheme.space8),
            Text(
              'Tap to select days when the task should repeat',
              style: AppTheme.labelSmall.copyWith(
                color: AppTheme.textTertiaryColor(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
        
        // End Date (for all recurring)
        const SizedBox(height: AppTheme.space24),
        Text(
          'End Date',
          style: AppTheme.labelLarge.copyWith(
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        InkWell(
          onTap: _selectEndDate,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.space16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariantColor(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_busy,
                  color: _endDate != null ? AppTheme.primary : AppTheme.textTertiaryColor(context),
                ),
                const SizedBox(width: AppTheme.space16),
                Expanded(
                  child: Text(
                    _endDate != null
                        ? DateFormat('EEEE, MMMM d, yyyy').format(_endDate!)
                        : 'No end date',
                    style: AppTheme.bodyLarge.copyWith(
                      color: _endDate != null ? null : AppTheme.textTertiaryColor(context),
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
                    color: AppTheme.textTertiaryColor(context),
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
            color: AppTheme.info.withValues(alpha: 0.1),
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
          summary += 'monthly on day ${_startDate?.day ?? DateTime.now().day}';
        }
        break;
      case TaskRecurrence.yearly:
        final month = _startDate != null 
            ? DateFormat('MMMM').format(_startDate!)
            : DateFormat('MMMM').format(DateTime.now());
        summary += 'every year on $month ${_startDate?.day ?? DateTime.now().day}';
        break;
      default:
        return '';
    }
    
    if (_endDate != null) {
      summary += ' until ${DateFormat('MMM d, yyyy').format(_endDate!)}';
    }
    
    return summary;
  }
}