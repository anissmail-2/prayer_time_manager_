import 'package:flutter/material.dart';
import '../core/services/todo_service.dart';
import '../core/services/space_service.dart';
import '../core/helpers/analytics_helper.dart';
import '../core/theme/app_theme.dart';
import '../models/task.dart';
import '../models/space.dart';
import '../widgets/task_details_dialog.dart';
import 'mobile_spaces_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Task> _taskResults = [];
  List<Space> _spaceResults = [];
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    AnalyticsHelper.logScreenView('search');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _taskResults = [];
        _spaceResults = [];
        _searchQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      // Log search analytics
      AnalyticsHelper.logSearch(query);

      // Search tasks
      final allTasks = await TodoService.getAllTasks();
      final taskMatches = allTasks.where((task) {
        final searchLower = query.toLowerCase();
        return task.title.toLowerCase().contains(searchLower) ||
            task.description.toLowerCase().contains(searchLower);
      }).toList();

      // Search spaces
      final allSpaces = await SpaceService.getAllSpaces();
      final spaceMatches = allSpaces.where((space) {
        final searchLower = query.toLowerCase();
        return space.name.toLowerCase().contains(searchLower) ||
            (space.description?.toLowerCase().contains(searchLower) ?? false);
      }).toList();

      setState(() {
        _taskResults = taskMatches;
        _spaceResults = spaceMatches;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search tasks and spaces...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: AppTheme.textSecondary),
          ),
          style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
          onChanged: (value) {
            // Debounce search
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_searchController.text == value) {
                _performSearch(value);
              }
            });
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
              onPressed: () {
                _searchController.clear();
                _performSearch('');
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Search for tasks and spaces',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final totalResults = _taskResults.length + _spaceResults.length;

    if (totalResults == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found for "$_searchQuery"',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Results header
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '$totalResults result${totalResults == 1 ? '' : 's'} for "$_searchQuery"',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // Spaces section
        if (_spaceResults.isNotEmpty) ...[
          Text(
            'Spaces (${_spaceResults.length})',
            style: AppTheme.headlineSmall.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._spaceResults.map((space) => _buildSpaceCard(space)),
          const SizedBox(height: 24),
        ],

        // Tasks section
        if (_taskResults.isNotEmpty) ...[
          Text(
            'Tasks (${_taskResults.length})',
            style: AppTheme.headlineSmall.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._taskResults.map((task) => _buildTaskCard(task)),
        ],
      ],
    );
  }

  Widget _buildSpaceCard(Space space) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(color: AppTheme.borderLight),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(
            Icons.folder,
            color: AppTheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          space.name,
          style: AppTheme.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: space.description != null
            ? Text(
                space.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // Navigate to space details
          // For now, just show a snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening space: ${space.name}')),
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(color: AppTheme.borderLight),
      ),
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (value) async {
            if (value != null) {
              final updatedTask = Task(
                id: task.id,
                title: task.title,
                description: task.description,
                isCompleted: value,
                date: task.date,
                time: task.time,
                priority: task.priority,
                category: task.category,
                recurrencePattern: task.recurrencePattern,
                completedDates: task.completedDates,
                prayerRelativeScheduling: task.prayerRelativeScheduling,
                itemType: task.itemType,
                estimatedMinutes: task.estimatedMinutes,
                startTime: task.startTime,
                endTime: task.endTime,
              );
              await TodoService.updateTask(updatedTask);
              _performSearch(_searchQuery); // Refresh results
            }
          },
        ),
        title: Text(
          task.title,
          style: AppTheme.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary,
          ),
        ),
        subtitle: task.description.isNotEmpty
            ? Text(
                task.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => TaskDetailsDialog(task: task),
          ).then((_) => _performSearch(_searchQuery)); // Refresh after dialog
        },
      ),
    );
  }
}
