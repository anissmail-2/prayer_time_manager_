import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/services/todo_service.dart';
import '../core/services/prayer_time_service.dart';
import '../core/theme/app_theme.dart';
import '../models/task.dart';
import '../widgets/task_details_dialog.dart';
import 'add_edit_item_screen.dart';

class DashboardScreen extends StatefulWidget {
  /// Called with the target tab index when the dashboard wants to switch
  /// tabs in [MainLayout] (e.g. "View All" -> Agenda).
  final void Function(int index)? onNavigate;

  const DashboardScreen({super.key, this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, String> _prayerTimes = {};
  List<TaskWithTime> _todayTasks = [];
  bool _isLoading = true;
  String? _nextPrayer;
  String? _nextPrayerTime;
  Duration? _timeToNextPrayer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Update the next-prayer countdown periodically
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateNextPrayer(),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      _prayerTimes = await PrayerTimeService.getPrayerTimes();
      _todayTasks = await TodoService.getUpcomingTasksWithTimes(_prayerTimes);
      _updateNextPrayer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _updateNextPrayer() {
    if (!mounted || _prayerTimes.isEmpty) return;

    final now = DateTime.now();

    // Parse all prayer times into today's DateTimes and sort chronologically
    // so the result doesn't depend on the map's iteration order.
    final parsed = <MapEntry<String, DateTime>>[];
    for (final entry in _prayerTimes.entries) {
      if (entry.key == 'Sunrise') continue;

      final parts = entry.value.split(':');
      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0].trim());
      final minute = int.tryParse(parts[1].trim());
      if (hour == null || minute == null) continue;

      parsed.add(MapEntry(
        entry.key,
        DateTime(now.year, now.month, now.day, hour, minute),
      ));
    }

    if (parsed.isEmpty) return;
    parsed.sort((a, b) => a.value.compareTo(b.value));

    // First prayer still ahead today, otherwise the earliest prayer tomorrow.
    MapEntry<String, DateTime>? next;
    for (final entry in parsed) {
      if (entry.value.isAfter(now)) {
        next = entry;
        break;
      }
    }
    next ??= MapEntry(
      parsed.first.key,
      parsed.first.value.add(const Duration(days: 1)),
    );

    final nextEntry = next;
    setState(() {
      _nextPrayer = nextEntry.key;
      _nextPrayerTime = _prayerTimes[nextEntry.key];
      _timeToNextPrayer = nextEntry.value.difference(now);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppTheme.space24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeSection(),
                    const SizedBox(height: AppTheme.space24),
                    _buildStatsCards(),
                    const SizedBox(height: AppTheme.space24),
                    _buildNextPrayerCard(),
                    const SizedBox(height: AppTheme.space24),
                    _buildTodayTasksSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeSection() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning!';
    } else if (hour < 17) {
      greeting = 'Good Afternoon!';
    } else {
      greeting = 'Good Evening!';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: AppTheme.headlineLarge.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        Text(
          DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    final completedToday = _todayTasks.where((t) => t.task.isCompletedForDate(DateTime.now())).length;
    final totalToday = _todayTasks.length;
    final pendingTasks = totalToday - completedToday;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Completed',
            value: completedToday.toString(),
            subtitle: 'tasks today',
            icon: Icons.check_circle_outline,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: AppTheme.space16),
        Expanded(
          child: _buildStatCard(
            title: 'Pending',
            value: pendingTasks.toString(),
            subtitle: 'tasks remaining',
            icon: Icons.pending_outlined,
            color: AppTheme.warning,
          ),
        ),
        const SizedBox(width: AppTheme.space16),
        Expanded(
          child: _buildStatCard(
            title: 'Total',
            value: totalToday.toString(),
            subtitle: 'tasks scheduled',
            icon: Icons.task_alt,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: AppTheme.cardDecoration(
        boxShadow: AppTheme.shadowSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          Text(
            value,
            style: AppTheme.headlineMedium.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            subtitle,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextPrayerCard() {
    if (_nextPrayer == null || _timeToNextPrayer == null) {
      return const SizedBox.shrink();
    }

    final hours = _timeToNextPrayer!.inHours;
    final minutes = _timeToNextPrayer!.inMinutes % 60;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary,
            AppTheme.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.shadowLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.space12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Icon(
                  Icons.access_time,
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
                      'Next Prayer',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      '$_nextPrayer at $_nextPrayerTime',
                      style: AppTheme.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space20),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space16,
              vertical: AppTheme.space8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
            ),
            child: Text(
              hours > 0 ? '$hours hr $minutes min' : '$minutes minutes',
              style: AppTheme.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTasksSection() {
    final upcomingTasks = _todayTasks
        .where((t) => !t.task.isCompletedForDate(DateTime.now()))
        .take(5)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Today\'s Tasks',
              style: AppTheme.titleLarge.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
            TextButton(
              // Switch to the Agenda tab (index 1)
              onPressed: () => widget.onNavigate?.call(1),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space16),
        if (upcomingTasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.space32),
            decoration: AppTheme.cardDecoration(),
            child: Column(
              children: [
                Icon(
                  Icons.task_alt,
                  size: 48,
                  color: AppTheme.textTertiary,
                ),
                const SizedBox(height: AppTheme.space16),
                Text(
                  'No pending tasks',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ...upcomingTasks.map((taskWithTime) => _buildTaskCard(taskWithTime)),
      ],
    );
  }

  Widget _buildTaskCard(TaskWithTime taskWithTime) {
    final task = taskWithTime.task;
    final time = taskWithTime.scheduledTime;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space12),
      decoration: AppTheme.cardDecoration(),
      child: ListTile(
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
              onDelete: () async {
                await TodoService.deleteTask(task.id);
                await _loadData();
              },
              onToggleComplete: () async {
                await TodoService.toggleTaskStatus(task);
                await _loadData();
              },
            ),
          );
        },
        contentPadding: const EdgeInsets.all(AppTheme.space16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: task.priority == TaskPriority.high
                ? AppTheme.error.withOpacity(0.1)
                : task.priority == TaskPriority.medium
                    ? AppTheme.warning.withOpacity(0.1)
                    : AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(
            Icons.task_alt,
            color: task.priority == TaskPriority.high
                ? AppTheme.error
                : task.priority == TaskPriority.medium
                    ? AppTheme.warning
                    : AppTheme.primary,
          ),
        ),
        title: Text(
          task.title,
          style: AppTheme.titleMedium.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          DateFormat('h:mm a').format(time),
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space12,
            vertical: AppTheme.space4,
          ),
          decoration: BoxDecoration(
            color: _getPriorityColor(task.priority).withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
          ),
          child: Text(
            task.priority.name.toUpperCase(),
            style: AppTheme.labelSmall.copyWith(
              color: _getPriorityColor(task.priority),
              fontWeight: FontWeight.w600,
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
}