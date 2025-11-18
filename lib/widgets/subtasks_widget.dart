import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/services/todo_service.dart';
import '../core/helpers/analytics_helper.dart';
import '../models/enhanced_task.dart';
import '../models/task.dart';

/// Widget for displaying and managing subtasks
class SubtasksWidget extends StatefulWidget {
  final EnhancedTask parentTask;
  final VoidCallback? onSubtasksChanged;
  final bool allowEditing;

  const SubtasksWidget({
    super.key,
    required this.parentTask,
    this.onSubtasksChanged,
    this.allowEditing = true,
  });

  @override
  State<SubtasksWidget> createState() => _SubtasksWidgetState();
}

class _SubtasksWidgetState extends State<SubtasksWidget> {
  List<EnhancedTask> _subtasks = [];
  bool _isLoading = true;
  final TextEditingController _newSubtaskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSubtasks();
  }

  @override
  void dispose() {
    _newSubtaskController.dispose();
    super.dispose();
  }

  Future<void> _loadSubtasks() async {
    setState(() => _isLoading = true);
    try {
      final allTasks = await TodoService.getAllTasks();
      _subtasks = allTasks
          .whereType<EnhancedTask>()
          .where((task) => task.parentTaskId == widget.parentTask.id)
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load subtasks: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _addSubtask(String title) async {
    if (title.trim().isEmpty) return;

    try {
      final newSubtask = EnhancedTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title.trim(),
        description: '',
        createdAt: DateTime.now(),
        scheduleType: ScheduleType.unscheduled,
        recurrence: TaskRecurrence.once,
        parentTaskId: widget.parentTask.id,
        priority: widget.parentTask.priority,
        status: TaskStatus.todo,
      );

      await TodoService.addTask(newSubtask);
      await AnalyticsHelper.logTaskCreated(source: 'subtask');

      _newSubtaskController.clear();
      await _loadSubtasks();
      widget.onSubtasksChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subtask added!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add subtask: $e')),
        );
      }
    }
  }

  Future<void> _toggleSubtask(EnhancedTask subtask) async {
    try {
      final updatedSubtask = EnhancedTask(
        id: subtask.id,
        title: subtask.title,
        description: subtask.description,
        createdAt: subtask.createdAt,
        isCompleted: !subtask.isCompleted,
        priority: subtask.priority,
        itemType: subtask.itemType,
        scheduleType: subtask.scheduleType,
        absoluteTime: subtask.absoluteTime,
        recurrence: subtask.recurrence,
        parentTaskId: subtask.parentTaskId,
        status: !subtask.isCompleted ? TaskStatus.done : TaskStatus.todo,
        completedDates: !subtask.isCompleted
            ? [...subtask.completedDates, DateTime.now()]
            : subtask.completedDates,
      );

      await TodoService.updateTask(updatedSubtask);
      await AnalyticsHelper.logTaskCompleted(isPrayerRelative: false);

      await _loadSubtasks();
      widget.onSubtasksChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update subtask: $e')),
        );
      }
    }
  }

  Future<void> _deleteSubtask(EnhancedTask subtask) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subtask'),
        content: Text('Delete "${subtask.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await TodoService.deleteTask(subtask.id);
        await AnalyticsHelper.logTaskDeleted();

        await _loadSubtasks();
        widget.onSubtasksChanged?.call();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subtask deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete subtask: $e')),
          );
        }
      }
    }
  }

  int get _completedCount => _subtasks.where((t) => t.isCompleted).length;
  int get _totalCount => _subtasks.length;
  double get _progress => _totalCount > 0 ? _completedCount / _totalCount : 0.0;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with progress
        Row(
          children: [
            Icon(
              Icons.check_box_outlined,
              size: 20,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Subtasks',
              style: AppTheme.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            if (_totalCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _progress == 1.0
                      ? AppTheme.success.withOpacity(0.1)
                      : AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_completedCount/$_totalCount',
                  style: AppTheme.labelSmall.copyWith(
                    color: _progress == 1.0 ? AppTheme.success : AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),

        // Progress bar
        if (_totalCount > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: AppTheme.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                _progress == 1.0 ? AppTheme.success : AppTheme.primary,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Subtask list
        if (_subtasks.isNotEmpty) ...[
          ..._subtasks.map((subtask) => _buildSubtaskItem(subtask)),
        ],

        // Add new subtask
        if (widget.allowEditing) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newSubtaskController,
                  decoration: InputDecoration(
                    hintText: 'Add a subtask...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: _addSubtask,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _addSubtask(_newSubtaskController.text),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSubtaskItem(EnhancedTask subtask) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.borderLight,
          width: 1,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 0,
        ),
        leading: Checkbox(
          value: subtask.isCompleted,
          onChanged: widget.allowEditing
              ? (_) => _toggleSubtask(subtask)
              : null,
          activeColor: AppTheme.success,
        ),
        title: Text(
          subtask.title,
          style: AppTheme.bodyMedium.copyWith(
            decoration: subtask.isCompleted
                ? TextDecoration.lineThrough
                : null,
            color: subtask.isCompleted
                ? AppTheme.textSecondary
                : AppTheme.textPrimary,
          ),
        ),
        trailing: widget.allowEditing
            ? IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: AppTheme.error,
                  size: 18,
                ),
                onPressed: () => _deleteSubtask(subtask),
              )
            : null,
      ),
    );
  }
}
