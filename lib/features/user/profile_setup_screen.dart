import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_radius.dart';
import '../../ui/theme/app_spacing.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final _client = Supabase.instance.client;

  String _activityLevel = 'low';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _error = 'No authenticated user found.';
        _isLoading = false;
      });
      return;
    }

    try {
      final existing = await _client
          .from('user_metrics')
          .select()
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      if (existing == null) {
        await _client.from('user_metrics').insert({
          'user_id': userId,
          'activity_level': 'low',
        });
        _activityLevel = 'low';
      } else {
        final age = existing['age'] as int?;
        final weight = existing['weight_kg'];
        final height = existing['height_cm'];
        final level = existing['activity_level'] as String?;

        _ageController.text = age?.toString() ?? '';
        _weightController.text =
            weight != null ? weight.toString() : '';
        _heightController.text =
            height != null ? height.toString() : '';
        _activityLevel = level ?? 'low';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _error = 'No authenticated user found.';
      });
      return;
    }

    final ageText = _ageController.text.trim();
    final weightText = _weightController.text.trim();
    final heightText = _heightController.text.trim();

    final age = ageText.isEmpty ? null : int.tryParse(ageText);
    final weight =
        weightText.isEmpty ? null : double.tryParse(weightText);
    final height =
        heightText.isEmpty ? null : double.tryParse(heightText);

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await _client.from('user_metrics').update({
        'age': age,
        'weight_kg': weight,
        'height_cm': height,
        'activity_level': _activityLevel,
      }).eq('user_id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile Setup'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error Banner
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              // Body Metrics Section
              Text(
                'Health Metrics',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Age Input
              _buildInputField(
                controller: _ageController,
                label: 'Age',
                hint: 'e.g., 25',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.cake_outlined,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Weight Input
              _buildInputField(
                controller: _weightController,
                label: 'Weight (kg)',
                hint: 'e.g., 60.0',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: Icons.scale_outlined,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Height Input
              _buildInputField(
                controller: _heightController,
                label: 'Height (cm)',
                hint: 'e.g., 170',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: Icons.height_outlined,
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Activity Level Section
              Text(
                'Activity Level',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Activity Level Dropdown
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: DropdownButtonFormField<String>(
                  value: _activityLevel,
                  items: const [
                    DropdownMenuItem(
                      value: 'low',
                      child: Text('Low'),
                    ),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text('Medium'),
                    ),
                    DropdownMenuItem(
                      value: 'high',
                      child: Text('High'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _activityLevel = value;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    prefixIcon: const Icon(
                      Icons.local_fire_department_outlined,
                      color: AppColors.teal,
                    ),
                  ),
                  isExpanded: true,
                  iconSize: 24,
                  dropdownColor: AppColors.surface,
                ),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    disabledBackgroundColor:
                        AppColors.teal.withOpacity(0.5),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Save',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputType keyboardType,
    required IconData prefixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          prefixIcon: Icon(
            prefixIcon,
            color: AppColors.teal,
          ),
          hintStyle: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textMuted),
          labelStyle: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
