import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dashboard_screen.dart';
import 'agenda_screen.dart';
import 'timeline_screen.dart';
import 'ai_assistant_screen.dart';
import 'prayer_schedule_screen.dart';
import 'mobile_spaces_screen.dart';
import 'settings_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';
import '../core/theme/app_theme.dart';
import '../core/services/auth_service.dart';
import '../core/services/data_migration_service.dart';
import '../core/services/user_preferences_service.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => MainLayoutState();
}

class MainLayoutState extends State<MainLayout> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isCollapsed = false;
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;
  bool _isPrayerModeEnabled = true; // Default to prayer mode
  String _appTitle = 'TaskFlow Pro'; // Dynamic app title based on mode

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for data migration on first load
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
  
  List<NavigationItem> get _navigationItems {
    final List<NavigationItem> items = [
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
    ];

    // Add Prayer Schedule only if prayer mode is enabled
    if (_isPrayerModeEnabled) {
      items.add(
        NavigationItem(
          icon: Icons.access_time_outlined,
          selectedIcon: Icons.access_time_filled,
          label: 'Prayer Schedule',
          route: 'prayer_schedule',
        ),
      );
    }

    return items;
  }

  @override
  void initState() {
    super.initState();
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

    // Load prayer mode preference
    _loadPrayerMode();

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

  Future<void> _loadPrayerMode() async {
    final enabled = await UserPreferencesService.isPrayerModeEnabled();
    final title = await UserPreferencesService.getAppTitle();
    if (mounted) {
      setState(() {
        _isPrayerModeEnabled = enabled;
        _appTitle = title;
      });
    }
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
        return const DashboardScreen();
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
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 1200;
    final bool isTablet = MediaQuery.of(context).size.width > 600;
    final bool showDrawer = !isDesktop && !isTablet;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
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
    return Material(
      color: Colors.white,
      elevation: 0,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: AppTheme.borderLight,
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
                _appTitle,
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SearchScreen()),
                  );
                },
                color: AppTheme.textSecondary,
                splashRadius: 24,
              ),
            ),
            Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifications coming soon!')),
                  );
                },
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
                  value: 'profile',
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        AuthService.currentUser?.displayName ?? 'User',
                        style: AppTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'subscription',
                  child: Row(
                    children: [
                      const Icon(Icons.star_outline, size: 20),
                      const SizedBox(width: 12),
                      Text('Subscription', style: AppTheme.bodyMedium),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
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
                  case 'profile':
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfileScreen()),
                      );
                    }
                    break;
                  case 'subscription':
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Subscription management coming soon!')),
                      );
                    }
                    break;
                  case 'settings':
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      );
                    }
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
                          _appTitle,
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
                onTap: () {},
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
              color: isSelected ? AppTheme.primary.withOpacity(0.1) : null,
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
                          _appTitle,
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
                      color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
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