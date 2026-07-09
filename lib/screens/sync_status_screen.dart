import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import '../core/services/data_sync_service.dart';
import '../core/services/todo_service.dart';
import '../core/services/space_service.dart';
import '../core/theme/app_theme.dart';

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  bool _isSyncing = false;
  String _syncStatus = '';
  Map<String, dynamic>? _lastSyncResult;

  @override
  void initState() {
    super.initState();
    _checkSyncStatus();
  }

  Future<void> _checkSyncStatus() async {
    if (!AuthService.isLoggedIn) {
      setState(() {
        _syncStatus = 'Not logged in - data stored locally only';
      });
      return;
    }

    try {
      final tasks = await TodoService.getAllTasks();
      final spaces = await SpaceService.getAllSpaces();

      if (!mounted) return;
      setState(() {
        _syncStatus = 'Connected to cloud';
        _lastSyncResult = {
          'tasks': tasks.length,
          'spaces': spaces.length,
          'userId': AuthService.userId,
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncStatus = 'Error checking sync status';
      });
    }
  }

  Future<void> _performManualSync() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = 'Syncing...';
    });

    try {
      final result = await DataSyncService.manualSync();

      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _syncStatus = result['message'] ?? 'Sync completed';
        _lastSyncResult = result;
      });

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data synced successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _syncStatus = 'Sync failed: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Sync Status'),
        backgroundColor: AppTheme.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sync Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isLoggedIn ? Icons.cloud_done : Icons.cloud_off,
                          color: isLoggedIn ? AppTheme.success : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: AppTheme.space8),
                        Text(
                          'Sync Status',
                          style: AppTheme.headlineSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      _syncStatus,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: AppTheme.space16),
            
            // Account Info
            if (isLoggedIn) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.space16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account',
                        style: AppTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppTheme.space8),
                      Text(
                        'Email: ${AuthService.currentUser?.email ?? 'Unknown'}',
                        style: AppTheme.bodyMedium,
                      ),
                      Text(
                        'User ID: ${AuthService.userId ?? 'Unknown'}',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: AppTheme.space16),
            ],
            
            // Data Summary
            if (_lastSyncResult != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.space16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Summary',
                        style: AppTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppTheme.space8),
                      Text(
                        'Tasks in cloud: ${_lastSyncResult!['tasks'] ?? _lastSyncResult!['firestoreTaskCount'] ?? 0}',
                        style: AppTheme.bodyMedium,
                      ),
                      Text(
                        'Spaces in cloud: ${_lastSyncResult!['spaces'] ?? 0}',
                        style: AppTheme.bodyMedium,
                      ),
                      if (_lastSyncResult!['localTaskCount'] != null)
                        Text(
                          'Local tasks: ${_lastSyncResult!['localTaskCount']}',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: AppTheme.space24),
            ],
            
            // Manual Sync Button
            if (isLoggedIn)
              Center(
                child: FilledButton.icon(
                  onPressed: _isSyncing ? null : _performManualSync,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sync),
                  label: Text(_isSyncing ? 'Syncing...' : 'Manual Sync'),
                ),
              ),
            
            if (!isLoggedIn) ...[
              const Spacer(),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 48,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(height: AppTheme.space16),
                    Text(
                      'Sign in to enable cloud sync',
                      style: AppTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'Your data is currently stored locally only',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ],
        ),
      ),
    );
  }
}