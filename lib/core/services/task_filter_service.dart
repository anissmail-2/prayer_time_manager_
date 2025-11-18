import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/task.dart';
import 'todo_service.dart';
import 'prayer_time_service.dart';

class TaskFilterService {
  static const String _filterPresetsKey = 'filter_presets';
  static const String _lastFilterKey = 'last_filter';
  static const int _defaultPageSize = 7; // Load 7 days at a time
  static final Map<String, Map<String, String>> _prayerTimesCache = {};

  // Sorting options
  static const List<SortOption> availableSortOptions = [
    SortOption(field: SortField.time, ascending: true, label: 'Time (Earliest First)'),
    SortOption(field: SortField.time, ascending: false, label: 'Time (Latest First)'),
    SortOption(field: SortField.priority, ascending: false, label: 'Priority (High to Low)'),
    SortOption(field: SortField.priority, ascending: true, label: 'Priority (Low to High)'),
    SortOption(field: SortField.name, ascending: true, label: 'Name (A-Z)'),
    SortOption(field: SortField.name, ascending: false, label: 'Name (Z-A)'),
    SortOption(field: SortField.dateCreated, ascending: false, label: 'Newest First'),
    SortOption(field: SortField.dateCreated, ascending: true, label: 'Oldest First'),
  ];

