import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/services/notification_service.dart';
import '../core/helpers/analytics_helper.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _prayerNotificationsEnabled = true;
  bool _taskNotificationsEnabled = true;
  int _prayerNotificationMinutes = 15;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    AnalyticsHelper.logSettingsOpened();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      _prayerNotificationsEnabled =
          await NotificationService.isPrayerNotificationsEnabled();
      _taskNotificationsEnabled =
          await NotificationService.isTaskNotificationsEnabled();
      _prayerNotificationMinutes =
          await NotificationService.getPrayerNotificationMinutes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _togglePrayerNotifications(bool value) async {
    setState(() => _prayerNotificationsEnabled = value);
    await NotificationService.setPrayerNotificationsEnabled(value);
    await AnalyticsHelper.logEvent(
      name: 'prayer_notifications_toggled',
      parameters: {'enabled': value},
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Prayer notifications enabled'
                : 'Prayer notifications disabled',
          ),
        ),
      );
    }
  }

  Future<void> _toggleTaskNotifications(bool value) async {
    setState(() => _taskNotificationsEnabled = value);
    await NotificationService.setTaskNotificationsEnabled(value);
    await AnalyticsHelper.logEvent(
      name: 'task_notifications_toggled',
      parameters: {'enabled': value},
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Task notifications enabled'
                : 'Task notifications disabled',
          ),
        ),
      );
    }
  }

  Future<void> _updatePrayerNotificationMinutes(int minutes) async {
    setState(() => _prayerNotificationMinutes = minutes);
    await NotificationService.setPrayerNotificationMinutes(minutes);
    await AnalyticsHelper.logEvent(
      name: 'prayer_notification_timing_changed',
      parameters: {'minutes': minutes},
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prayer notifications set to $minutes minutes before'),
        ),
      );
    }
  }

  Future<void> _testNotification() async {
    await NotificationService.showNotification(
      title: '🔔 Test Notification',
      body: 'Notifications are working correctly!',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification sent')),
      );
    }

    await AnalyticsHelper.logEvent(name: 'test_notification_sent');
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
        title: Text(
          'Notification Settings',
          style: AppTheme.headlineMedium.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Prayer Notifications Section
                _buildSectionHeader('Prayer Notifications'),
                _buildCard([
                  _buildSwitchTile(
                    icon: Icons.notifications_active,
                    title: 'Enable Prayer Notifications',
                    subtitle: 'Get notified before each prayer time',
                    value: _prayerNotificationsEnabled,
                    onChanged: _togglePrayerNotifications,
                  ),
                  if (_prayerNotificationsEnabled) ...[
                    const Divider(height: 1),
                    _buildTimingSelector(),
                  ],
                ]),

                const SizedBox(height: 24),

                // Task Notifications Section
                _buildSectionHeader('Task Notifications'),
                _buildCard([
                  _buildSwitchTile(
                    icon: Icons.task_alt,
                    title: 'Enable Task Reminders',
                    subtitle: 'Get notified about upcoming tasks',
                    value: _taskNotificationsEnabled,
                    onChanged: _toggleTaskNotifications,
                  ),
                ]),

                const SizedBox(height: 24),

                // Test Notification
                _buildSectionHeader('Testing'),
                _buildCard([
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.send,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Send Test Notification',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Check if notifications are working',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: AppTheme.textSecondary,
                    ),
                    onTap: _testNotification,
                  ),
                ]),

                const SizedBox(height: 24),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Notifications require permission. If not working, check app settings.',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: AppTheme.headlineSmall.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: AppTheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: AppTheme.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.textSecondary,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primary,
      ),
    );
  }

  Widget _buildTimingSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notify me before prayer',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [5, 10, 15, 20, 30]
                .map((minutes) => _buildTimingChip(minutes))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimingChip(int minutes) {
    final isSelected = _prayerNotificationMinutes == minutes;
    return GestureDetector(
      onTap: () => _updatePrayerNotificationMinutes(minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary
              : AppTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : AppTheme.primary.withOpacity(0.3),
          ),
        ),
        child: Text(
          '$minutes min',
          style: AppTheme.bodySmall.copyWith(
            color: isSelected ? Colors.white : AppTheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
