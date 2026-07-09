import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/space.dart';
import '../core/services/todo_service.dart';
import '../core/services/prayer_time_service.dart';
import '../core/services/space_service.dart';
import '../core/services/task_filter_service.dart';
import '../core/theme/app_theme.dart';
import '../widgets/task_filter_dialog.dart';
import '../widgets/task_details_dialog.dart';
import 'add_edit_item_screen.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  List<TaskWithTime> _allTasks = [];
  List<TaskWithTime> _filteredTasks = [];
  Map<String, String> _prayerTimes = {};
  List<Space> _spaces = [];
  bool _isLoading = true;
  
  TaskFilterOptions _filterOptions = TaskFilterOptions();
  String _searchQuery = '';
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      // If filtering by specific date, get prayer times for that date
      if (_filterOptions.specificDate != null) {
        _prayerTimes = await PrayerTimeService.getPrayerTimes(date: _filterOptions.specificDate);
      } else {
        // Otherwise get today's prayer times
        _prayerTimes = await PrayerTimeService.getPrayerTimes();
      }
      
      _allTasks = await TodoService.getAllTasksWithTimes(_prayerTimes);
      _spaces = await SpaceService.getAllSpaces();
      _applyFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading activities: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredTasks = _allTasks.where((taskWithTime) {
        final task = taskWithTime.task;
        final today = DateTime.now();
        final taskDate = taskWithTime.scheduledTime;
        
        // Apply date filter
        if (_filterOptions.specificDate != null) {
          if (!_isSameDay(taskDate, _filterOptions.specificDate!)) {
            return false;
          }
        } else if (_filterOptions.startDate != null && _filterOptions.endDate != null) {
          if (taskDate.isBefore(_filterOptions.startDate!) || 
              taskDate.isAfter(_filterOptions.endDate!.add(const Duration(days: 1)))) {
            return false;
          }
        }
        
        // Apply status filters
        if (_filterOptions.statuses.isNotEmpty) {
          bool matchesStatus = false;
          
          for (final status in _filterOptions.statuses) {
            switch (status) {
              case TaskStatus.all:
                matchesStatus = true;
                break;
              case TaskStatus.today:
                if (_isSameDay(taskDate, today)) {
                  matchesStatus = true;
                }
                break;
              case TaskStatus.upcoming:
                if (taskDate.isAfter(today)) {
                  matchesStatus = true;
                }
                break;
              case TaskStatus.completed:
                // Completed on the task's own scheduled date, not today
                if (task.isCompletedForDate(taskDate)) {
                  matchesStatus = true;
                }
                break;
              case TaskStatus.missed:
                // Missed: the whole scheduled day has passed without completion
                final startOfToday = DateTime(today.year, today.month, today.day);
                if (taskDate.isBefore(startOfToday) &&
                    !task.isCompletedForDate(taskDate)) {
                  matchesStatus = true;
                }
                break;
              case TaskStatus.overdue:
                // Overdue: due before now (including earlier today) and incomplete
                if (taskDate.isBefore(today) &&
                    !task.isCompletedForDate(taskDate)) {
                  matchesStatus = true;
                }
                break;
              case TaskStatus.old:
                if (taskDate.isBefore(today.subtract(const Duration(days: 30)))) {
                  matchesStatus = true;
                }
                break;
            }
            
            if (matchesStatus) break;
          }
          
          if (!matchesStatus) return false;
        }
        
        // Apply priority filter
        if (_filterOptions.priorities.isNotEmpty && 
            !_filterOptions.priorities.contains(task.priority)) {
          return false;
        }
        
        // Note: Space filtering would need task metadata or EnhancedTask support
        // For now, we skip space filtering for regular tasks
        
        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          return task.title.toLowerCase().contains(query) ||
                 (task.description?.toLowerCase().contains(query) ?? false);
        }
        
        return true;
      }).toList();
      
      // Sort by time
      _filteredTasks.sort(
        (a, b) => a.scheduledTime.compareTo(b.scheduledTime),
      );
    });
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// Completion state for the card's own scheduled date. One-time tasks
  /// also honor the global flag; recurring tasks are completed per date.
  bool _isTaskCompleted(TaskWithTime taskWithTime) {
    final task = taskWithTime.task;
    if (task.recurrence == TaskRecurrence.once) {
      return task.isCompleted ||
          task.isCompletedForDate(taskWithTime.scheduledTime);
    }
    return task.isCompletedForDate(taskWithTime.scheduledTime);
  }

  Future<void> _toggleTaskCompletion(TaskWithTime taskWithTime) async {
    final task = taskWithTime.task;
    // Complete for the card's own scheduled date, not always today
    final date = taskWithTime.scheduledTime;

    try {
      if (_isTaskCompleted(taskWithTime)) {
        await TodoService.unmarkTaskCompleted(task.id, date);
      } else {
        await TodoService.markTaskCompleted(task.id, date);
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating activity: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteTask(String taskId) async {
    try {
      await TodoService.deleteTask(taskId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity deleted'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting activity: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: _buildTasksList(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditItemScreen(prayerTimes: _prayerTimes),
            ),
          );
          if (result == true) {
            await _loadData();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Activity'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activities',
                style: AppTheme.headlineLarge.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(AppTheme.space8),
                  decoration: BoxDecoration(
                    color: _filterOptions.hasActiveFilters
                        ? AppTheme.primary.withValues(alpha: 0.1)
                        : AppTheme.surfaceVariantColor(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Stack(
                    children: [
                      Icon(
                        Icons.filter_list,
                        color: _filterOptions.hasActiveFilters
                            ? AppTheme.primary
                            : AppTheme.textSecondaryColor(context),
                      ),
                      if (_filterOptions.hasActiveFilters)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                onPressed: _showFilterDialog,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search activities...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _applyFilters();
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilters();
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    final result = await showDialog<TaskFilterOptions>(
      context: context,
      builder: (context) => TaskFilterDialog(
        initialFilters: _filterOptions,
        availableSpaces: _spaces,
      ),
    );
    
    if (result != null && mounted) {
      setState(() {
        _filterOptions = result;
        _applyFilters();
      });
    }
  }

  Widget _buildTasksList() {
    if (_filteredTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt,
              size: 64,
              color: AppTheme.textTertiaryColor(context),
            ),
            const SizedBox(height: AppTheme.space16),
            Text(
              'No activities found',
              style: AppTheme.titleLarge.copyWith(
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search'
                  : 'Create your first activity',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textTertiaryColor(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.space16),
      itemCount: _filteredTasks.length,
      itemBuilder: (context, index) {
        final taskWithTime = _filteredTasks[index];
        return _buildTaskCard(taskWithTime);
      },
    );
  }

  Widget _buildTaskCard(TaskWithTime taskWithTime) {
    final task = taskWithTime.task;
    final time = taskWithTime.scheduledTime;
    final isCompleted = _isTaskCompleted(taskWithTime);
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space12),
      decoration: AppTheme.cardDecorationFor(context),
      child: Dismissible(
        key: Key(task.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppTheme.space20),
          decoration: BoxDecoration(
            color: AppTheme.error,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: const Icon(
            Icons.delete_outline,
            color: Colors.white,
            size: 28,
          ),
        ),
        confirmDismiss: (direction) async {
          return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Activity'),
              content: const Text('Are you sure you want to delete this activity?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
        },
        onDismissed: (direction) => _deleteTask(task.id),
        child: InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => TaskDetailsDialog(
                task: task,
                cachedPrayerTimes: _prayerTimes,
                completionDate: taskWithTime.scheduledTime,
                onEdit: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditItemScreen(task: task, prayerTimes: _prayerTimes),
                    ),
                  );
                  if (result == true) {
                    await _loadData();
                  }
                },
                onDelete: () => _deleteTask(task.id),
                onToggleComplete: () => _toggleTaskCompletion(taskWithTime),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: Row(
              children: [
                Checkbox(
                  value: isCompleted,
                  onChanged: (value) => _toggleTaskCompletion(taskWithTime),
                  activeColor: AppTheme.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: AppTheme.titleMedium.copyWith(
                                color: isCompleted
                                    ? AppTheme.textTertiaryColor(context)
                                    : AppTheme.textPrimaryColor(context),
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.space8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.space8,
                              vertical: AppTheme.space4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.task_alt,
                                  size: 14,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: AppTheme.space4),
                                Text(
                                  'Task',
                                  style: AppTheme.labelSmall.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (task.description != null && task.description!.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          task.description!,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondaryColor(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppTheme.space8),
                      Row(
                        children: [
                          // Date display
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.space8,
                              vertical: AppTheme.space4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceVariantColor(context),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: AppTheme.textSecondaryColor(context),
                                ),
                                const SizedBox(width: AppTheme.space4),
                                Text(
                                  DateFormat('MMM d, yyyy').format(time),
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondaryColor(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppTheme.space8),
                          // Time display
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: AppTheme.textTertiaryColor(context),
                          ),
                          const SizedBox(width: AppTheme.space4),
                          Text(
                            taskWithTime.endTime != null
                                    ? '${DateFormat('h:mm a').format(taskWithTime.scheduledTime)} - ${DateFormat('h:mm a').format(taskWithTime.endTime!)}'
                                    : DateFormat('h:mm a').format(time),
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textTertiaryColor(context),
                            ),
                          ),
                          const Spacer(),
                          if (task.recurrence != TaskRecurrence.once) ...[
                            Icon(
                              Icons.repeat,
                              size: 16,
                              color: AppTheme.textTertiaryColor(context),
                            ),
                            const SizedBox(width: AppTheme.space4),
                            Text(
                              task.recurrence.name,
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textTertiaryColor(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space8,
                    vertical: AppTheme.space4,
                  ),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(task.priority).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    Icons.flag,
                    size: 16,
                    color: _getPriorityColor(task.priority),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return AppTheme.error;
      case TaskPriority.medium:
        return AppTheme.warning;
      case TaskPriority.low:
        return AppTheme.success;
    }
  }

  // TODO: Implement ActivityType support - currently Task model doesn't have activityType field
  // Color _getActivityTypeColor(ActivityType type) {
  //   switch (type) {
  //     case ActivityType.work:
  //       return AppTheme.info;
  //     case ActivityType.personal:
  //       return AppTheme.success;
  //     case ActivityType.event:
  //       return AppTheme.error;
  //     default:
  //       return AppTheme.primary;
  //   }
  // }

  // IconData _getActivityTypeIcon(ActivityType type) {
  //   switch (type) {
  //     case ActivityType.work:
  //       return Icons.work_outline;
  //     case ActivityType.personal:
  //       return Icons.person_outline;
  //     case ActivityType.event:
  //       return Icons.event;
  //     default:
  //       return Icons.task_alt;
  //   }
  // }

  // String _getActivityTypeLabel(ActivityType type) {
  //   switch (type) {
  //     case ActivityType.work:
  //       return 'Work';
  //     case ActivityType.personal:
  //       return 'Personal';
  //     case ActivityType.event:
  //       return 'Event';
  //     default:
  //       return 'Task';
  //   }
  // }
}