import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/prayer_duration.dart';
import '../core/services/todo_service.dart';
import '../core/services/prayer_time_service.dart';
import '../core/services/prayer_duration_service.dart';
import '../core/theme/app_theme.dart';
import '../widgets/task_details_dialog.dart';
import 'add_edit_item_screen.dart';
import 'prayer_settings_screen.dart';

// Mobile-optimized timeline view
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  Map<String, String> _prayerTimes = {};
  List<TaskWithTime> _todayTasks = [];
  final List<TimelineItem> _timelineItems = [];
  List<PrayerTimeBlock> _prayerBlocks = [];
  List<FreeTimeSlot> _freeTimeSlots = [];
  bool _isLoading = true;
  bool _showFreeTime = false;
  bool _showPrayerTimes = true;
  DateTime _selectedDate = DateTime.now();
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _loadData();
    // Start timer to refresh timeline every minute
    _startTimer();
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  void _startTimer() {
    // Refresh timeline every minute to update NOW marker and free time splits
    Future.delayed(const Duration(minutes: 1), () {
      if (mounted && _isSameDay(_selectedDate, DateTime.now())) {
        _buildTimelineItems();
        setState(() {});
        _startTimer(); // Continue the timer
      }
    });
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      _prayerTimes = await PrayerTimeService.getPrayerTimes(date: _selectedDate);
      
      // Get all tasks and filter for selected date
      final allTasks = await TodoService.getAllTasks();
      final selectedDateTasks = allTasks.where((task) {
        // Filter tasks that should show on selected date
        if (task.isCompleted && task.recurrence == TaskRecurrence.once) {
          return false;
        }
        
        // Check if task has scheduling info
        if (task.scheduleType == ScheduleType.absolute && task.absoluteTime == null) {
          return false;
        }
        
        if (task.scheduleType == ScheduleType.prayerRelative && task.relatedPrayer == null) {
          return false;
        }
        
        // For now, show all scheduled tasks
        return true;
      }).toList();
      
      // Convert to TaskWithTime
      _todayTasks = [];
      for (final task in selectedDateTasks) {
        final scheduledTime = await TodoService.calculateTaskTime(task, _prayerTimes, _selectedDate);
        if (scheduledTime != null) {
          DateTime? endTime;
          
          // Calculate end time
          if (task.scheduleType == ScheduleType.absolute && task.endTime != null) {
            endTime = DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
              task.endTime!.hour,
              task.endTime!.minute,
            );
          } else if (task.estimatedMinutes != null) {
            endTime = scheduledTime.add(Duration(minutes: task.estimatedMinutes!));
          } else {
            endTime = scheduledTime.add(const Duration(minutes: 30));
          }
          
          _todayTasks.add(TaskWithTime(
            task: task,
            scheduledTime: scheduledTime,
            endTime: endTime,
          ));
        }
      }
      
      _prayerBlocks = await PrayerDurationService.getPrayerBlocksForDate(_selectedDate);
      _freeTimeSlots = await PrayerDurationService.getFreeTimes(_todayTasks);
      
      _buildTimelineItems();
      
      // Scroll to current time after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToNow();
      });
    } catch (e) {
      debugPrint('Error loading timeline: $e');
    }
    
    setState(() => _isLoading = false);
  }
  
  void _buildTimelineItems() {
    _timelineItems.clear();
    final now = DateTime.now();
    final today = _selectedDate;
    final isToday = _isSameDay(today, now);
    
    // Add all events with their times
    List<TimelineItem> events = [];
    
    // Add prayer blocks (with duration ranges) if filter is on
    if (_showPrayerTimes) {
      for (final prayerBlock in _prayerBlocks) {
        // Skip unwanted prayer times
        final prayerName = prayerBlock.prayer.toString().split('.').last;
        final displayName = prayerName.substring(0, 1).toUpperCase() + prayerName.substring(1);
        
        // Skip sunrise and other unwanted times
        if (prayerBlock.prayer == PrayerName.sunrise) continue;
        
        events.add(TimelineItem(
          type: TimelineItemType.prayer,
          title: displayName,
          time: prayerBlock.startTime,
          endTime: prayerBlock.endTime,
          actualPrayerTime: prayerBlock.actualPrayerTime,
          color: _getPrayerColor(prayerBlock.prayer),
          icon: Icons.mosque_rounded,
          prayerBlock: prayerBlock,
        ));
      }
    }
    
    // Add tasks
    for (final taskWithTime in _todayTasks) {
      events.add(TimelineItem(
        type: TimelineItemType.task,
        title: taskWithTime.task.title,
        description: taskWithTime.task.description,
        time: taskWithTime.scheduledTime,
        endTime: taskWithTime.endTime,
        color: _getTaskColor(taskWithTime.task.priority),
        icon: Icons.task_alt_rounded,
        task: taskWithTime.task,
      ));
    }
    
    // Add free time slots if filter is on
    if (_showFreeTime) {
      final now = DateTime.now();
      final isToday = _isSameDay(_selectedDate, now);
      
      for (final freeSlot in _freeTimeSlots) {
        // Check if this free slot needs to be split by current time
        if (isToday && 
            freeSlot.startTime.isBefore(now) && 
            freeSlot.endTime.isAfter(now)) {
          // Split the free time slot at current time
          // Part 1: Past free time (grayed out)
          final pastDuration = now.difference(freeSlot.startTime);
          events.add(TimelineItem(
            type: TimelineItemType.freeTime,
            title: 'Free Time',
            description: '${pastDuration.inMinutes} minutes (past)',
            time: freeSlot.startTime,
            endTime: now,
            color: AppTheme.textTertiary.withValues(alpha: 0.3),
            icon: Icons.history_rounded,
            freeSlot: FreeTimeSlot(
              startTime: freeSlot.startTime,
              endTime: now,
              duration: pastDuration,
            ),
          ));
          
          // Part 2: Future free time (still available)
          final futureDuration = freeSlot.endTime.difference(now);
          events.add(TimelineItem(
            type: TimelineItemType.freeTime,
            title: 'Free Time',
            description: '${futureDuration.inMinutes} minutes available',
            time: now,
            endTime: freeSlot.endTime,
            color: AppTheme.success.withValues(alpha: 0.3),
            icon: Icons.add_circle_outline_rounded,
            freeSlot: FreeTimeSlot(
              startTime: now,
              endTime: freeSlot.endTime,
              duration: futureDuration,
            ),
          ));
        } else {
          // No need to split - add the whole slot
          final isPast = isToday && freeSlot.endTime.isBefore(now);
          events.add(TimelineItem(
            type: TimelineItemType.freeTime,
            title: 'Free Time',
            description: isPast 
                ? '${freeSlot.duration.inMinutes} minutes (past)'
                : '${freeSlot.duration.inMinutes} minutes available',
            time: freeSlot.startTime,
            endTime: freeSlot.endTime,
            color: isPast 
                ? AppTheme.textTertiary.withValues(alpha: 0.3)
                : AppTheme.success.withValues(alpha: 0.3),
            icon: isPast ? Icons.history_rounded : Icons.add_circle_outline_rounded,
            freeSlot: freeSlot,
          ));
        }
      }
    }
    
    // Sort events by time
    events.sort((a, b) => a.time.compareTo(b.time));
    
    // Group events by time period and add to timeline
    DateTime? lastHour;
    for (final event in events) {
      // Add hour marker if new hour
      final eventHour = DateTime(event.time.year, event.time.month, event.time.day, event.time.hour);
      if (lastHour == null || eventHour.hour != lastHour.hour) {
        _timelineItems.add(TimelineItem(
          type: TimelineItemType.timeMarker,
          title: DateFormat('h a').format(eventHour),
          time: eventHour,
        ));
        lastHour = eventHour;
      }
      
      // Add the event
      _timelineItems.add(event);
    }
    
    // Add current time marker if today
    if (isToday) {
      // Find position for current time
      int insertIndex = _timelineItems.length;
      for (int i = 0; i < _timelineItems.length; i++) {
        if (_timelineItems[i].time.isAfter(now)) {
          insertIndex = i;
          break;
        }
      }
      
      _timelineItems.insert(insertIndex, TimelineItem(
        type: TimelineItemType.currentTime,
        title: 'Now',
        time: now,
      ));
    }
  }
  
  void _scrollToNow() {
    if (!mounted || !_scrollController.hasClients) return;
    if (!_isSameDay(_selectedDate, DateTime.now())) return;
    
    // Find current time item
    final nowIndex = _timelineItems.indexWhere((item) => item.type == TimelineItemType.currentTime);
    if (nowIndex != -1) {
      // Calculate approximate position (each item ~80px)
      final scrollPosition = nowIndex * 80.0 - 200; // Center it
      
      _scrollController.animateTo(
        scrollPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildTimeline(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    
    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
          // Date selector and filter button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                InkWell(
                  onTap: () => _selectDate(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isToday ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isToday ? AppTheme.primary : AppTheme.borderLight,
                        width: isToday ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: isToday ? AppTheme.primary : AppTheme.textSecondary,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isToday ? 'Today' : DateFormat('EEEE').format(_selectedDate),
                                style: AppTheme.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isToday ? AppTheme.primary : AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('MMMM d, yyyy').format(_selectedDate),
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppTheme.textSecondary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showPrayerTimes = !_showPrayerTimes;
                            _buildTimelineItems();
                          });
                        },
                        icon: Icon(
                          Icons.mosque_rounded,
                          size: 18,
                        ),
                        label: Text(_showPrayerTimes ? 'Hide Prayers' : 'Show Prayers'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _showPrayerTimes ? AppTheme.primary : AppTheme.textSecondary,
                          side: BorderSide(
                            color: _showPrayerTimes ? AppTheme.primary : AppTheme.borderLight,
                          ),
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showFreeTime = !_showFreeTime;
                            _buildTimelineItems();
                          });
                        },
                        icon: Icon(
                          Icons.event_available_rounded,
                          size: 18,
                        ),
                        label: Text(_showFreeTime ? 'Hide Free' : 'Show Free'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _showFreeTime ? AppTheme.success : AppTheme.textSecondary,
                          side: BorderSide(
                            color: _showFreeTime ? AppTheme.success : AppTheme.borderLight,
                          ),
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTimeline() {
    if (_timelineItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 64,
              color: AppTheme.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No events today',
              style: AppTheme.titleMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _timelineItems.length,
      itemBuilder: (context, index) {
        final item = _timelineItems[index];
        
        switch (item.type) {
          case TimelineItemType.section:
            return _buildSectionHeader(item);
          case TimelineItemType.timeMarker:
            return _buildTimeMarker(item);
          case TimelineItemType.currentTime:
            return _buildCurrentTimeMarker();
          case TimelineItemType.prayer:
            return _buildPrayerItem(item);
          case TimelineItemType.task:
            return _buildTaskItem(item);
          case TimelineItemType.freeTime:
            return _buildFreeTimeItem(item);
        }
      },
    );
  }
  
  Widget _buildSectionHeader(TimelineItem item) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        item.title,
        style: AppTheme.headlineSmall.copyWith(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildTimeMarker(TimelineItem item) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              item.title,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: AppTheme.borderLight,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCurrentTimeMarker() {
    final now = DateTime.now();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.error,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  'NOW',
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('h:mm a').format(now),
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.error,
                    AppTheme.error.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPrayerItem(TimelineItem item) {
    final now = DateTime.now();
    final isPast = _isSameDay(_selectedDate, now) && item.endTime!.isBefore(now);
    final isActive = _isSameDay(_selectedDate, now) && 
                     now.isAfter(item.time) && 
                     now.isBefore(item.endTime!);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _showPrayerDetails(item, canEdit: !isPast),
        onLongPress: isPast ? null : () => _editPrayerSettings(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive
                ? item.color!.withValues(alpha: 0.25)
                : isPast 
                    ? item.color!.withValues(alpha: 0.1)
                    : item.color!.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? item.color!
                  : item.color!.withValues(alpha: isPast ? 0.3 : 0.5),
              width: isActive ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.color!.withValues(alpha: isPast ? 0.3 : 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTheme.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isPast 
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${DateFormat('h:mm a').format(item.time)} - ${DateFormat('h:mm a').format(item.endTime!)}',
                          style: AppTheme.bodySmall.copyWith(
                            color: isPast 
                                ? AppTheme.textSecondary.withValues(alpha: 0.7)
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (item.actualPrayerTime != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Iqama: ${DateFormat('h:mm a').format(item.actualPrayerTime!)}',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'NOW',
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                )
              else if (isPast)
                Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTaskItem(TimelineItem item) {
    final now = DateTime.now();
    final isPast = _isSameDay(_selectedDate, now) && item.time.isBefore(now);
    final isCompleted = item.task?.isCompleted ?? false;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _showTaskDetails(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.borderLight,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.color!.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.icon,
                  color: item.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTheme.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted || isPast
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.endTime != null
                              ? '${DateFormat('h:mm a').format(item.time)} - ${DateFormat('h:mm a').format(item.endTime!)}'
                              : DateFormat('h:mm a').format(item.time),
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (item.description != null && item.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary.withValues(alpha: 0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: isPast ? null : () => _toggleTaskComplete(item),
                icon: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: isCompleted
                      ? AppTheme.success
                      : isPast 
                          ? AppTheme.textSecondary.withValues(alpha: 0.5)
                          : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null && !_isSameDay(date, _selectedDate)) {
      setState(() {
        _selectedDate = date;
        _loadData();
      });
    }
  }
  
  Widget _buildFreeTimeItem(TimelineItem item) {
    final now = DateTime.now();
    final isPast = _isSameDay(_selectedDate, now) && item.endTime!.isBefore(now);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: isPast ? null : () => _createTaskInFreeTime(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isPast 
                ? AppTheme.surface.withValues(alpha: 0.5)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPast 
                  ? AppTheme.textTertiary.withValues(alpha: 0.2)
                  : AppTheme.success.withValues(alpha: 0.3),
              width: 1,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPast 
                      ? AppTheme.textTertiary.withValues(alpha: 0.1)
                      : AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.icon,
                  color: isPast 
                      ? AppTheme.textTertiary
                      : AppTheme.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTheme.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isPast 
                            ? AppTheme.textTertiary
                            : AppTheme.success,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 12,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${DateFormat('h:mm a').format(item.time)} - ${DateFormat('h:mm a').format(item.endTime!)}',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (item.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.description!,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.add_circle_outline_rounded,
                color: isPast ? AppTheme.textSecondary.withValues(alpha: 0.5) : AppTheme.success,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrayerDetails(TimelineItem item, {bool canEdit = true}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: item.color!.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.icon,
                      color: item.color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppTheme.headlineSmall.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Prayer Time',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: item.color!.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.color!.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.timer_rounded,
                          color: item.color,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Duration',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${DateFormat('h:mm a').format(item.time)} - ${DateFormat('h:mm a').format(item.endTime!)}',
                          style: AppTheme.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: item.color,
                          ),
                        ),
                      ],
                    ),
                    if (item.actualPrayerTime != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            color: item.color,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Iqama Time',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            DateFormat('h:mm a').format(item.actualPrayerTime!),
                            style: AppTheme.titleSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: item.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _editPrayerSettings(item);
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit Prayer Settings'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showTaskDetails(TimelineItem item) {
    if (item.task == null) return;
    
    showDialog(
      context: context,
      builder: (context) => TaskDetailsDialog(
        task: item.task,
        cachedPrayerTimes: _prayerTimes,
        onEdit: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditItemScreen(
                task: item.task,
                prayerTimes: _prayerTimes,
              ),
            ),
          );
          if (result == true) {
            await _loadData();
          }
        },
        onDelete: () async {
          await TodoService.deleteTask(item.task!.id);
          await _loadData();
        },
        onToggleComplete: () => _toggleTaskComplete(item),
      ),
    );
  }
  
  void _showTaskDetailsOld(TimelineItem item) {
    if (item.task == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: item.color!.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.icon,
                      color: item.color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: AppTheme.headlineSmall.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Task',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (item.description != null) ...[
                const SizedBox(height: 16),
                Text(
                  item.description!,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: item.color!.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.color!.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: item.color,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Scheduled',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item.endTime != null
                          ? '${DateFormat('h:mm a').format(item.time)} - ${DateFormat('h:mm a').format(item.endTime!)}'
                          : DateFormat('h:mm a').format(item.time),
                      style: AppTheme.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: item.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _editTask(item);
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _toggleTaskComplete(item);
                      },
                      icon: Icon(
                        item.task!.isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                      ),
                      label: Text(
                        item.task!.isCompleted ? 'Completed' : 'Complete',
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _toggleTaskComplete(TimelineItem item) async {
    if (item.task != null) {
      await TodoService.toggleTaskStatus(item.task!);
      _loadData();
    }
  }
  
  void _editTask(TimelineItem item) async {
    if (item.task == null) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditItemScreen(
          task: item.task,
          prayerTimes: _prayerTimes,
        ),
      ),
    );
    
    if (result == true) {
      _loadData();
    }
  }
  
  void _createTaskInFreeTime(TimelineItem item) async {
    if (item.freeSlot == null) return;
    
    // Navigate to add task screen with pre-filled time
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditItemScreen(
          task: null, // Pass null for new task
          prayerTimes: _prayerTimes,
          initialTime: item.freeSlot!.startTime,
          initialEndTime: item.freeSlot!.endTime,
        ),
      ),
    );
    
    if (result == true) {
      _loadData();
    }
  }
  
  void _editPrayerSettings(TimelineItem item) async {
    if (item.prayerBlock == null) return;
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrayerSettingsScreen(
          initialPrayer: item.prayerBlock!.prayer,
          singlePrayerMode: true,
          specificDate: _selectedDate,
        ),
      ),
    );
    _loadData();
  }
  
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
  
  Color _getTaskColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return AppTheme.error;
      case TaskPriority.medium:
        return AppTheme.warning;
      case TaskPriority.low:
        return AppTheme.success;
    }
  }
}

