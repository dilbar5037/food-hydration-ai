import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/role_service.dart';
import '../../core/services/network_service.dart';
import '../../ui/components/app_card.dart';
import '../../ui/components/app_text_field.dart';
import '../../ui/components/error_banner.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    required this.authService,
    required this.roleService,
  });

  final AuthService authService;
  final RoleService roleService;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final NetworkService _networkService = NetworkService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  static const Color _primaryTeal = AppColors.teal;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;
  static const Color _textMuted = AppColors.textMuted;
  static const Color _backgroundLight = Color(0xFFF0FDFA);

  static final RegExp _hasUpper = RegExp(r'[A-Z]');
  static final RegExp _hasLower = RegExp(r'[a-z]');
  static final RegExp _hasDigit = RegExp(r'[0-9]');
  static final RegExp _hasSpecial = RegExp(
    r"""[!@#\$%\^&\*\(\)_\+\-=\{\}\[\]:;"'<>,\.\?\/\\\|~]""",
  );

  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _meetsUpper => _hasUpper.hasMatch(_passwordController.text);
  bool get _meetsLower => _hasLower.hasMatch(_passwordController.text);
  bool get _meetsDigit => _hasDigit.hasMatch(_passwordController.text);
  bool get _meetsSpecial => _hasSpecial.hasMatch(_passwordController.text);
  bool get _isPasswordValid =>
      _hasMinLength &&
      _meetsUpper &&
      _meetsLower &&
      _meetsDigit &&
      _meetsSpecial;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Email and password are required.');
      return;
    }

    if (!_isPasswordValid) {
      _showError('Password must meet all requirements.');
      return;
    }

    try {
      final hasNetwork = await _networkService.hasNetwork();
      if (!hasNetwork) {
        _showError(
          'No internet / Supabase unreachable. Please check connection and retry.',
        );
        return;
      }
    } catch (_) {
      _showError(
        'No internet / Supabase unreachable. Please check connection and retry.',
      );
      return;
    }

    setState(() => _errorMessage = null);
    setState(() => _isLoading = true);
    try {
      final response =
          await widget.authService.signUp(email: email, password: password);
      if (response.user != null) {
        await widget.roleService.ensureProfileExists(email: email);
        if (!mounted) return;
        context.go('/');
      }
    } catch (e) {
      if (!mounted) return;
      _showError(_friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _friendlyError(Object error) {
    try {
      if (error is AuthRetryableFetchException ||
          error is SocketException ||
          error is TimeoutException) {
        return 'No internet / Supabase unreachable. Please check connection and retry.';
      }
      return error.toString();
    } catch (_) {
      return 'No internet / Supabase unreachable. Please check connection and retry.';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundLight,
      appBar: AppBar(
        title: const Text('Sign Up'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _textPrimary,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _backgroundLight,
              Color(0xFFE0F2FE),
              Color(0xFFFAFAFA),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _primaryTeal.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF06B6D4).withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_primaryTeal, Color(0xFF06B6D4)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryTeal.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.restaurant_menu,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      'Food & Hydration AI',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Track meals, water, and compliance easily.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            hintText: 'Email',
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: _primaryTeal,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            onChanged: (_) => setState(() {}),
                            hintText: 'Password',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: _primaryTeal,
                              size: 22,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: _textMuted,
                                size: 22,
                              ),
                              splashRadius: 24,
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _PasswordRuleRow(
                            label: 'Minimum 8 characters',
                            isMet: _hasMinLength,
                          ),
                          _PasswordRuleRow(
                            label: 'At least 1 uppercase letter',
                            isMet: _meetsUpper,
                          ),
                          _PasswordRuleRow(
                            label: 'At least 1 lowercase letter',
                            isMet: _meetsLower,
                          ),
                          _PasswordRuleRow(
                            label: 'At least 1 number',
                            isMet: _meetsDigit,
                          ),
                          _PasswordRuleRow(
                            label: 'At least 1 special character',
                            isMet: _meetsSpecial,
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            ErrorBanner(message: _errorMessage!),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading || !_isPasswordValid
                                  ? null
                                  : _handleSignup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryTeal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(fontSize: 14),
                                children: [
                                  TextSpan(
                                    text: 'Already have an account? ',
                                    style: TextStyle(
                                      color: _textSecondary,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Login',
                                    style: TextStyle(
                                      color: _primaryTeal,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 24,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordRuleRow extends StatelessWidget {
  const _PasswordRuleRow({
    required this.label,
    required this.isMet,
  });

  static const Color _successGreen = Color(0xFF10B981);
  static const Color _textSecondary = Color(0xFF64748B);

  final String label;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    final color = isMet ? _successGreen : _textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isMet ? _successGreen : Colors.transparent,
              border: Border.all(
                color: isMet ? _successGreen : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: isMet
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