  // Quick date presets
  static List<DatePreset> getDatePresets() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return [
      DatePreset(
        name: 'Today',
        startDate: today,
        endDate: today,
      ),
      DatePreset(
        name: 'Tomorrow',
        startDate: today.add(const Duration(days: 1)),
        endDate: today.add(const Duration(days: 1)),
      ),
      DatePreset(
        name: 'This Week',
        startDate: today.subtract(Duration(days: today.weekday - 1)),
        endDate: today.add(Duration(days: 7 - today.weekday)),
      ),
      DatePreset(
        name: 'Next Week',
        startDate: today.add(Duration(days: 8 - today.weekday)),
        endDate: today.add(Duration(days: 14 - today.weekday)),
      ),
      DatePreset(
        name: 'This Month',
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
      ),
      DatePreset(
        name: 'Next 7 Days',
        startDate: today,
        endDate: today.add(const Duration(days: 6)),
      ),
      DatePreset(
        name: 'Next 30 Days',
        startDate: today,
        endDate: today.add(const Duration(days: 29)),
      ),
    ];
  }

  // Load filtered tasks with pagination
  static Future<FilteredTasksResult> loadFilteredTasks({
    required TaskFilterOptions filters,
    int page = 0,
    int pageSize = _defaultPageSize,
    SortOption? sortOption,
  }) async {
    try {
      // Determine date range
      DateTime startDate;
      DateTime endDate;
      
      if (filters.specificDate != null) {
        startDate = filters.specificDate!;
        endDate = filters.specificDate!;
      } else if (filters.startDate != null && filters.endDate != null) {
        startDate = filters.startDate!;
        endDate = filters.endDate!;
      } else {
        // Default to pagination from today
        final today = DateTime.now();
        startDate = today.add(Duration(days: page * pageSize));
        endDate = today.add(Duration(days: (page + 1) * pageSize - 1));
      }

      // Load tasks for date range with caching
      final allTasks = await _loadTasksForDateRange(startDate, endDate);
      
      // Apply filters
      final filteredTasks = _applyFilters(allTasks, filters);
      
      // Apply sorting
      final sortedTasks = _applySorting(filteredTasks, sortOption);
      
      return FilteredTasksResult(
        tasks: sortedTasks,
        totalCount: sortedTasks.length,
        hasMore: endDate.isBefore(DateTime.now().add(const Duration(days: 365))),
        currentPage: page,
      );
    } catch (e) {
      return FilteredTasksResult(
        tasks: [],
        totalCount: 0,
        hasMore: false,
        currentPage: page,
        error: e.toString(),
      );
    }
  }

  // Load tasks for date range with caching
  static Future<List<TaskWithTime>> _loadTasksForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final tasks = <TaskWithTime>[];
    DateTime currentDate = startDate;
    
    while (!currentDate.isAfter(endDate)) {
      // Check cache first
      final cacheKey = _getCacheKey(currentDate);
      Map<String, String> prayerTimes;
      
      if (_prayerTimesCache.containsKey(cacheKey)) {
        prayerTimes = _prayerTimesCache[cacheKey]!;
      } else {
        // Load and cache prayer times
        prayerTimes = await PrayerTimeService.getPrayerTimes(date: currentDate);
        _prayerTimesCache[cacheKey] = prayerTimes;
        
        // Keep cache size reasonable (max 60 days)
        if (_prayerTimesCache.length > 60) {
          final oldestKey = _prayerTimesCache.keys.first;
          _prayerTimesCache.remove(oldestKey);
        }
      }
      
      final tasksForDate = await TodoService.getAllTasksWithTimesForDate(
        prayerTimes,
        currentDate,
      );
      tasks.addAll(tasksForDate);
      
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    return tasks;
  }

  // Apply all filters to tasks
  static List<TaskWithTime> _applyFilters(
    List<TaskWithTime> tasks,
    TaskFilterOptions filters,
  ) {
    return tasks.where((taskWithTime) {
      final task = taskWithTime.task;
      final taskDate = taskWithTime.scheduledTime;
      
      // Status filter (removed redundant 'all' option)
      if (filters.statuses.isNotEmpty) {
        bool matchesStatus = false;
        final now = DateTime.now();
        
        for (final status in filters.statuses) {
          switch (status) {
            case TaskStatus.all:
              matchesStatus = true;
              break;
            case TaskStatus.today:
              if (_isSameDay(taskDate, now)) {
                matchesStatus = true;
              }
              break;
            case TaskStatus.upcoming:
              if (taskDate.isAfter(now)) {
                matchesStatus = true;
              }
              break;
            case TaskStatus.completed:
              if (task.isCompletedForDate(taskDate ?? now)) {
                matchesStatus = true;
              }
              break;
            case TaskStatus.missed:
              // Check if task time has actually passed, not just the date
              if (taskDate.isBefore(now) &&
                  !task.isCompletedForDate(taskDate)) {
                matchesStatus = true;
              }
              break;
            case TaskStatus.overdue:
              // Tasks that are overdue but not from too long ago
              if (taskDate.isBefore(now) &&
                  taskDate.isAfter(now.subtract(const Duration(days: 7))) &&
                  !task.isCompletedForDate(taskDate)) {
                matchesStatus = true;
              }
              break;
            case TaskStatus.old:
              if (taskDate.isBefore(now.subtract(const Duration(days: 30)))) {
                matchesStatus = true;
              }
              break;
          }
          
          if (matchesStatus) break;
        }
        
        if (!matchesStatus) return false;
      }
      
      // Priority filter
      if (filters.priorities.isNotEmpty && 
          !filters.priorities.contains(task.priority)) {
        return false;
      }
      
      // Space filter - NOW WORKING!
      if (filters.spaceIds.isNotEmpty) {
        final spaceId = _extractSpaceId(task.description ?? '');
        if (spaceId == null || !filters.spaceIds.contains(spaceId)) {
          return false;
        }
      }
      
      // Enhanced search - searches title, description, and space
      if (filters.searchQuery.isNotEmpty) {
        final query = filters.searchQuery.toLowerCase();
        bool matches = false;
        
        // Search in title
        if (task.title.toLowerCase().contains(query)) {
          matches = true;
        }
        
        // Search in description
        if (!matches && task.description != null) {
          if (task.description!.toLowerCase().contains(query)) {
            matches = true;
          }
        }
        
        // Search in space name
        if (!matches) {
          final spaceId = _extractSpaceId(task.description ?? '');
          if (spaceId != null) {
            // This would need space name lookup - for now just check space ID
            if (spaceId.toLowerCase().contains(query)) {
              matches = true;
            }
          }
        }
        
        // Search in tags
        if (!matches && filters.searchInTags) {
          final tags = _extractTags(task.description ?? '');
          for (final tag in tags) {
            if (tag.toLowerCase().contains(query)) {
              matches = true;
              break;
            }
          }
        }
        
        if (!matches) return false;
      }
      
      // Item type filter
      if (filters.itemTypes.isNotEmpty && 
          !filters.itemTypes.contains(task.itemType)) {
        return false;
      }
      
      return true;
    }).toList();
  }

  // Apply sorting to tasks
  static List<TaskWithTime> _applySorting(
    List<TaskWithTime> tasks,
    SortOption? sortOption,
  ) {
    if (sortOption == null) {
      // Default sort by time
      tasks.sort((a, b) {
        if (a.scheduledTime == null && b.scheduledTime == null) return 0;
        return a.scheduledTime.compareTo(b.scheduledTime);
      });
      return tasks;
    }
    
    switch (sortOption.field) {
      case SortField.time:
        tasks.sort((a, b) {
          if (a.scheduledTime == null && b.scheduledTime == null) return 0;
          final comparison = a.scheduledTime.compareTo(b.scheduledTime);
          return sortOption.ascending ? comparison : -comparison;
        });
        break;
        
      case SortField.priority:
        tasks.sort((a, b) {
          final aValue = _getPriorityValue(a.task.priority);
          final bValue = _getPriorityValue(b.task.priority);
          final comparison = aValue.compareTo(bValue);
          return sortOption.ascending ? comparison : -comparison;
        });
        break;
        
      case SortField.name:
        tasks.sort((a, b) {
          final comparison = a.task.title.compareTo(b.task.title);
          return sortOption.ascending ? comparison : -comparison;
        });
        break;
        
      case SortField.dateCreated:
        tasks.sort((a, b) {
          // Use task ID as proxy for creation date (milliseconds since epoch)
          final aId = int.tryParse(a.task.id) ?? 0;
          final bId = int.tryParse(b.task.id) ?? 0;
          final comparison = aId.compareTo(bId);
          return sortOption.ascending ? comparison : -comparison;
        });
        break;
    }
    
    return tasks;
  }

  // Save filter preset
  static Future<void> saveFilterPreset(String name, TaskFilterOptions filters) async {
    final prefs = await SharedPreferences.getInstance();
    final presetsJson = prefs.getString(_filterPresetsKey) ?? '{}';
    final presets = Map<String, dynamic>.from(json.decode(presetsJson));
    
    presets[name] = filters.toJson();
    
    await prefs.setString(_filterPresetsKey, json.encode(presets));
  }

  // Load filter presets
  static Future<Map<String, TaskFilterOptions>> loadFilterPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final presetsJson = prefs.getString(_filterPresetsKey) ?? '{}';
    final presets = Map<String, dynamic>.from(json.decode(presetsJson));
    
    final result = <String, TaskFilterOptions>{};
    for (final entry in presets.entries) {
      result[entry.key] = TaskFilterOptions.fromJson(entry.value);
    }
    
    return result;
  }

  // Delete filter preset
  static Future<void> deleteFilterPreset(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final presetsJson = prefs.getString(_filterPresetsKey) ?? '{}';
    final presets = Map<String, dynamic>.from(json.decode(presetsJson));
    
    presets.remove(name);
    
    await prefs.setString(_filterPresetsKey, json.encode(presets));
  }

  // Save last used filter
  static Future<void> saveLastFilter(TaskFilterOptions filters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastFilterKey, json.encode(filters.toJson()));
  }

  // Load last used filter
  static Future<TaskFilterOptions?> loadLastFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final filterJson = prefs.getString(_lastFilterKey);
    
    if (filterJson != null) {
      return TaskFilterOptions.fromJson(json.decode(filterJson));
    }
    
    return null;
  }

  // Helper methods
  static String _getCacheKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  static String? _extractSpaceId(String description) {
    final regex = RegExp(r'#(\w+)');
    final match = regex.firstMatch(description);
    return match?.group(1);
  }

  static List<String> _extractTags(String description) {
    final regex = RegExp(r'#(\w+)');
    final matches = regex.allMatches(description);
    return matches.map((m) => m.group(1) ?? '').where((tag) => tag.isNotEmpty).toList();
  }

  static int _getPriorityValue(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return 3;
      case TaskPriority.medium:
        return 2;
      case TaskPriority.low:
        return 1;
    }
  }

  // Export filtered tasks to CSV
  static String exportToCSV(List<TaskWithTime> tasks) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('Title,Description,Date,Time,Priority,Type,Status,Recurrence');
    
    // Data
    for (final taskWithTime in tasks) {
      final task = taskWithTime.task;
      final time = taskWithTime.scheduledTime;
      
      buffer.write('"${task.title}",');
      buffer.write('"${task.description ?? ''}",');
      buffer.write('"${"${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}"}",');
      buffer.write('"${"${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}"}",');
      buffer.write('"${task.priority.name}",');
      buffer.write('"${task.itemType.name}",');
      buffer.write('"${task.isCompletedForDate(DateTime.now()) ? "Completed" : "Pending"}",');
      buffer.writeln('"${task.recurrence.name}"');
    }
    
    return buffer.toString();
  }
}

