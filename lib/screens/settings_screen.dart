import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme/app_theme.dart';
import '../core/services/auth_service.dart';
import '../core/services/firebase_service.dart';
import '../core/services/data_sync_service.dart';
import '../core/services/user_preferences_service.dart';
import '../core/services/theme_service.dart';
import '../main.dart';
import 'prayer_settings_screen.dart';
import 'location_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSyncing = false;
  bool _isPrayerModeEnabled = true;
  ThemeMode _themeMode = ThemeMode.system;
  String _weekStartDay = 'monday';

  @override
  void initState() {
    super.initState();
    _loadPrayerMode();
    _loadThemeMode();
    _loadWeekStartDay();
  }

  Future<void> _loadWeekStartDay() async {
    final day = await UserPreferencesService.getWeekStartDay();
    if (mounted) {
      setState(() {
        _weekStartDay = day;
      });
    }
  }

  Future<void> _loadPrayerMode() async {
    final enabled = await UserPreferencesService.isPrayerModeEnabled();
    if (mounted) {
      setState(() {
        _isPrayerModeEnabled = enabled;
      });
    }
  }

  Future<void> _loadThemeMode() async {
    final mode = await ThemeService.getThemeMode();
    if (mounted) {
      setState(() {
        _themeMode = mode;
      });
    }
  }

  Future<void> _showWeekStartDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Week Starts On'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Monday'),
              value: 'monday',
              groupValue: _weekStartDay,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<String>(
              title: const Text('Sunday'),
              value: 'sunday',
              groupValue: _weekStartDay,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<String>(
              title: const Text('Saturday'),
              value: 'saturday',
              groupValue: _weekStartDay,
              onChanged: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null && result != _weekStartDay) {
      await UserPreferencesService.setWeekStartDay(result);
      setState(() {
        _weekStartDay = result;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Week starts on ${result.substring(0, 1).toUpperCase()}${result.substring(1)}'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    }
  }

  Future<void> _showThemeDialog() async {
    final result = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              subtitle: const Text('Always use light theme'),
              value: ThemeMode.light,
              groupValue: _themeMode,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              subtitle: const Text('Always use dark theme'),
              value: ThemeMode.dark,
              groupValue: _themeMode,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('System Default'),
              subtitle: const Text('Follow system theme'),
              value: ThemeMode.system,
              groupValue: _themeMode,
              onChanged: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null && result != _themeMode) {
      await ThemeService.setThemeMode(result);
      setState(() {
        _themeMode = result;
      });

      // Update the root app theme
      final appState = context.findAncestorStateOfType<TaskFlowProState>();
      appState?.updateThemeMode(result);

      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Theme changed to ${ThemeService.getThemeModeName(result)}'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    }
  }

  Future<void> _togglePrayerMode(bool value) async {
    await UserPreferencesService.setPrayerMode(value);
    if (mounted) {
      setState(() {
        _isPrayerModeEnabled = value;
      });

      // Show informational message
      final mode = value ? 'Prayer Mode' : 'Productivity Mode';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to $mode'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Delete Account', style: TextStyle(color: AppTheme.error)),
        content: const Text(
          'This will permanently delete your account and all associated data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AuthService.deleteAccount();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AuthScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleManualSync() async {
    setState(() => _isSyncing = true);
    
    try {
      final results = await DataSyncService.manualSync();
      
      if (mounted) {
        final message = results['success'] 
          ? 'Sync completed successfully'
          : 'Sync failed: ${results['message']}';
          
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final isAuthenticated = AuthService.isLoggedIn;
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text('Settings'),
        titleTextStyle: AppTheme.headlineMedium.copyWith(
          color: AppTheme.textPrimary,
        ),
      ),
      body: ListView(
        children: [
          // Account Section
          if (FirebaseService.isSupported) ...[
            _buildSectionHeader('Account'),
            if (isAuthenticated && user != null) ...[
              _buildAccountInfo(user),
              _buildSettingsTile(
                icon: Icons.sync,
                title: 'Sync Data',
                subtitle: 'Manually sync local data with cloud',
                onTap: _isSyncing ? null : _handleManualSync,
                trailing: _isSyncing 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              ),
              _buildSettingsTile(
                icon: Icons.logout,
                title: 'Sign Out',
                subtitle: 'Sign out of your account',
                onTap: _handleSignOut,
                color: AppTheme.warning,
              ),
            ] else ...[
              _buildSettingsTile(
                icon: Icons.login,
                title: 'Sign In',
                subtitle: 'Sign in to sync data across devices',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                },
              ),
            ],
            const SizedBox(height: AppTheme.space16),
          ],
          
          // General Settings
          _buildSectionHeader('General'),
          _buildSettingsTile(
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle: ThemeService.getThemeModeName(_themeMode),
            onTap: _showThemeDialog,
            trailing: Icon(
              _themeMode == ThemeMode.light
                  ? Icons.light_mode
                  : _themeMode == ThemeMode.dark
                      ? Icons.dark_mode
                      : Icons.brightness_auto,
              color: AppTheme.primary,
            ),
          ),
          _buildSettingsTile(
            icon: Icons.calendar_view_week_outlined,
            title: 'Week Starts On',
            subtitle: '${_weekStartDay.substring(0, 1).toUpperCase()}${_weekStartDay.substring(1)}',
            onTap: _showWeekStartDialog,
          ),
          _buildSettingsTile(
            icon: Icons.mosque,
            title: 'Prayer Mode',
            subtitle: _isPrayerModeEnabled
                ? 'Show prayer times and Islamic features'
                : 'Hide prayer-related features',
            trailing: Switch(
              value: _isPrayerModeEnabled,
              onChanged: _togglePrayerMode,
              activeColor: AppTheme.primary,
            ),
          ),
          _buildSettingsTile(
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Manage prayer and task notifications',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
              );
            },
          ),
          const SizedBox(height: AppTheme.space16),

          // Prayer Settings (only show when prayer mode is enabled)
          if (_isPrayerModeEnabled) ...[
            _buildSectionHeader('Prayer Settings'),
          _buildSettingsTile(
            icon: Icons.access_time,
            title: 'Prayer Durations',
            subtitle: 'Configure duration for each prayer',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrayerSettingsScreen()),
              );
            },
          ),
            _buildSettingsTile(
              icon: Icons.location_on,
              title: 'Location',
              subtitle: 'Set location for accurate prayer times',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LocationSettingsScreen()),
                );
              },
            ),
            const SizedBox(height: AppTheme.space16),
          ],
          
          // App Info
          _buildSectionHeader('About'),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: _isPrayerModeEnabled ? 'TaskFlow Pro' : 'TaskFlow',
            subtitle: 'Version 1.0.0',
            onTap: () {
              final appName = _isPrayerModeEnabled ? 'TaskFlow Pro' : 'TaskFlow';
              showAboutDialog(
                context: context,
                applicationName: appName,
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024 $appName. All rights reserved.',
              );
            },
          ),
          
          // Danger Zone
          if (isAuthenticated && FirebaseService.isSupported) ...[
            const SizedBox(height: AppTheme.space16),
            _buildSectionHeader('Danger Zone', color: AppTheme.error),
            _buildSettingsTile(
              icon: Icons.delete_forever,
              title: 'Delete Account',
              subtitle: 'Permanently delete your account and all data',
              onTap: _handleDeleteAccount,
              color: AppTheme.error,
            ),
          ],
          
          const SizedBox(height: AppTheme.space32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space16,
        AppTheme.space16,
        AppTheme.space16,
        AppTheme.space8,
      ),
      child: Text(
        title,
        style: AppTheme.labelMedium.copyWith(
          color: color ?? AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildAccountInfo(User user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.primary.withOpacity(0.1),
            backgroundImage: user.photoURL != null 
              ? NetworkImage(user.photoURL!)
              : null,
            child: user.photoURL == null
              ? Icon(Icons.person, size: 30, color: AppTheme.primary)
              : null,
          ),
          const SizedBox(width: AppTheme.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName ?? 'User',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (user.email != null)
                  Text(
                    user.email!,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Color? color,
    Widget? trailing,
  }) {
    final tileColor = color ?? AppTheme.textPrimary;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: ListTile(
          enabled: onTap != null,
          onTap: onTap,
          leading: Icon(icon, color: tileColor),
          title: Text(
            title,
            style: AppTheme.bodyLarge.copyWith(color: tileColor),
          ),
          subtitle: Text(
            subtitle,
            style: AppTheme.bodySmall.copyWith(
              color: tileColor.withOpacity(0.7),
            ),
          ),
          trailing: trailing ?? (onTap != null 
            ? Icon(Icons.chevron_right, color: AppTheme.textSecondary)
            : null),
        ),
      ),
    );
  }
}