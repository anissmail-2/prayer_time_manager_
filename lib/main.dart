import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/auth_wrapper.dart';
import 'core/theme/app_theme.dart';
import 'core/services/api_config_service.dart';
import 'core/services/firebase_service.dart';
import 'core/services/data_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize API configuration
  await ApiConfigService.initialize();
  
  // Initialize Firebase
  await FirebaseService.initialize();
  
  // Initialize data sync service
  await DataSyncService.initialize();
  
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

class TaskFlowPro extends StatelessWidget {
  const TaskFlowPro({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow Pro',
      debugShowCheckedModeBanner: false,
      
      // Theme configuration
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system, // Follows system theme
      
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