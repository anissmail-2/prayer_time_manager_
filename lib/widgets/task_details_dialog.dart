import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../core/services/prayer_time_service.dart';
import '../models/task.dart';
import '../models/enhanced_task.dart';
import 'subtasks_widget.dart';
import 'attachments_widget.dart';

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

class TaskDetailsDialog extends StatelessWidget {
  final Task? task;
  final EnhancedTask? enhancedTask;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback? onToggleComplete;
  final Map<String, String>? cachedPrayerTimes;

  const TaskDetailsDialog({
    super.key,
    this.task,
    this.enhancedTask,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
    this.onToggleComplete,
    this.cachedPrayerTimes,
  }) : assert(task != null || enhancedTask != null);

  @override
  Widget build(BuildContext context) {
    final displayTask = task ?? enhancedTask!;
    final isEnhanced = enhancedTask != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: screenSize.height * 0.85,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.surface.withValues(alpha: 0.95),
                  AppTheme.surface.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Creative Header with animated gradient
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getPriorityColor(displayTask.priority),
                        _getPriorityColor(displayTask.priority).withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Background pattern
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _PatternPainter(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                // Task icon
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    _getTaskIcon(displayTask),
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Title
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayTask.title,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (displayTask.description != null && displayTask.description!.isNotEmpty)
                                        Text(
                                          displayTask.description!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white.withValues(alpha: 0.8),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                // Close button
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
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
                ),
                
                // Content Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Schedule Display - Different for prayer relative
                        if (displayTask.scheduleType == ScheduleType.prayerRelative) ...[
                          _buildPrayerScheduleCard(context, displayTask),
                          const SizedBox(height: 12),
                          // Priority Card full width
                          _buildInfoCard(
                            icon: _getPriorityIcon(displayTask.priority),
                            title: 'Priority',
                            value: displayTask.priority.name.toUpperCase(),
                            color: _getPriorityColor(displayTask.priority),
                          ),
                        ] else ...[
                          // Quick Info Cards in a Row for non-prayer tasks
                          Row(
                            children: [
                              // Schedule Card
                              Expanded(
                                child: _buildInfoCard(
                                  icon: Icons.access_time_rounded,
                                  title: 'Schedule',
                                  value: _getScheduleDisplayText(displayTask),
                                  subtitle: _getScheduleSubtitle(displayTask),
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Priority Card
                              Expanded(
                                child: _buildInfoCard(
                                  icon: _getPriorityIcon(displayTask.priority),
                                  title: 'Priority',
                                  value: displayTask.priority.name.toUpperCase(),
                                  color: _getPriorityColor(displayTask.priority),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        
                        // Details Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark 
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: AppTheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Details',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildDetailRow(
                                icon: Icons.calendar_today_outlined,
                                label: 'Created',
                                value: _formatDate(displayTask.createdAt),
                              ),
                              if (displayTask.completedDates.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _buildDetailRow(
                                  icon: Icons.check_circle_outline,
                                  label: 'Completed',
                                  value: _formatDate(displayTask.completedDates.last),
                                ),
                              ],
                              if (displayTask.recurrence != TaskRecurrence.once) ...[
                                const SizedBox(height: 8),
                                _buildDetailRow(
                                  icon: Icons.repeat_rounded,
                                  label: 'Repeats',
                                  value: _getRecurrenceText(displayTask.recurrence),
                                ),
                              ],
                            ],
                          ),
                        ),
                    
                    // Enhanced task specific fields
                    if (isEnhanced) ...[
                      // Notes
                      if (enhancedTask!.notes != null && enhancedTask!.notes!.isNotEmpty)
                        _buildSection(
                          'Notes',
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppTheme.space16),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundLight,
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              border: Border.all(
                                color: AppTheme.borderMedium,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              enhancedTask!.notes!,
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.textPrimary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      
                      // Tags
                      if (enhancedTask!.tags.isNotEmpty)
                        _buildSection(
                          'Tags',
                          Wrap(
                            spacing: AppTheme.space8,
                            runSpacing: AppTheme.space4,
                            children: enhancedTask!.tags.map((tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.space12,
                                vertical: AppTheme.space4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: Text(
                                tag,
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.primary,
                                ),
                              ),
                            )).toList(),
                          ),
                        ),
                      
                      // Time estimates
                      if (enhancedTask!.estimatedMinutes != null || enhancedTask!.actualMinutes != null)
                        _buildSection(
                          'Time Tracking',
                          Row(
                            children: [
                              if (enhancedTask!.estimatedMinutes != null) ...[
                                Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: AppTheme.textTertiary,
                                ),
                                const SizedBox(width: AppTheme.space4),
                                Text(
                                  'Est: ${enhancedTask!.estimatedMinutes} min',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                              if (enhancedTask!.estimatedMinutes != null && enhancedTask!.actualMinutes != null)
                                const SizedBox(width: AppTheme.space16),
                              if (enhancedTask!.actualMinutes != null) ...[
                                Icon(
                                  Icons.timer,
                                  size: 16,
                                  color: AppTheme.textTertiary,
                                ),
                                const SizedBox(width: AppTheme.space4),
                                Text(
                                  'Actual: ${enhancedTask!.actualMinutes} min',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                      // Subtasks
                      if (!enhancedTask!.isSubtask)
                        _buildSection(
                          '',
                          SubtasksWidget(
                            parentTask: enhancedTask!,
                            onSubtasksChanged: () {
                              // Optionally refresh parent task
                            },
                            allowEditing: onEdit != null,
                          ),
                        ),

                      // Attachments
                      _buildSection(
                        '',
                        AttachmentsWidget(
                          attachmentPaths: enhancedTask!.attachments,
                          onAttachmentsChanged: (newAttachments) {
                            // Optionally update attachments
                          },
                          allowEditing: onEdit != null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
                
                // Action Buttons Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Complete Button
                      if (onToggleComplete != null)
                        Expanded(
                          child: _buildActionButton(
                            onTap: () {
                              Navigator.pop(context);
                              onToggleComplete!();
                            },
                            icon: displayTask.isCompleted || (isEnhanced && enhancedTask!.status == TaskStatus.done)
                                ? Icons.undo_rounded
                                : Icons.check_circle_rounded,
                            label: displayTask.isCompleted || (isEnhanced && enhancedTask!.status == TaskStatus.done)
                                ? 'Incomplete'
                                : 'Complete',
                            color: displayTask.isCompleted || (isEnhanced && enhancedTask!.status == TaskStatus.done)
                                ? Colors.orange
                                : Colors.green,
                          ),
                        ),
                      
                      // Duplicate Button
                      if (onDuplicate != null) ...[
                        const SizedBox(width: 8),
                        _buildActionButton(
                          onTap: () {
                            Navigator.pop(context);
                            onDuplicate!();
                          },
                          icon: Icons.content_copy_rounded,
                          label: '',
                          color: AppTheme.secondary,
                          isCompact: true,
                        ),
                      ],

                      // Delete Button
                      if (onDelete != null) ...[
                        const SizedBox(width: 8),
                        _buildActionButton(
                          onTap: () {
                            Navigator.pop(context);
                            onDelete!();
                          },
                          icon: Icons.delete_outline_rounded,
                          label: '',
                          color: Colors.red,
                          isCompact: true,
                        ),
                      ],

                      // Edit Button (Primary)
                      if (onEdit != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionButton(
                            onTap: () {
                              Navigator.pop(context);
                              onEdit!();
                            },
                            icon: Icons.edit_outlined,
                            label: 'Edit',
                            color: AppTheme.primary,
                            isPrimary: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build special prayer schedule card
  Widget _buildPrayerScheduleCard(BuildContext context, Task task) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withValues(alpha: 0.15),
            AppTheme.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mosque_rounded,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Schedule",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      _getScheduleDisplayText(task),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Prayer Rule Display
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Start Time
                _buildPrayerTimeRow(
                  context: context,
                  label: 'Starts',
                  prayer: task.relatedPrayer!,
                  isBefore: task.isBeforePrayer ?? false,
                  minutes: task.minutesOffset ?? 0,
                  icon: Icons.play_circle_outline_rounded,
                  color: AppTheme.success,
                ),
                if (task.endRelatedPrayer != null) ...[
                  const SizedBox(height: 12),
                  // Divider
                  Row(
                    children: [
                      const SizedBox(width: 40),
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppTheme.primary.withValues(alpha: 0.2),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // End Time
                  _buildPrayerTimeRow(
                    context: context,
                    label: 'Ends',
                    prayer: task.endRelatedPrayer!,
                    isBefore: task.endIsBeforePrayer ?? false,
                    minutes: task.endMinutesOffset ?? 0,
                    icon: Icons.stop_circle_outlined,
                    color: AppTheme.error,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPrayerTimeRow({
    required BuildContext context,
    required String label,
    required PrayerName prayer,
    required bool isBefore,
    required int minutes,
    required IconData icon,
    required Color color,
  }) {
    final prayerStr = prayer.toString().split('.').last.capitalize();
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              if (minutes == 0) ...[
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      const TextSpan(text: 'At '),
                      TextSpan(
                        text: '$prayerStr prayer',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$minutes min',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isBefore ? 'before' : 'after',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      prayerStr,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
  
  // Helper method to build info cards
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // Helper method to build detail rows
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: AppTheme.textTertiary,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textTertiary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Helper method to build action buttons
  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color color,
    bool isPrimary = false,
    bool isCompact = false,
  }) {
    return Material(
      color: isPrimary ? color : color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      elevation: isPrimary ? 2 : 0,
      shadowColor: isPrimary ? color.withValues(alpha: 0.3) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: 12,
            horizontal: isCompact ? 12 : 16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: isCompact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary ? Colors.white : color,
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isPrimary ? Colors.white : color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to get task icon
  IconData _getTaskIcon(Task task) {
    switch (task.itemType) {
      case ItemType.task:
        return Icons.task_alt_rounded;
      case ItemType.activity:
        return Icons.fitness_center_rounded;
      case ItemType.event:
        return Icons.event_rounded;
      case ItemType.session:
        return Icons.timer_rounded;
      case ItemType.routine:
        return Icons.refresh_rounded;
      case ItemType.appointment:
        return Icons.people_rounded;
      case ItemType.reminder:
        return Icons.notifications_rounded;
    }
  }

  Widget _buildSection(String title, Widget content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.titleSmall.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          content,
        ],
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

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return AppTheme.textTertiary;
      case TaskStatus.inProgress:
        return AppTheme.primary;
      case TaskStatus.blocked:
        return AppTheme.error;
      case TaskStatus.review:
        return AppTheme.warning;
      case TaskStatus.done:
        return AppTheme.success;
      case TaskStatus.cancelled:
        return AppTheme.textTertiary;
    }
  }

  String _getStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return 'To Do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.blocked:
        return 'Blocked';
      case TaskStatus.review:
        return 'Review';
      case TaskStatus.done:
        return 'Done';
      case TaskStatus.cancelled:
        return 'Cancelled';
    }
  }

  String? _getScheduleSubtitle(Task task) {
    if (task.scheduleType == ScheduleType.prayerRelative && task.relatedPrayer != null) {
      // Build the prayer-relative description
      final prayer = task.relatedPrayer.toString().split('.').last;
      final displayPrayer = prayer.substring(0, 1).toUpperCase() + prayer.substring(1);
      final beforeAfter = task.isBeforePrayer == true ? 'before' : 'after';
      final minutes = task.minutesOffset ?? 0;
      
      String subtitle = '$minutes min $beforeAfter $displayPrayer';
      
      if (task.endRelatedPrayer != null) {
        final endPrayer = task.endRelatedPrayer.toString().split('.').last;
        final displayEndPrayer = endPrayer.substring(0, 1).toUpperCase() + endPrayer.substring(1);
        final endBeforeAfter = task.endIsBeforePrayer == true ? 'before' : 'after';
        final endMinutes = task.endMinutesOffset ?? 0;
        
        subtitle += ' - $endMinutes min $endBeforeAfter $displayEndPrayer';
      }
      
      // Only return subtitle if we have calculated times in the main display
      if (cachedPrayerTimes != null && cachedPrayerTimes!.isNotEmpty) {
        return subtitle;
      }
    }
    return null;
  }

  String _getScheduleDisplayText(Task task) {
    if (task.scheduleType == ScheduleType.absolute) {
      if (task.absoluteTime != null && task.endTime != null) {
        final startTime = DateFormat('h:mm a').format(task.absoluteTime!);
        final endTime = DateFormat('h:mm a').format(task.endTime!);
        return '$startTime - $endTime';
      } else if (task.absoluteTime != null) {
        return DateFormat('h:mm a').format(task.absoluteTime!);
      }
    } else if (task.scheduleType == ScheduleType.prayerRelative && task.relatedPrayer != null) {
      // Build the prayer-relative description
      final prayer = task.relatedPrayer.toString().split('.').last;
      final displayPrayer = prayer.substring(0, 1).toUpperCase() + prayer.substring(1);
      final beforeAfter = task.isBeforePrayer == true ? 'before' : 'after';
      final minutes = task.minutesOffset ?? 0;
      
      String relativeText = '$minutes min $beforeAfter $displayPrayer';
      String calculatedTimes = '';
      
      // Calculate start time if we have prayer times
      if (cachedPrayerTimes != null && cachedPrayerTimes!.isNotEmpty) {
        final startCalc = PrayerTimeService.calculatePrayerRelativeTime(
          prayerTimes: cachedPrayerTimes!,
          prayerName: displayPrayer,
          isBefore: task.isBeforePrayer ?? true,
          minutesOffset: minutes,
        );
        
        if (startCalc != null) {
          calculatedTimes = DateFormat('h:mm a').format(startCalc);
        }
      }
      
      // Add end time if available
      if (task.endRelatedPrayer != null) {
        final endPrayer = task.endRelatedPrayer.toString().split('.').last;
        final displayEndPrayer = endPrayer.substring(0, 1).toUpperCase() + endPrayer.substring(1);
        final endBeforeAfter = task.endIsBeforePrayer == true ? 'before' : 'after';
        final endMinutes = task.endMinutesOffset ?? 0;
        
        relativeText += ' - $endMinutes min $endBeforeAfter $displayEndPrayer';
        
        // Calculate end time
        if (cachedPrayerTimes != null && cachedPrayerTimes!.isNotEmpty) {
          final endCalc = PrayerTimeService.calculatePrayerRelativeTime(
            prayerTimes: cachedPrayerTimes!,
            prayerName: displayEndPrayer,
            isBefore: task.endIsBeforePrayer ?? false,
            minutesOffset: endMinutes,
          );
          
          if (endCalc != null) {
            calculatedTimes += ' - ${DateFormat('h:mm a').format(endCalc)}';
          }
        }
      }
      
      // Return both relative and calculated times if available
      if (calculatedTimes.isNotEmpty) {
        return calculatedTimes;
      } else {
        return relativeText;
      }
    }
    
    return 'No schedule';
  }

  String _calculatePrayerRelativeTimes(Task task) {
    // Use cached prayer times if available, otherwise show relative format
    if (cachedPrayerTimes == null || cachedPrayerTimes!.isEmpty) {
      // Fallback to relative format if prayer times not loaded
      final prayer = task.relatedPrayer.toString().split('.').last;
      final beforeAfter = task.isBeforePrayer == true ? 'before' : 'after';
      final minutes = task.minutesOffset ?? 0;
      
      String text = '$minutes min $beforeAfter $prayer';
      
      if (task.endRelatedPrayer != null) {
        final endPrayer = task.endRelatedPrayer.toString().split('.').last;
        final endBeforeAfter = task.endIsBeforePrayer == true ? 'before' : 'after';
        final endMinutes = task.endMinutesOffset ?? 0;
        text += ' to $endMinutes min $endBeforeAfter $endPrayer';
      }
      
      return text;
    }
    
    // Calculate actual times using prayer times
    try {
      final startPrayer = task.relatedPrayer!;
      final startPrayerName = startPrayer.toString().split('.').last;
      final capitalizedPrayerName = startPrayerName[0].toUpperCase() + startPrayerName.substring(1);
      final startPrayerTime = cachedPrayerTimes![capitalizedPrayerName];
      
      if (startPrayerTime != null) {
        final timeParts = startPrayerTime.split(':');
        final prayerHour = int.parse(timeParts[0]);
        final prayerMinute = int.parse(timeParts[1]);
        
        // Calculate start time
        final startDateTime = DateTime.now().copyWith(
          hour: prayerHour,
          minute: prayerMinute,
          second: 0,
          millisecond: 0,
        );
        
        final offset = task.minutesOffset ?? 0;
        final calculatedStartTime = task.isBeforePrayer == true
            ? startDateTime.subtract(Duration(minutes: offset))
            : startDateTime.add(Duration(minutes: offset));
        
        String result = '${calculatedStartTime.hour.toString().padLeft(2, '0')}:${calculatedStartTime.minute.toString().padLeft(2, '0')}';
        
        // Calculate end time if specified
        if (task.endRelatedPrayer != null) {
          final endPrayer = task.endRelatedPrayer!;
          final endPrayerName = endPrayer.toString().split('.').last;
          final capitalizedEndPrayerName = endPrayerName[0].toUpperCase() + endPrayerName.substring(1);
          final endPrayerTime = cachedPrayerTimes![capitalizedEndPrayerName];
          
          if (endPrayerTime != null) {
            final endTimeParts = endPrayerTime.split(':');
            final endPrayerHour = int.parse(endTimeParts[0]);
            final endPrayerMinute = int.parse(endTimeParts[1]);
            
            final endDateTime = DateTime.now().copyWith(
              hour: endPrayerHour,
              minute: endPrayerMinute,
              second: 0,
              millisecond: 0,
            );
            
            final endOffset = task.endMinutesOffset ?? 0;
            final calculatedEndTime = task.endIsBeforePrayer == true
                ? endDateTime.subtract(Duration(minutes: endOffset))
                : endDateTime.add(Duration(minutes: endOffset));
            
            result += ' - ${calculatedEndTime.hour.toString().padLeft(2, '0')}:${calculatedEndTime.minute.toString().padLeft(2, '0')}';
          }
        }
        
        return result;
      }
    } catch (e) {
      // If calculation fails, fall back to relative format
    }
    
    // Fallback to relative format
    final prayer = task.relatedPrayer.toString().split('.').last;
    final beforeAfter = task.isBeforePrayer == true ? 'before' : 'after';
    final minutes = task.minutesOffset ?? 0;
    return '$minutes min $beforeAfter $prayer';
  }

  String _getRecurrenceText(TaskRecurrence recurrence) {
    switch (recurrence) {
      case TaskRecurrence.once:
        return 'One-time task';
      case TaskRecurrence.daily:
        return 'Repeats daily';
      case TaskRecurrence.weekly:
        return 'Repeats weekly';
      case TaskRecurrence.monthly:
        return 'Repeats monthly';
      case TaskRecurrence.yearly:
        return 'Repeats yearly';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
  
  String _getPrayerRelativeDescription(Task task) {
    if (task.relatedPrayer == null) return '';
    
    final prayer = task.relatedPrayer.toString().split('.').last.capitalize();
    final beforeAfter = task.isBeforePrayer == true ? 'before' : 'after';
    final minutes = task.minutesOffset ?? 0;
    
    // Format the start time
    String text;
    if (minutes == 0) {
      text = 'At $prayer time';
    } else {
      text = '$minutes min $beforeAfter $prayer';
    }
    
    if (task.endRelatedPrayer != null) {
      final endPrayer = task.endRelatedPrayer.toString().split('.').last.capitalize();
      final endBeforeAfter = task.endIsBeforePrayer == true ? 'before' : 'after';
      final endMinutes = task.endMinutesOffset ?? 0;
      
      // Format the end time
      if (endMinutes == 0) {
        text += ' to $endPrayer time';
      } else {
        text += ' to $endMinutes min $endBeforeAfter $endPrayer';
      }
    }
    
    return text;
  }
}

// Pattern painter for header background
class _PatternPainter extends CustomPainter {
  final Color color;

  _PatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const spacing = 30.0;
    const radius = 2.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}