// Timeline item types
enum TimelineItemType {
  section,
  timeMarker,
  currentTime,
  prayer,
  task,
  freeTime,
}

// Timeline item model
class TimelineItem {
  final TimelineItemType type;
  final String title;
  final String? description;
  final DateTime time;
  final DateTime? endTime;
  final DateTime? actualPrayerTime;
  final Color? color;
  final IconData? icon;
  final Task? task;
  final PrayerTimeBlock? prayerBlock;
  final FreeTimeSlot? freeSlot;
  
  TimelineItem({
    required this.type,
    required this.title,
    this.description,
    required this.time,
    this.endTime,
    this.actualPrayerTime,
    this.color,
    this.icon,
    this.task,
    this.prayerBlock,
    this.freeSlot,
  });
}

// Dialog for adjusting prayer slot duration
class _PrayerSlotAdjustmentDialog extends StatefulWidget {
  final String prayerName;
  final DateTime prayerTime;
  final DateTime currentStartTime;
  final DateTime currentEndTime;
  
  const _PrayerSlotAdjustmentDialog({
    required this.prayerName,
    required this.prayerTime,
    required this.currentStartTime,
    required this.currentEndTime,
  });
  
  @override
  State<_PrayerSlotAdjustmentDialog> createState() => _PrayerSlotAdjustmentDialogState();
}

