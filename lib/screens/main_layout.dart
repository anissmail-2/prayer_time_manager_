import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dashboard_screen.dart';
import 'agenda_screen.dart';
import 'timeline_screen.dart';
import 'ai_assistant_screen.dart';
import 'prayer_schedule_screen.dart';
import 'mobile_spaces_screen.dart';
import 'settings_screen.dart';
import '../core/theme/app_theme.dart';
import '../core/services/auth_service.dart';
import '../core/services/data_migration_service.dart';
import '../core/services/todo_service.dart';
import '../core/services/space_service.dart';
import '../models/task.dart';
import '../models/space.dart';
import '../widgets/task_details_dialog.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => MainLayoutState();
}

class MainLayoutState extends State<MainLayout> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isCollapsed = false;
  bool _migrationCheckDone = false;
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;

  void _scheduleMigrationCheck() {
    if (_migrationCheckDone) return;
    _migrationCheckDone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (await DataMigrationService.checkAndPromptMigration(context)) {
        if (mounted) {
          await DataMigrationService.showMigrationDialog(context);
        }
      }
    });
  }


  void navigateTo(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  
  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
      route: 'dashboard',
    ),
    NavigationItem(
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note,
      label: 'Agenda',
      route: 'agenda',
    ),
    NavigationItem(
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder,
      label: 'Spaces',
      route: 'spaces',
    ),
    NavigationItem(
      icon: Icons.timeline_outlined,
      selectedIcon: Icons.timeline,
      label: 'Timeline',
      route: 'timeline',
    ),
    NavigationItem(
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome,
      label: 'AI Assistant',
      route: 'ai_assistant',
    ),
    NavigationItem(
      icon: Icons.access_time_outlined,
      selectedIcon: Icons.access_time_filled,
      label: 'Prayer Schedule',
      route: 'prayer_schedule',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scheduleMigrationCheck();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _widthAnimation = Tween<double>(
      begin: 280,
      end: 80,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));
    
    // Set system UI
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isCollapsed = !_isCollapsed;
      if (_isCollapsed) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return DashboardScreen(onNavigate: navigateTo);
      case 1:
        return const AgendaScreen();
      case 2:
        return MobileSpacesScreen(
          onNavigateToTasks: () => navigateTo(1),
        );
      case 3:
        return const TimelineScreen();
      case 4:
        return const AIAssistantScreen();
      case 5:
        return const PrayerScheduleScreen();
      default:
        return DashboardScreen(onNavigate: navigateTo);
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openSearch() {
    showSearch<void>(
      context: context,
      delegate: _AppSearchDelegate(
        onSelectTask: _showTaskDetails,
        onSelectSpace: () => navigateTo(2),
      ),
    );
  }

  void _showTaskDetails(Task task) {
    showDialog(
      context: context,
      builder: (context) => TaskDetailsDialog(task: task),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 1200;
    final bool isTablet = MediaQuery.of(context).size.width > 600;
    final bool showDrawer = !isDesktop && !isTablet;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: showDrawer ? _buildMobileDrawer() : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!showDrawer) _buildSidebar(),
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(showDrawer),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool showMobileMenu) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    return Material(
      color: surfaceColor,
      elevation: 0,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            if (showMobileMenu)
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  color: AppTheme.textPrimary,
                  splashRadius: 24,
                ),
              )
            else
              const SizedBox(width: 16),
            Expanded(
              child: Text(
                'TaskFlow Pro',
                style: AppTheme.headlineMedium.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Quick actions with proper tap targets
            Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Search tasks and spaces',
                onPressed: _openSearch,
                color: AppTheme.textSecondary,
                splashRadius: 24,
              ),
            ),
            const SizedBox(width: 8),
            // Profile
            PopupMenuButton<String>(
              offset: const Offset(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      const Icon(Icons.settings_outlined, size: 20),
                      const SizedBox(width: 12),
                      Text('Settings', style: AppTheme.bodyMedium),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'signout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, size: 20),
                      const SizedBox(width: 12),
                      Text('Sign Out', style: AppTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                switch (value) {
                  case 'settings':
                    _openSettings();
                    break;
                  case 'signout':
                    await AuthService.signOut();
                    break;
                }
              },
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primary,
                    backgroundImage: AuthService.currentUser?.photoURL != null
                        ? NetworkImage(AuthService.currentUser!.photoURL!)
                        : null,
                    child: AuthService.currentUser?.photoURL == null
                        ? Text(
                            (AuthService.currentUser?.displayName ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        return Container(
          width: _widthAnimation.value,
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            border: Border(
              right: BorderSide(
                color: AppTheme.borderLight,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Logo section
              Container(
                height: 64,
                padding: EdgeInsets.symmetric(
                  horizontal: _isCollapsed ? 16 : 24,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: AppTheme.primary,
                      size: 32,
                    ),
                    if (!_isCollapsed) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'TaskFlow',
                          style: AppTheme.headlineSmall.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    IconButton(
                      icon: Icon(
                        _isCollapsed ? Icons.menu_open : Icons.menu,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: _toggleSidebar,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Navigation items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _navigationItems.length,
                  itemBuilder: (context, index) {
                    final item = _navigationItems[index];
                    final isSelected = _selectedIndex == index;
                    
                    return _buildNavItem(
                      item: item,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedIndex = index),
                    );
                  },
                ),
              ),
              // Bottom section
              const Divider(height: 1),
              _buildNavItem(
                item: NavigationItem(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: 'Settings',
                  route: 'settings',
                ),
                isSelected: false,
                onTap: _openSettings,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required NavigationItem item,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _isCollapsed ? 8 : 12,
        vertical: 2,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: _isCollapsed ? 16 : 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                  size: 24,
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: AppTheme.bodyLarge.copyWith(
                        color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: AppTheme.surfaceLight,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.primary,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'TaskFlow Pro',
                          style: AppTheme.headlineMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _navigationItems.length,
                itemBuilder: (context, index) {
                  final item = _navigationItems[index];
                  final isSelected = _selectedIndex == index;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Material(
                      color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: ListTile(
                        leading: Icon(
                          isSelected ? item.selectedIcon : item.icon,
                          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                        ),
                        title: Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onTap: () {
                          setState(() => _selectedIndex = index);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
                title: Text('Settings', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _openSettings();
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

}

class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;

  NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });
}

/// Searches task titles/descriptions and space names.
///
/// Selecting a task opens [TaskDetailsDialog]; selecting a space switches
/// to the Spaces tab.
class _AppSearchDelegate extends SearchDelegate<void> {
  final void Function(Task task) onSelectTask;
  final VoidCallback onSelectSpace;

  _AppSearchDelegate({
    required this.onSelectTask,
    required this.onSelectSpace,
  }) : super(searchFieldLabel: 'Search tasks and spaces');

  Future<(List<Task>, List<Space>)> _search(String query) async {
    final lower = query.toLowerCase();
    final tasks = await TodoService.getAllTasks();
    final spaces = await SpaceService.getAllSpaces();

    final matchedTasks = tasks.where((task) {
      return task.title.toLowerCase().contains(lower) ||
          (task.description?.toLowerCase().contains(lower) ?? false);
    }).toList();

    final matchedSpaces = spaces.where((space) {
      return space.name.toLowerCase().contains(lower) ||
          (space.description?.toLowerCase().contains(lower) ?? false);
    }).toList();

    return (matchedTasks, matchedSpaces);
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: 'Clear',
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchBody(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchBody(context);

  Widget _buildSearchBody(BuildContext context) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return Center(
        child: Text(
          'Type to search tasks and spaces',
          style: AppTheme.bodyLarge.copyWith(color: AppTheme.textSecondary),
        ),
      );
    }

    return FutureBuilder<(List<Task>, List<Space>)>(
      future: _search(trimmed),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Search failed: ${snapshot.error}',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.error),
            ),
          );
        }

        final (tasks, spaces) = snapshot.data ?? (<Task>[], <Space>[]);
        if (tasks.isEmpty && spaces.isEmpty) {
          return Center(
            child: Text(
              'No results for "$trimmed"',
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.textSecondary),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
          children: [
            if (tasks.isNotEmpty) _buildSectionLabel('Tasks'),
            ...tasks.map(
              (task) => ListTile(
                leading: Icon(Icons.task_alt, color: AppTheme.primary),
                title: Text(task.title, style: AppTheme.bodyLarge),
                subtitle: (task.description?.isNotEmpty ?? false)
                    ? Text(
                        task.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      )
                    : null,
                onTap: () {
                  close(context, null);
                  onSelectTask(task);
                },
              ),
            ),
            if (spaces.isNotEmpty) _buildSectionLabel('Spaces'),
            ...spaces.map(
              (space) => ListTile(
                leading: Icon(Icons.folder_outlined, color: AppTheme.secondary),
                title: Text(space.name, style: AppTheme.bodyLarge),
                subtitle: (space.description?.isNotEmpty ?? false)
                    ? Text(
                        space.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      )
                    : null,
                onTap: () {
                  close(context, null);
                  onSelectSpace();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space16,
        AppTheme.space16,
        AppTheme.space16,
        AppTheme.space8,
      ),
      child: Text(
        label,
        style: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
      ),
    );
  }
}