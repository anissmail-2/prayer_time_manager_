import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme/app_theme.dart';
import '../core/services/auth_service.dart';
import '../core/services/firebase_service.dart';
import '../core/services/data_sync_service.dart';
import 'prayer_settings_screen.dart';
import 'location_settings_screen.dart';
import 'auth_screen.dart';
import 'api_keys_screen.dart';
import 'sync_status_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSyncing = false;

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
        // Return to the root route; AuthWrapper's auth-state StreamBuilder
        // will show the AuthScreen once signed out.
        Navigator.of(context).popUntil((route) => route.isFirst);
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
          // Return to the root route; AuthWrapper's auth-state StreamBuilder
          // will show the AuthScreen once the account is gone.
          Navigator.of(context).popUntil((route) => route.isFirst);
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
                icon: Icons.cloud_outlined,
                title: 'Sync Status',
                subtitle: 'View cloud sync status and data summary',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SyncStatusScreen()),
                  );
                },
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
          
          // Prayer Settings
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

          // AI & API Configuration
          _buildSectionHeader('AI & API Configuration'),
          _buildSettingsTile(
            icon: Icons.key_outlined,
            title: 'API Keys',
            subtitle: 'Configure AI and voice transcription API keys',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ApiKeysScreen()),
              );
            },
          ),
          const SizedBox(height: AppTheme.space16),

          // App Info
          _buildSectionHeader('About'),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'TaskFlow Pro',
            subtitle: 'Version 1.0.0',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'TaskFlow Pro',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024 TaskFlow Pro. All rights reserved.',
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