class _PrayerSlotAdjustmentDialogState extends State<_PrayerSlotAdjustmentDialog> {
  late int minutesBefore;
  late int minutesAfter;
  
  @override
  void initState() {
    super.initState();
    // Calculate current minutes before and after
    minutesBefore = widget.prayerTime.difference(widget.currentStartTime).inMinutes;
    minutesAfter = widget.currentEndTime.difference(widget.prayerTime).inMinutes;
  }
  
  @override
  Widget build(BuildContext context) {
    final newStartTime = widget.prayerTime.subtract(Duration(minutes: minutesBefore));
    final newEndTime = widget.prayerTime.add(Duration(minutes: minutesAfter));
    
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Adjust ${widget.prayerName} Slot'),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, MMM d').format(widget.prayerTime),
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Prayer time info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.mosque, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Iqama: ${DateFormat('h:mm a').format(widget.prayerTime)}',
                  style: AppTheme.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Minutes before
          Row(
            children: [
              Expanded(
                child: Text(
                  'Start before Iqama:',
                  style: AppTheme.bodyMedium,
                ),
              ),
              IconButton(
                onPressed: minutesBefore > 0 ? () {
                  setState(() {
                    minutesBefore = (minutesBefore - 1).clamp(0, 120);
                  });
                } : null,
                icon: const Icon(Icons.remove),
                iconSize: 20,
              ),
              InkWell(
                onTap: () async {
                  final result = await _showMinuteInputDialog(
                    context,
                    'Minutes before Iqama',
                    minutesBefore,
                  );
                  if (result != null) {
                    setState(() {
                      minutesBefore = result.clamp(0, 120);
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primary),
                    borderRadius: BorderRadius.circular(4),
                    color: AppTheme.primary.withValues(alpha: 0.05),
                  ),
                  child: Text(
                    '$minutesBefore min',
                    style: AppTheme.titleSmall.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    minutesBefore = (minutesBefore + 1).clamp(0, 120);
                  });
                },
                icon: const Icon(Icons.add),
                iconSize: 20,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Minutes after
          Row(
            children: [
              Expanded(
                child: Text(
                  'End after Iqama:',
                  style: AppTheme.bodyMedium,
                ),
              ),
              IconButton(
                onPressed: minutesAfter > 0 ? () {
                  setState(() {
                    minutesAfter = (minutesAfter - 1).clamp(0, 120);
                  });
                } : null,
                icon: const Icon(Icons.remove),
                iconSize: 20,
              ),
              InkWell(
                onTap: () async {
                  final result = await _showMinuteInputDialog(
                    context,
                    'Minutes after Iqama',
                    minutesAfter,
                  );
                  if (result != null) {
                    setState(() {
                      minutesAfter = result.clamp(0, 120);
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primary),
                    borderRadius: BorderRadius.circular(4),
                    color: AppTheme.primary.withValues(alpha: 0.05),
                  ),
                  child: Text(
                    '$minutesAfter min',
                    style: AppTheme.titleSmall.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    minutesAfter = (minutesAfter + 1).clamp(0, 120);
                  });
                },
                icon: const Icon(Icons.add),
                iconSize: 20,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Time range preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${DateFormat('h:mm a').format(newStartTime)} - ${DateFormat('h:mm a').format(newEndTime)}',
                    style: AppTheme.titleSmall.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'minutesBefore': minutesBefore,
              'minutesAfter': minutesAfter,
            });
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
  
  Future<int?> _showMinuteInputDialog(BuildContext context, String title, int currentValue) async {
    final controller = TextEditingController(text: currentValue.toString());
    
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter minutes (0-120)',
            border: OutlineInputBorder(),
            suffix: Text('min'),
          ),
          autofocus: true,
          onSubmitted: (value) {
            final minutes = int.tryParse(value);
            Navigator.pop(context, minutes);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final minutes = int.tryParse(controller.text);
              Navigator.pop(context, minutes);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}