// Enhanced filter options
class TaskFilterOptions {
  DateTime? specificDate;
  DateTime? startDate;
  DateTime? endDate;
  Set<TaskStatus> statuses;
  Set<String> spaceIds;
  Set<TaskPriority> priorities;
  Set<ItemType> itemTypes;
  String searchQuery;
  bool searchInTags;
  
  TaskFilterOptions({
    this.specificDate,
    this.startDate,
    this.endDate,
    Set<TaskStatus>? statuses,
    Set<String>? spaceIds,
    Set<TaskPriority>? priorities,
    Set<ItemType>? itemTypes,
    this.searchQuery = '',
    this.searchInTags = true,
  })  : statuses = statuses ?? {},
        spaceIds = spaceIds ?? {},
        priorities = priorities ?? {},
        itemTypes = itemTypes ?? {};

  bool get hasActiveFilters =>
      specificDate != null ||
      (startDate != null && endDate != null) ||
      statuses.isNotEmpty ||
      spaceIds.isNotEmpty ||
      priorities.isNotEmpty ||
      itemTypes.isNotEmpty ||
      searchQuery.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'specificDate': specificDate?.toIso8601String(),
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'statuses': statuses.map((s) => s.index).toList(),
    'spaceIds': spaceIds.toList(),
    'priorities': priorities.map((p) => p.index).toList(),
    'itemTypes': itemTypes.map((t) => t.index).toList(),
    'searchQuery': searchQuery,
    'searchInTags': searchInTags,
  };

  factory TaskFilterOptions.fromJson(Map<String, dynamic> json) {
    return TaskFilterOptions(
      specificDate: json['specificDate'] != null 
          ? DateTime.parse(json['specificDate']) : null,
      startDate: json['startDate'] != null 
          ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null 
          ? DateTime.parse(json['endDate']) : null,
      statuses: (json['statuses'] as List?)
          ?.map((i) => TaskStatus.values[i as int]).toSet() ?? {},
      spaceIds: (json['spaceIds'] as List?)?.map((id) => id as String).toSet() ?? {},
      priorities: (json['priorities'] as List?)
          ?.map((i) => TaskPriority.values[i as int]).toSet() ?? {},
      itemTypes: (json['itemTypes'] as List?)
          ?.map((i) => ItemType.values[i as int]).toSet() ?? {},
      searchQuery: json['searchQuery'] ?? '',
      searchInTags: json['searchInTags'] ?? true,
    );
  }

  void clearDateFilter() {
    specificDate = null;
    startDate = null;
    endDate = null;
  }
}

// Updated status enum
enum TaskStatus {
  all,      // Show all tasks
  today,
  upcoming,
  completed,
  missed,
  overdue,
  old,      // Tasks older than 30 days
}

// Sort options
enum SortField {
  time,
  priority,
  name,
  dateCreated,
}

class SortOption {
  final SortField field;
  final bool ascending;
  final String label;
  
  const SortOption({
    required this.field,
    required this.ascending,
    required this.label,
  });
}

// Date preset
class DatePreset {
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  
  const DatePreset({
    required this.name,
    required this.startDate,
    required this.endDate,
  });
}

// Filter result
class FilteredTasksResult {
  final List<TaskWithTime> tasks;
  final int totalCount;
  final bool hasMore;
  final int currentPage;
  final String? error;
  
  const FilteredTasksResult({
    required this.tasks,
    required this.totalCount,
    required this.hasMore,
    required this.currentPage,
    this.error,
  });
}