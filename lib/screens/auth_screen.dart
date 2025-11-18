import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/auth_service.dart';
import '../core/theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      User? user;
      if (_isLogin) {
        user = await AuthService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        user = await AuthService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );
      }

      if (user != null && mounted) {
        // Navigate to main app - will be handled by auth state listener
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await AuthService.signInWithGoogle();
      if (user != null && mounted) {
        // Navigate to main app - will be handled by auth state listener
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1200;
    final isTablet = size.width > 600;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primary.withValues(alpha: 0.1),
              AppTheme.secondary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppTheme.space24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 400 : (isTablet ? 500 : double.infinity),
                ),
                child: Card(
                  elevation: isDesktop ? 8 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(
                      isDesktop ? AppTheme.space32 : AppTheme.space24,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo and Title
                          Icon(
                            Icons.task_alt,
                            size: 64,
                            color: AppTheme.primary,
                          ),
                          SizedBox(height: AppTheme.space16),
                          Text(
                            'TaskFlow Pro',
                            style: AppTheme.headlineLarge.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: AppTheme.space8),
                          Text(
                            _isLogin
                                ? 'Welcome back!'
                                : 'Create your account',
                            style: AppTheme.bodyLarge.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: AppTheme.space32),

                          // Error message
                          if (_errorMessage != null) ...[
                            Container(
                              padding: EdgeInsets.all(AppTheme.space12),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                border: Border.all(
                                  color: AppTheme.error.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: AppTheme.error,
                                    size: 20,
                                  ),
                                  SizedBox(width: AppTheme.space8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: AppTheme.space16),
                          ],

                          // Name field (sign up only)
                          if (!_isLogin) ...[
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                ),
                              ),
                              textCapitalization: TextCapitalization.words,
                              enabled: !_isLoading,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your name';
                                }
                                if (value.trim().length < 2) {
                                  return 'Name must be at least 2 characters';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: AppTheme.space16),
                          ],

                          // Email field
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            enabled: !_isLoading,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value.trim())) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: AppTheme.space16),

                          // Password field
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              ),
                            ),
                            obscureText: _obscurePassword,
                            enabled: !_isLoading,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (!_isLogin && value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),

                          // Forgot password link
                          if (_isLogin) ...[
                            SizedBox(height: AppTheme.space8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        _showForgotPasswordDialog();
                                      },
                                child: Text(
                                  'Forgot password?',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          SizedBox(height: AppTheme.space24),

                          // Submit button
                          FilledButton(
                            onPressed: _isLoading ? null : _handleSubmit,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _isLogin ? 'Sign In' : 'Create Account',
                                    style: AppTheme.bodyLarge.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),

                          SizedBox(height: AppTheme.space16),

                          // Divider
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppTheme.space16,
                                ),
                                child: Text(
                                  'OR',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),

                          SizedBox(height: AppTheme.space16),

                          // Google sign in button
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _handleGoogleSignIn,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              ),
                            ),
                            icon: Image.network(
                              'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                              height: 20,
                              width: 20,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.g_mobiledata, size: 20);
                              },
                            ),
                            label: Text(
                              'Continue with Google',
                              style: AppTheme.bodyLarge,
                            ),
                          ),

                          SizedBox(height: AppTheme.space24),

                          // Toggle auth mode
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isLogin
                                    ? "Don't have an account?"
                                    : 'Already have an account?',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _isLogin = !_isLogin;
                                          _errorMessage = null;
                                          _formKey.currentState?.reset();
                                        });
                                      },
                                child: Text(
                                  _isLogin ? 'Sign Up' : 'Sign In',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(text: _emailController.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: AppTheme.space16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter your email'),
                  ),
                );
                return;
              }

              try {
                await AuthService.resetPassword(email);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Password reset email sent to $email'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Send Reset Email'),
          ),
        ],
      ),
    );
  }
}