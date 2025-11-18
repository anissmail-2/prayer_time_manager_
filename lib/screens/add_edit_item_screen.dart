import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../core/services/todo_service.dart';
import '../core/services/prayer_time_service.dart';
import '../core/services/user_preferences_service.dart';
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

  // Prayer mode state
  bool _isPrayerModeEnabled = true;

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

    _loadPrayerMode();
    
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

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedTime ?? DateTime.now()),
    );
    
    if (time != null) {
      setState(() {
        final now = DateTime.now();
        _selectedTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
      });
    }
  }

  Future<void> _selectEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _selectedEndTime ?? _selectedTime?.add(const Duration(hours: 1)) ?? DateTime.now(),
      ),
    );
    
    if (time != null) {
      setState(() {
        final now = DateTime.now();
        final newEndTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
        
        // Check if end time is after start time
        if (_selectedTime != null && newEndTime.isBefore(_selectedTime!)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('End time must be after start time')),
          );
          return;
        }
        
        _selectedEndTime = newEndTime;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
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
    
    if (_recurrenceType == RecurrenceType.weekly && _selectedWeekDays.isEmpty) {
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
        print('Updating task...');
        await TodoService.updateTask(task);
      } else {
        print('Adding new task...');
        await TodoService.addTask(task);
      }
      
      print('Task saved successfully, navigating back...');
      Navigator.pop(context, true);
    } catch (e) {
      print('Error saving task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving item: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
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
                hideDatePicker: true, // Hide date picker since it's handled in recurrence
                showPrayerRelativeOptions: _isPrayerModeEnabled, // Show prayer options based on mode
                initialTaskDate: _selectedTime ?? _startDate,
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
              
              const SizedBox(height: AppTheme.space32),
            
              // Recurrence
              _buildSectionHeader('Repeat', Icons.repeat),
              const SizedBox(height: AppTheme.space16),
              
              // Recurrence type selector - redesigned for 5 options
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
  
  Widget _buildAbsoluteTimeSection(BuildContext context, bool isDark) {
    return Column(
      key: const ValueKey('absolute'),
      children: [
        // Start Time
        InkWell(
          onTap: _selectTime,
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
                        _selectedTime != null 
                            ? DateFormat('h:mm a').format(_selectedTime!)
                            : 'Select time',
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
          onTap: _selectEndTime,
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
                        _selectedEndTime != null 
                            ? DateFormat('h:mm a').format(_selectedEndTime!)
                            : 'Select end time',
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _selectedEndTime != null 
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
  
  Widget _buildPrayerRelativeSection(BuildContext context, bool isDark) {
    return Column(
      key: const ValueKey('prayer'),
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
              labelText: 'Select Prayer *',
              prefixIcon: Icon(Icons.mosque, color: AppTheme.primary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: AppTheme.space12,
              ),
            ),
            initialValue: _selectedPrayer,
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
                child: _buildBeforeAfterOption(
                  context,
                  label: 'Before',
                  isSelected: _isBeforePrayer,
                  onTap: () => setState(() => _isBeforePrayer = true),
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
                  isSelected: !_isBeforePrayer,
                  onTap: () => setState(() => _isBeforePrayer = false),
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
            helperText: 'How many minutes ${_isBeforePrayer ? "before" : "after"} the prayer',
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide(
                color: AppTheme.error,
                width: 2,
              ),
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
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter minutes';
            }
            final minutes = int.tryParse(value);
            if (minutes == null || minutes < 0) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
        
        // Show calculated time for prayer-relative selection
        if (_selectedPrayer != null) ...[
          const SizedBox(height: AppTheme.space12),
          _buildCalculatedTimeDisplay(
            prayer: _selectedPrayer!,
            isBefore: _isBeforePrayer,
            minutes: _minutesOffset,
            label: 'Task will start at',
            color: AppTheme.success,
          ),
        ],
        
        const SizedBox(height: AppTheme.space24),
        
        // End Time Section
        _buildSectionHeader('End Time', Icons.access_time_filled),
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
          child: DropdownButtonFormField<PrayerName>(
            decoration: InputDecoration(
              labelText: 'End at Prayer *',
              prefixIcon: Icon(Icons.mosque, color: AppTheme.primary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: AppTheme.space12,
              ),
            ),
            initialValue: _endSelectedPrayer,
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
              setState(() {
                _endSelectedPrayer = value;
              });
            },
            validator: (value) {
              if (value == null) {
                return 'Please select an end prayer';
              }
              return null;
            },
          ),
        ),
        
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
            prefixIcon: Icon(Icons.timer_off_outlined, color: AppTheme.primary),
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
          keyboardType: TextInputType.number,
          initialValue: _endMinutesOffset.toString(),
          onChanged: (value) {
            final minutes = int.tryParse(value);
            if (minutes != null && minutes >= 0) {
              setState(() {
                _endMinutesOffset = minutes;
              });
            }
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter end minutes';
            }
            final minutes = int.tryParse(value);
            if (minutes == null || minutes < 0) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
        
        // Show calculated time for end prayer-relative selection
        if (_endSelectedPrayer != null) ...[
          const SizedBox(height: AppTheme.space12),
          _buildCalculatedTimeDisplay(
            prayer: _endSelectedPrayer!,
            isBefore: _endIsBeforePrayer,
            minutes: _endMinutesOffset,
            label: 'Task will end at',
            color: AppTheme.error,
          ),
        ],
        
        // Show schedule rule with beautiful UI
        if (_selectedPrayer != null) ...[
          const SizedBox(height: AppTheme.space24),
          // Beautiful Schedule Rule Display
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primary.withOpacity(0.08),
                  AppTheme.primary.withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                // Header with icon and title
                Container(
                  padding: const EdgeInsets.all(AppTheme.space16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppTheme.radiusLarge - 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.space8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.schedule_rounded,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Text(
                        'Schedule Rule',
                        style: AppTheme.titleMedium.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      // Preview button
                      _buildPreviewButton(context),
                    ],
                  ),
                ),
                // Rule display
                Padding(
                  padding: const EdgeInsets.all(AppTheme.space20),
                  child: Column(
                    children: [
                      // Start time rule
                      _buildTimeRuleRow(
                        icon: Icons.play_arrow_rounded,
                        label: 'Start',
                        prayer: _selectedPrayer!,
                        isBefore: _isBeforePrayer,
                        minutes: _minutesOffset,
                        color: AppTheme.success,
                      ),
                      if (_endSelectedPrayer != null) ...[
                        const SizedBox(height: AppTheme.space16),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: AppTheme.space32),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppTheme.primary.withOpacity(0.2),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.space16),
                        // End time rule
                        _buildTimeRuleRow(
                          icon: Icons.stop_rounded,
                          label: 'End',
                          prayer: _endSelectedPrayer!,
                          isBefore: _endIsBeforePrayer,
                          minutes: _endMinutesOffset,
                          color: AppTheme.error,
                        ),
                      ],
                      const SizedBox(height: AppTheme.space20),
                      // Info message
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space12,
                          vertical: AppTheme.space8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.white.withOpacity(0.05)
                              : AppTheme.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: AppTheme.primary.withOpacity(0.7),
                            ),
                            const SizedBox(width: AppTheme.space8),
                            Text(
                              'Times adjust daily with prayer schedule',
                              style: AppTheme.labelSmall.copyWith(
                                color: AppTheme.primary.withOpacity(0.7),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
              : isDark ? Colors.white.withOpacity(0.05) : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
          border: Border.all(
            color: isSelected 
                ? AppTheme.primary
                : isDark ? Colors.white.withOpacity(0.1) : Colors.transparent,
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
                  : (isDark ? Colors.white70 : Colors.grey[700]),
            ),
            const SizedBox(width: AppTheme.space8),
            Text(
              label,
              style: AppTheme.labelLarge.copyWith(
                color: isSelected 
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey[700]),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              ? color.withOpacity(0.15)
              : isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isSelected 
                ? color
                : isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? color : AppTheme.textSecondary,
            ),
            const SizedBox(height: AppTheme.space4),
            Text(
              label,
              style: AppTheme.labelMedium.copyWith(
                color: isSelected ? color : AppTheme.textSecondary,
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
    required String label,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prayerStr = prayer.toString().split('.').last;
    final displayName = prayerStr.substring(0, 1).toUpperCase() + prayerStr.substring(1);
    
    // Calculate the actual time
    final calculatedTime = PrayerTimeService.calculatePrayerRelativeTime(
      prayerTimes: widget.prayerTimes,
      prayerName: displayName,
      isBefore: isBefore,
      minutesOffset: minutes,
    );
    
    if (calculatedTime == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.access_time,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.labelSmall.copyWith(
                    color: isDark ? Colors.white54 : AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  DateFormat('EEEE, MMMM d • h:mm a').format(calculatedTime),
                  style: AppTheme.bodyLarge.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRuleRow({
    required IconData icon,
    required String label,
    required PrayerName prayer,
    required bool isBefore,
    required int minutes,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prayerStr = prayer.toString().split('.').last;
    final displayName = prayerStr.substring(0, 1).toUpperCase() + prayerStr.substring(1);
    
    // Calculate the actual time
    final calculatedTime = PrayerTimeService.calculatePrayerRelativeTime(
      prayerTimes: widget.prayerTimes,
      prayerName: displayName,
      isBefore: isBefore,
      minutesOffset: minutes,
    );
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.space8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: AppTheme.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.labelSmall.copyWith(
                  color: isDark ? Colors.white54 : AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              RichText(
                text: TextSpan(
                  style: AppTheme.bodyLarge.copyWith(
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: '$minutes ',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: 'minutes '),
                    TextSpan(
                      text: isBefore ? 'before ' : 'after ',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: displayName,
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (calculatedTime != null) ...[
                const SizedBox(height: AppTheme.space4),
                Text(
                  'Today at ${DateFormat('h:mm a').format(calculatedTime)}',
                  style: AppTheme.labelMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Prayer time display
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space12,
                vertical: AppTheme.space6,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mosque,
                    size: 14,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: AppTheme.space4),
                  Text(
                    widget.prayerTimes[displayName] ?? '--:--',
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
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
              color: AppTheme.primary.withOpacity(0.3),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
              surface: isDark ? AppTheme.surfaceDark : Colors.white,
              onSurface: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (date != null && mounted) {
      // Here you would fetch prayer times for the selected date
      // For now, we'll show a dialog with the current calculation
      _showPreviewDialog(date);
    }
  }
  
  void _showPreviewDialog(DateTime date) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.space8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
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
                    color: AppTheme.textSecondary,
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
              padding: const EdgeInsets.all(AppTheme.space16),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withOpacity(0.05)
                    : AppTheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.2),
                ),
              ),
              child: Column(
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
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.space8),
                  Text(
                    'Times will be calculated automatically when the date arrives',
                    style: AppTheme.labelSmall.copyWith(
                      color: AppTheme.textTertiary,
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
                color: isDark 
                    ? Colors.white.withOpacity(0.05)
                    : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Schedule Rule:',
                    style: AppTheme.labelSmall.copyWith(
                      color: AppTheme.textTertiary,
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
  
  String _calculatePrayerRelativeTimes() {
    // Keep this method for backward compatibility if needed
    return _buildRuleDescription();
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
            duration: AppTheme.animationFast,
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
    required DateTime? selectedTime,
    required Function(DateTime) onTimeSelected,
    required bool isStartTime,
  }) {
    return InkWell(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(selectedTime ?? DateTime.now()),
        );
        
        if (time != null) {
          final now = DateTime.now();
          onTimeSelected(DateTime(now.year, now.month, now.day, time.hour, time.minute));
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
                  ? DateFormat('hh:mm a').format(selectedTime)
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

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() {
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
                  color: AppTheme.primary.withOpacity(0.3),
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
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
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
          // Grid of days 1-31
          Container(
            padding: const EdgeInsets.all(AppTheme.space12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.transparent,
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
                          : isDark
                              ? Colors.white.withOpacity(0.05)
                              : AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.2),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        day.toString(),
                        style: AppTheme.labelMedium.copyWith(
                          color: isSelected
                              ? Colors.white
                              : isDark
                                  ? Colors.white70
                                  : Colors.black87,
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
                color: Colors.grey,
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