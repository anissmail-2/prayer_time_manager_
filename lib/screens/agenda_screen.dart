import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
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

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  // Filtered tasks from service
  List<TaskWithTime> _filteredTasks = [];
  Map<String, String> _prayerTimes = {};
  List<Space> _spaces = [];
  
  // Filter and sort state
  TaskFilterOptions _filterOptions = TaskFilterOptions();
  SortOption? _currentSort;
  
  // Pagination state
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  
  // UI state
  bool _isLoading = true;
  String? _errorMessage;
  
  // Search with debouncing
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;

  // Scroll controller for infinite scrolling
  final ScrollController _scrollController = ScrollController();

  // Undo delete state
  Task? _lastDeletedTask;
  int? _lastDeletedIndex;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadLastFilter();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreTasks();
      }
    });
  }

  Future<void> _loadLastFilter() async {
    final lastFilter = await TaskFilterService.loadLastFilter();
    if (lastFilter != null && mounted) {
      setState(() {
        _filterOptions = lastFilter;
      });
      await _loadData();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load today's prayer times for new task creation
      _prayerTimes = await PrayerTimeService.getPrayerTimes();
      
      // Load spaces for filtering
      _spaces = await SpaceService.getAllSpaces();
      
      // Load initial page of tasks
      await _loadData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading data: $e';
        });
      }
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData({bool resetPage = true}) async {
    if (resetPage) {
      setState(() {
        _currentPage = 0;
        _filteredTasks.clear();
        _hasMore = true;
      });
    }
    
    try {
      final result = await TaskFilterService.loadFilteredTasks(
        filters: _filterOptions,
        page: _currentPage,
        sortOption: _currentSort,
      );
      
      if (mounted) {
        setState(() {
          if (resetPage) {
            _filteredTasks = result.tasks;
          } else {
            _filteredTasks.addAll(result.tasks);
          }
          _hasMore = result.hasMore;
          _errorMessage = result.error;
        });
      }
      
      // Save filter for next time
      await TaskFilterService.saveLastFilter(_filterOptions);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading tasks: $e';
        });
      }
    }
  }

  Future<void> _loadMoreTasks() async {
    if (!_hasMore || _isLoadingMore) return;
    
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    
    await _loadData(resetPage: false);
    
    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    // Cancel previous timer
    _searchDebounceTimer?.cancel();
    
    // Start new timer
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _filterOptions.searchQuery = value;
      });
      _loadData();
    });
  }

  Future<void> _toggleTaskCompletion(TaskWithTime taskWithTime) async {
    final task = taskWithTime.task;
    final today = DateTime.now();
    
    try {
      if (task.isCompletedForDate(today)) {
        await TodoService.unmarkTaskCompleted(task.id, today);
      } else {
        await TodoService.markTaskCompleted(task.id, today);
      }
      
      // Update task in list without full reload
      final index = _filteredTasks.indexWhere((t) => t.task.id == task.id);
      if (index != -1 && mounted) {
        setState(() {
          // Refresh the specific task
          _filteredTasks[index] = TaskWithTime(
            task: task,
            scheduledTime: taskWithTime.scheduledTime,
            endTime: taskWithTime.endTime,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating item: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteTask(String taskId) async {
    try {
      // Store the task and its position for undo
      final index = _filteredTasks.indexWhere((t) => t.task.id == taskId);
      if (index == -1) return;

      final deletedTaskWithTime = _filteredTasks[index];
      _lastDeletedTask = deletedTaskWithTime.task;
      _lastDeletedIndex = index;

      // Delete from service
      await TodoService.deleteTask(taskId);

      // Remove from list
      if (mounted) {
        setState(() {
          _filteredTasks.removeAt(index);
        });

        // Show snackbar with undo option
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task deleted'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () async {
                // Restore the deleted task
                if (_lastDeletedTask != null) {
                  await TodoService.addTask(_lastDeletedTask!);
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Task restored'),
                        backgroundColor: AppTheme.success,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting item: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _exportTasks() async {
    try {
      final csv = TaskFilterService.exportToCSV(_filteredTasks);
      
      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: csv));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tasks exported to clipboard'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
      
      // On desktop, also save to file
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // Implement file save dialog for desktop platforms
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting tasks: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Column(
        children: [
          _buildHeader(),
          if (_errorMessage != null)
            _buildErrorBanner(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadInitialData,
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
        label: const Text('New Item'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  Widget _buildHeader() {
    final hasActiveFilters = _filterOptions.hasActiveFilters;
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.space24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agenda',
                    style: AppTheme.headlineLarge.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (!hasActiveFilters)
                    Text(
                      DateFormat('EEEE, MMM d').format(DateTime.now()),
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    )
                  else
                    Text(
                      '${_filteredTasks.length} items',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primary,
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  // Sort indicator
                  if (_currentSort != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space8,
                        vertical: AppTheme.space4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _currentSort!.ascending 
                                ? Icons.arrow_upward 
                                : Icons.arrow_downward,
                            size: 14,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: AppTheme.space4),
                          Text(
                            _currentSort!.field.name,
                            style: AppTheme.labelSmall.copyWith(
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: AppTheme.space8),
                  // Filter button
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(AppTheme.space8),
                      decoration: BoxDecoration(
                        color: hasActiveFilters
                            ? AppTheme.primary.withOpacity(0.1)
                            : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Stack(
                        children: [
                          Icon(
                            Icons.filter_list,
                            color: hasActiveFilters
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                          if (hasActiveFilters)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
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
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          // Enhanced search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search tasks, spaces, or tags...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tag search toggle
                        IconButton(
                          icon: Icon(
                            Icons.tag,
                            color: _filterOptions.searchInTags
                                ? AppTheme.primary
                                : AppTheme.textTertiary,
                          ),
                          tooltip: 'Search in tags',
                          onPressed: () {
                            setState(() {
                              _filterOptions.searchInTags = !_filterOptions.searchInTags;
                            });
                            _loadData();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _filterOptions.searchQuery = '';
                            });
                            _loadData();
                          },
                        ),
                      ],
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.surfaceVariant.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space12),
      color: AppTheme.error.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.error),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TaskFilterDialog(
        initialFilters: _filterOptions,
        availableSpaces: _spaces,
        currentSort: _currentSort,
      ),
    );
    
    if (result != null) {
      if (result['export'] == true) {
        await _exportTasks();
      } else {
        setState(() {
          _filterOptions = result['filters'] as TaskFilterOptions;
          _currentSort = result['sort'] as SortOption?;
        });
        await _loadData();
      }
    }
  }

  Widget _buildTasksList() {
    if (_filteredTasks.isEmpty && !_isLoadingMore) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note,
              size: 64,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: AppTheme.space16),
            Text(
              'No items found',
              style: AppTheme.titleLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              _filterOptions.searchQuery.isNotEmpty
                  ? 'Try adjusting your search'
                  : _filterOptions.hasActiveFilters
                      ? 'Try adjusting your filters'
                      : 'Create your first item',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textTertiary,
              ),
            ),
            if (_filterOptions.hasActiveFilters) ...[
              const SizedBox(height: AppTheme.space16),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _filterOptions = TaskFilterOptions();
                    _searchController.clear();
                  });
                  _loadData();
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppTheme.space16),
      itemCount: _filteredTasks.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _filteredTasks.length) {
          return const Padding(
            padding: EdgeInsets.all(AppTheme.space16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        final taskWithTime = _filteredTasks[index];
        return _buildTaskCard(taskWithTime);
      },
    );
  }

  Widget _buildTaskCard(TaskWithTime taskWithTime) {
    final task = taskWithTime.task;
    final time = taskWithTime.scheduledTime;
    final isCompleted = task.isCompletedForDate(DateTime.now());
    
    // Extract space info
    final spaceId = _extractSpaceId(task.description ?? '');
    final space = spaceId != null 
        ? _spaces.firstWhere((s) => s.id == spaceId, orElse: () => _spaces.first)
        : null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space12),
      decoration: AppTheme.cardDecoration(),
      child: Dismissible(
        key: Key(task.id),
        direction: DismissDirection.horizontal, // Allow both directions
        // Background for swipe right (complete)
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: AppTheme.space20),
          decoration: BoxDecoration(
            color: isCompleted ? AppTheme.warning : AppTheme.success,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Icon(
            isCompleted ? Icons.restart_alt : Icons.check_circle_outline,
            color: Colors.white,
            size: 28,
          ),
        ),
        // Secondary background for swipe left (delete)
        secondaryBackground: Container(
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
          if (direction == DismissDirection.startToEnd) {
            // Swipe right - toggle completion
            _toggleTaskCompletion(taskWithTime);
            return false; // Don't dismiss
          } else {
            // Swipe left - delete
            return await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Item'),
                content: const Text('Are you sure you want to delete this item?'),
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
          }
        },
        onDismissed: (direction) {
          if (direction == DismissDirection.endToStart) {
            _deleteTask(task.id);
          }
        },
        child: InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => TaskDetailsDialog(
                task: task,
                cachedPrayerTimes: _prayerTimes,
                onEdit: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditItemScreen(
                        task: task,
                        prayerTimes: _prayerTimes,
                      ),
                    ),
                  );
                  if (result == true) {
                    await _loadData();
                  }
                },
                onDuplicate: () async {
                  await TodoService.duplicateTask(task);
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Task duplicated successfully'),
                        backgroundColor: AppTheme.success,
                        duration: Duration(seconds: 2),
                      ),
                    );
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
                // Checkbox with animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: Checkbox(
                    value: isCompleted,
                    onChanged: (value) => _toggleTaskCompletion(taskWithTime),
                    activeColor: AppTheme.success,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: AppTheme.titleMedium.copyWith(
                          color: isCompleted
                              ? AppTheme.textTertiary
                              : AppTheme.textPrimary,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (task.description != null && task.description!.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          task.description!.replaceAll(RegExp(r'#\w+'), '').trim(),
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppTheme.space8),
                      Wrap(
                        spacing: AppTheme.space8,
                        runSpacing: AppTheme.space4,
                        children: [
                          // Date display
                          _buildChip(
                            icon: Icons.calendar_today,
                            label: DateFormat('MMM d').format(time),
                            color: AppTheme.textSecondary,
                          ),
                          // Time display
                          _buildChip(
                            icon: Icons.schedule,
                            label: taskWithTime.endTime != null
                                    ? '${DateFormat('h:mm a').format(time)} - ${DateFormat('h:mm a').format(taskWithTime.endTime!)}'
                                    : DateFormat('h:mm a').format(time),
                            color: AppTheme.textSecondary,
                          ),
                          // Space indicator
                          if (space != null)
                            _buildChip(
                              icon: Icons.folder,
                              label: space.name,
                              color: _getSpaceColor(space.color),
                            ),
                          // Recurrence indicator
                          if (task.recurrence != TaskRecurrence.once)
                            _buildChip(
                              icon: Icons.repeat,
                              label: task.recurrence.name,
                              color: AppTheme.secondary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                // Right side indicators
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Priority indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space8,
                        vertical: AppTheme.space4,
                      ),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(task.priority),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Text(
                        _getPriorityLabel(task.priority),
                        style: AppTheme.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space8),
                    // Item type indicator
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space6),
                      decoration: BoxDecoration(
                        color: _getItemTypeColor(task.itemType).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getItemTypeIcon(task.itemType),
                        size: 14,
                        color: _getItemTypeColor(task.itemType),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space8,
        vertical: AppTheme.space4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppTheme.space4),
          Text(
            label,
            style: AppTheme.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String? _extractSpaceId(String description) {
    final regex = RegExp(r'#(\w+)');
    final match = regex.firstMatch(description);
    return match?.group(1);
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
  
  IconData _getPriorityIcon(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Icons.priority_high_rounded;
      case TaskPriority.medium:
        return Icons.remove_rounded;
      case TaskPriority.low:
        return Icons.arrow_downward_rounded;
    }
  }

  String _getPriorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return 'HIGH';
      case TaskPriority.medium:
        return 'MED';
      case TaskPriority.low:
        return 'LOW';
    }
  }

  IconData _getItemTypeIcon(ItemType type) {
    switch (type) {
      case ItemType.task:
        return Icons.task_alt;
      case ItemType.activity:
        return Icons.directions_run;
      case ItemType.event:
        return Icons.event;
      case ItemType.session:
        return Icons.computer;
      case ItemType.routine:
        return Icons.repeat;
      case ItemType.appointment:
        return Icons.people;
      case ItemType.reminder:
        return Icons.notifications;
    }
  }
  
  Color _getItemTypeColor(ItemType type) {
    switch (type) {
      case ItemType.task:
        return AppTheme.primary;
      case ItemType.activity:
        return Colors.orange;
      case ItemType.event:
        return Colors.purple;
      case ItemType.session:
        return Colors.blue;
      case ItemType.routine:
        return Colors.green;
      case ItemType.appointment:
        return Colors.red;
      case ItemType.reminder:
        return Colors.amber;
    }
  }

  Color _getSpaceColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) {
      return AppTheme.primary;
    }
    try {
      return Color(int.parse(colorHex, radix: 16));
    } catch (e) {
      return AppTheme.primary;
    }
  }
}