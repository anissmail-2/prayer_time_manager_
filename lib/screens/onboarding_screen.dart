import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/services/user_preferences_service.dart';
import '../core/helpers/analytics_helper.dart';
import 'main_layout.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _selectedMode;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _selectMode(String mode) {
    setState(() => _selectedMode = mode);
  }

  Future<void> _completeOnboarding() async {
    if (_selectedMode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a mode to continue')),
      );
      return;
    }

    // Save preferences
    await UserPreferencesService.setAppMode(_selectedMode!);
    await UserPreferencesService.completeOnboarding();

    // Navigate to main app
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainLayout()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: List.generate(
                  3,
                  (index) => Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(
                        left: index == 0 ? 0 : 4,
                        right: index == 2 ? 0 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? AppTheme.primary
                            : AppTheme.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Page view
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomePage(),
                  _buildModeSelectionPage(),
                  _buildReadyPage(),
                ],
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _currentPage == 2
                        ? _completeOnboarding
                        : _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentPage == 2 ? 'Get Started' : 'Next',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // App icon placeholder
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.task_alt,
              size: 64,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'Welcome to TaskFlow',
            style: AppTheme.headlineLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          Text(
            'Your intelligent task management companion that adapts to your lifestyle',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          _buildFeatureItem(
            Icons.check_circle_outline,
            'Smart Task Organization',
            'Organize tasks with spaces, priorities, and schedules',
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            Icons.offline_bolt,
            'Offline-First',
            'Full functionality without internet connection',
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            Icons.psychology,
            'AI Assistant',
            'Get help with task management using AI',
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelectionPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Choose Your Experience',
            style: AppTheme.headlineLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          Text(
            'Select the mode that best fits your lifestyle',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // Prayer Mode Card
          _buildModeCard(
            mode: 'prayer',
            icon: Icons.mosque,
            title: 'Prayer Mode',
            subtitle: 'With Islamic Prayer Times',
            description:
                'Schedule tasks relative to prayer times, get prayer reminders, and integrate your spiritual practice with productivity',
            features: [
              '🕌 Accurate prayer times for your location',
              '📅 Schedule tasks before/after prayers',
              '⏰ Prayer time notifications',
              '✨ Islamic calendar integration',
            ],
          ),
          const SizedBox(height: 24),

          // Productivity Mode Card
          _buildModeCard(
            mode: 'productivity',
            icon: Icons.rocket_launch,
            title: 'Productivity Mode',
            subtitle: 'Pure Task Management',
            description:
                'Focus on productivity without prayer-related features. Perfect for anyone who wants a clean task management experience',
            features: [
              '✅ Smart task organization',
              '📊 Timeline and agenda views',
              '🤖 AI-powered assistance',
              '🎯 Goal tracking and spaces',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadyPage() {
    final isPrayerMode = _selectedMode == 'prayer';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 64,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'You\'re All Set!',
            style: AppTheme.headlineLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          Text(
            isPrayerMode
                ? 'Welcome to TaskFlow Pro with Prayer Times'
                : 'Welcome to TaskFlow - Your Productivity Partner',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isPrayerMode ? Icons.mosque : Icons.workspace_premium,
                  size: 48,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'You\'ve selected:',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isPrayerMode ? 'Prayer Mode' : 'Productivity Mode',
                  style: AppTheme.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You can change this anytime in Settings',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
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

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppTheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required String mode,
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required List<String> features,
  }) {
    final isSelected = _selectedMode == mode;

    return GestureDetector(
      onTap: () => _selectMode(mode),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.borderLight,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : AppTheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.headlineSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.primary,
                    size: 28,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ...features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        feature,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
