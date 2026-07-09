import 'dart:async';
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
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Start timer to refresh timeline every minute
    _startTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startTimer() {
    // Refresh timeline every minute to update NOW marker and free time
    // splits. A periodic timer keeps ticking regardless of which date is
    // being viewed, so the NOW marker resumes when the user returns to today.
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      if (_isSameDay(_selectedDate, DateTime.now())) {
        setState(() {
          _buildTimelineItems();
        });
      }
    });
  }
  
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      _prayerTimes = await PrayerTimeService.getPrayerTimes(date: _selectedDate);
      
      // Get all tasks and filter for selected date
      final allTasks = await TodoService.getAllTasks();
      final selectedDateTasks = allTasks.where((task) {
        // Check if task has scheduling info
        if (task.scheduleType == ScheduleType.absolute && task.absoluteTime == null) {
          return false;
        }

        if (task.scheduleType == ScheduleType.prayerRelative && task.relatedPrayer == null) {
          return false;
        }

        // Only show tasks scheduled for the selected date. Completed
        // tasks stay visible (with completed styling) so users can see
        // what they've done.
        return task.shouldShowOnDate(_selectedDate);
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
      _freeTimeSlots =
          await PrayerDurationService.getFreeTimesForDate(_selectedDate, _todayTasks);

      _buildTimelineItems();

      // Scroll to current time after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToNow();
      });
    } catch (e) {
      debugPrint('Error loading timeline: $e');
    }

    if (!mounted) return;
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
            color: AppTheme.textTertiaryColor(context).withValues(alpha: 0.3),
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
                ? AppTheme.textTertiaryColor(context).withValues(alpha: 0.3)
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
      backgroundColor: AppTheme.backgroundColor(context),
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
      color: AppTheme.surfaceColor(context),
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
                      color: isToday ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.backgroundColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isToday ? AppTheme.primary : AppTheme.borderColor(context),
                        width: isToday ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: isToday ? AppTheme.primary : AppTheme.textSecondaryColor(context),
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
                                  color: isToday ? AppTheme.primary : AppTheme.textPrimaryColor(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('MMMM d, yyyy').format(_selectedDate),
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondaryColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppTheme.textSecondaryColor(context),
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
                          foregroundColor: _showPrayerTimes ? AppTheme.primary : AppTheme.textSecondaryColor(context),
                          side: BorderSide(
                            color: _showPrayerTimes ? AppTheme.primary : AppTheme.borderColor(context),
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
                          foregroundColor: _showFreeTime ? AppTheme.success : AppTheme.textSecondaryColor(context),
                          side: BorderSide(
                            color: _showFreeTime ? AppTheme.success : AppTheme.borderColor(context),
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
      final isToday = _isSameDay(_selectedDate, DateTime.now());
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 64,
              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              isToday
                  ? 'No events today'
                  : 'No events on ${DateFormat('EEE, MMM d').format(_selectedDate)}',
              style: AppTheme.titleMedium.copyWith(
                color: AppTheme.textSecondaryColor(context),
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
          color: AppTheme.textPrimaryColor(context),
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
                color: AppTheme.textSecondaryColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: AppTheme.borderColor(context),
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
                            ? AppTheme.textSecondaryColor(context)
                            : AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${DateFormat('h:mm a').format(item.time)} - ${DateFormat('h:mm a').format(item.endTime!)}',
                          style: AppTheme.bodySmall.copyWith(
                            color: isPast
                                ? AppTheme.textSecondaryColor(context).withValues(alpha: 0.7)
                                : AppTheme.textSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                    if (item.actualPrayerTime != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Iqama: ${DateFormat('h:mm a').format(item.actualPrayerTime!)}',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
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
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.5),
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
    final isCompleted = _isTaskCompleted(item.task);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _showTaskDetails(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.borderColor(context),
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
                            ? AppTheme.textSecondaryColor(context)
                            : AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.endTime != null
                              ? '${DateFormat('h:mm a').format(item.time)} - ${DateFormat('h:mm a').format(item.endTime!)}'
                              : DateFormat('h:mm a').format(item.time),
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                    if (item.description != null && item.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                // Past tasks can (and usually are) checked off after the fact
                onPressed: () => _toggleTaskComplete(item),
                icon: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: isCompleted
                      ? AppTheme.success
                      : isPast
                          ? AppTheme.textSecondaryColor(context).withValues(alpha: 0.5)
                          : AppTheme.textSecondaryColor(context),
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
    
    if (date != null && mounted && !_isSameDay(date, _selectedDate)) {
      setState(() {
        _selectedDate = date;
      });
      _loadData();
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
                ? AppTheme.surfaceColor(context).withValues(alpha: 0.5)
                : AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPast
                  ? AppTheme.textTertiaryColor(context).withValues(alpha: 0.2)
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
                      ? AppTheme.textTertiaryColor(context).withValues(alpha: 0.1)
                      : AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.icon,
                  color: isPast
                      ? AppTheme.textTertiaryColor(context)
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
                            ? AppTheme.textTertiaryColor(context)
                            : AppTheme.success,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 12,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${DateFormat('h:mm a').format(item.time)} - ${DateFormat('h:mm a').format(item.endTime!)}',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                    if (item.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.description!,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.add_circle_outline_rounded,
                color: isPast ? AppTheme.textSecondaryColor(context).withValues(alpha: 0.5) : AppTheme.success,
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
      backgroundColor: AppTheme.surfaceColor(context),
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
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Prayer Time',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondaryColor(context),
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
                            color: AppTheme.textPrimaryColor(context),
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
                              color: AppTheme.textPrimaryColor(context),
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
        completionDate: _selectedDate,
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
  
  
  /// Completion state for the currently selected date. One-time tasks use
  /// the global flag; recurring tasks are completed per date.
  bool _isTaskCompleted(Task? task) {
    if (task == null) return false;
    if (task.recurrence == TaskRecurrence.once) {
      return task.isCompleted || task.isCompletedForDate(_selectedDate);
    }
    return task.isCompletedForDate(_selectedDate);
  }

  void _toggleTaskComplete(TimelineItem item) async {
    final task = item.task;
    if (task == null) return;

    if (task.recurrence == TaskRecurrence.once) {
      await TodoService.toggleTaskStatus(task);
    } else if (task.isCompletedForDate(_selectedDate)) {
      await TodoService.unmarkTaskCompleted(task.id, _selectedDate);
    } else {
      await TodoService.markTaskCompleted(task.id, _selectedDate);
    }

    if (!mounted) return;
    _loadData();
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
