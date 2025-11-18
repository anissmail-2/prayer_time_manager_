import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/auth_wrapper.dart';
import 'core/theme/app_theme.dart';
import 'core/services/api_config_service.dart';
import 'core/services/firebase_service.dart';
import 'core/services/data_sync_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize API configuration
  await ApiConfigService.initialize();
  
  // Initialize Firebase
  await FirebaseService.initialize();
  
  // Initialize data sync service
  await DataSyncService.initialize();

  // Initialize notification service
  await NotificationService.initialize();

  // Schedule daily prayer notifications
  await NotificationService.schedulePrayerNotifications();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const TaskFlowPro());
}

class TaskFlowPro extends StatefulWidget {
  const TaskFlowPro({super.key});

  @override
  State<TaskFlowPro> createState() => TaskFlowProState();
}

class TaskFlowProState extends State<TaskFlowPro> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final mode = await ThemeService.getThemeMode();
    if (mounted) {
      setState(() {
        _themeMode = mode;
      });
    }
  }

  // Public method to update theme mode from settings
  void updateThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow Pro',
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _themeMode,

      // Navigation
      home: const AuthWrapper(),

      // Page transitions
      builder: (context, child) {
        return MediaQuery(
          // Prevent system text scaling from breaking layouts
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2)),
          ),
          child: child!,
        );
      },
    );
  }
}