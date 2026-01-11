import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/role_service.dart';

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
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

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
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'Food & Hydration AI',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Track meals, water, and compliance easily.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading || !_isPasswordValid
                              ? null
                              : _handleSignup,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Sign Up'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Back to login'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

  final String label;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    final color = isMet
        ? Colors.green
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
