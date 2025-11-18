import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity.dart';
import '../core/theme/app_theme.dart';
import '../core/services/space_service.dart';

class ActivityDetailsDialog extends StatelessWidget {
  final Activity activity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ActivityDetailsDialog({
    super.key,
    required this.activity,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOngoing = activity.startTime.isBefore(now) && activity.endTime.isAfter(now);
    final isPast = activity.endTime.isBefore(now);
    final duration = activity.duration;
    
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppTheme.space24),
              decoration: BoxDecoration(
                color: (activity.color != null 
                    ? Color(int.parse(activity.color!.replaceFirst('#', '0xff')))
                    : activity.type.defaultColor).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusLarge),
                  topRight: Radius.circular(AppTheme.radiusLarge),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.space12),
                        decoration: BoxDecoration(
                          color: activity.color != null 
                              ? Color(int.parse(activity.color!.replaceFirst('#', '0xff')))
                              : activity.type.defaultColor,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Icon(
                          activity.type.icon,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.title,
                              style: AppTheme.headlineSmall.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppTheme.space4),
                            Text(
                              activity.type.displayName,
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOngoing)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.space12,
                            vertical: AppTheme.space4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
                          ),
                          child: Text(
                            'ONGOING',
                            style: AppTheme.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Content
            SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.space24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date and time
                  _buildInfoRow(
                    icon: Icons.calendar_today,
                    label: 'Date',
                    value: DateFormat('EEEE, MMMM d, yyyy').format(activity.startTime),
                  ),
                  const SizedBox(height: AppTheme.space16),
                  
                  _buildInfoRow(
                    icon: Icons.access_time,
                    label: 'Time',
                    value: activity.isAllDay 
                        ? 'All day'
                        : '${DateFormat('h:mm a').format(activity.startTime)} - ${DateFormat('h:mm a').format(activity.endTime)}',
                  ),
                  const SizedBox(height: AppTheme.space16),
                  
                  _buildInfoRow(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: _formatDuration(duration),
                  ),
                  
                  if (activity.location != null) ...[
                    const SizedBox(height: AppTheme.space16),
                    _buildInfoRow(
                      icon: Icons.location_on,
                      label: 'Location',
                      value: activity.location!,
                    ),
                  ],
                  
                  if (activity.attendees.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.space16),
                    _buildInfoRow(
                      icon: Icons.people,
                      label: 'Attendees',
                      value: activity.attendees.join(', '),
                    ),
                  ],
                  
                  if (activity.spaceId != null) ...[
                    const SizedBox(height: AppTheme.space16),
                    FutureBuilder(
                      future: SpaceService.getSpace(activity.spaceId!),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          final space = snapshot.data!;
                          return _buildInfoRow(
                            icon: Icons.folder,
                            label: 'Space',
                            value: space.name,
                            valueColor: space.color != null 
                                ? _parseColor(space.color!)
                                : null,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                  
                  if (activity.recurrence != ActivityRecurrence.once) ...[
                    const SizedBox(height: AppTheme.space16),
                    _buildInfoRow(
                      icon: Icons.repeat,
                      label: 'Recurrence',
                      value: _getRecurrenceDescription(),
                    ),
                  ],
                  
                  if (activity.description != null && activity.description!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.space24),
                    _buildSection('Description', activity.description!),
                  ],
                  
                  if (activity.notes != null && activity.notes!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.space24),
                    _buildSection('Notes', activity.notes!),
                  ],
                  
                  const SizedBox(height: AppTheme.space24),
                  _buildMetaInfo(),
                ],
              ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(AppTheme.space16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.borderLight),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onDelete();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.error,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onEdit();
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppTheme.textTertiary,
        ),
        const SizedBox(width: AppTheme.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              Text(
                value,
                style: AppTheme.bodyMedium.copyWith(
                  color: valueColor ?? AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.titleMedium.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.space12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Text(
            content,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaInfo() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppTheme.textTertiary,
              ),
              const SizedBox(width: AppTheme.space8),
              Text(
                'Activity Information',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            'Created ${_formatRelativeDate(activity.createdAt)}',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
          if (activity.updatedAt != activity.createdAt)
            Text(
              'Last updated ${_formatRelativeDate(activity.updatedAt)}',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textTertiary,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0 && minutes > 0) {
      return '$hours hour${hours > 1 ? 's' : ''} $minutes minute${minutes > 1 ? 's' : ''}';
    } else if (hours > 0) {
      return '$hours hour${hours > 1 ? 's' : ''}';
    } else {
      return '$minutes minute${minutes > 1 ? 's' : ''}';
    }
  }

  String _getRecurrenceDescription() {
    switch (activity.recurrence) {
      case ActivityRecurrence.daily:
        return 'Every day';
      case ActivityRecurrence.weekly:
        if (activity.weeklyDays != null && activity.weeklyDays!.isNotEmpty) {
          final days = activity.weeklyDays!.map((day) {
            switch (day) {
              case 1: return 'Mon';
              case 2: return 'Tue';
              case 3: return 'Wed';
              case 4: return 'Thu';
              case 5: return 'Fri';
              case 6: return 'Sat';
              case 7: return 'Sun';
              default: return '';
            }
          }).join(', ');
          return 'Weekly on $days';
        }
        return 'Every week';
      case ActivityRecurrence.monthly:
        return 'Monthly on day ${activity.startTime.day}';
      default:
        return 'Does not repeat';
    }
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'just now';
        }
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      }
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  Color _parseColor(String colorString) {
    try {
      if (colorString.startsWith('#')) {
        return Color(int.parse(colorString.replaceFirst('#', '0xff')));
      } else if (colorString.startsWith('0x') || colorString.startsWith('0X')) {
        return Color(int.parse(colorString));
      } else if (colorString.length == 6) {
        return Color(int.parse('0xff$colorString', radix: 16));
      } else if (colorString.length == 8 && colorString.toUpperCase().startsWith('FF')) {
        return Color(int.parse('0x$colorString', radix: 16));
      } else {
        return Color(int.parse('0xff$colorString', radix: 16));
      }
    } catch (e) {
      return AppTheme.primary;
    }
  }
}