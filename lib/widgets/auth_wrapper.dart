import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/auth_service.dart';
import '../core/services/firebase_service.dart';
import '../core/services/user_preferences_service.dart';
import '../screens/auth_screen.dart';
import '../screens/main_layout.dart';
import '../screens/onboarding_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if onboarding is completed
    return FutureBuilder<bool>(
      future: UserPreferencesService.isOnboardingCompleted(),
      builder: (context, onboardingSnapshot) {
        if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Show onboarding for first-time users
        if (onboardingSnapshot.data == false) {
          return const OnboardingScreen();
        }

        // Skip authentication on unsupported platforms (like Linux)
        if (!FirebaseService.isSupported) {
          return const MainLayout();
        }

        // Continue with normal auth flow
        return _buildAuthFlow();
      },
    );
  }

  Widget _buildAuthFlow() {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      // Force rebuild
                      (context as Element).markNeedsBuild();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        // Check authentication state
        if (snapshot.hasData && snapshot.data != null) {
          // User is logged in
          return const MainLayout();
        } else {
          // User is not logged in
          return const AuthScreen();
        }
      },
    );
  }
}
