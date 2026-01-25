import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_service.dart';
import '../../ui/components/app_card.dart';
import '../../ui/components/app_icon_badge.dart';
import '../../ui/components/app_list_tile_card.dart';
import '../../ui/components/primary_button.dart';
import '../../ui/components/section_header.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../hydration/hydration_screen.dart';
import 'health_dashboard_screen.dart';
import 'scan_meal_screen.dart';
import 'meal_history_screen.dart';
import 'profile_setup_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  static const Color _primaryTeal = AppColors.teal;
  static const Color _primaryTealLight = Color(0xFFCCFBF1);
  static const Color _accentCoral = AppColors.coral;
  static const Color _accentCoralLight = Color(0xFFFFEDD5);
  static const Color _softPurple = AppColors.purple;
  static const Color _softPurpleLight = Color(0xFFEDE9FE);
  static const Color _softPink = AppColors.pink;
  static const Color _softPinkLight = Color(0xFFFCE7F3);
  static const Color _bgPrimary = AppColors.background;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;
  static const Color _textMuted = AppColors.textMuted;

  Future<void> _signOut(BuildContext context) async {
    await widget.authService.signOut();
    if (context.mounted) {
      context.go('/login');
    }
  }

  Future<void> _openProfileSetup() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ProfileSetupScreen(),
      ),
    );
    if (result == true && mounted) {
      // No-op: keep existing flow without adding logic.
    }
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    }
    if (hour < 17) {
      return 'Good Afternoon';
    }
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      appBar: AppBar(
        title: Text(
          'Wellness',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
        ),
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF0FDFA),
                _bgPrimary,
              ],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greetingText(),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: _textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Welcome back',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _textPrimary,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: _primaryTealLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Activity level: --',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: _primaryTeal),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const AppIconBadge(
                      icon: Icons.person_outline,
                      backgroundColor: _softPurpleLight,
                      iconColor: _softPurple,
                      size: 56,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(title: 'Health', accentColor: _primaryTeal),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const HealthDashboardScreen(),
                    ),
                  );
                },
                child: Row(
                  children: [
                    const AppIconBadge(
                      icon: Icons.dashboard_outlined,
                      backgroundColor: _primaryTeal,
                      iconColor: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dashboard',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'View Health',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: _textMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: _textMuted),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HydrationScreen(),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppIconBadge(
                            icon: Icons.water_drop_outlined,
                            backgroundColor: _softPurple,
                            iconColor: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Hydration',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Track Water',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: _textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppCard(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MealHistoryScreen(),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppIconBadge(
                            icon: Icons.history,
                            backgroundColor: _accentCoralLight,
                            iconColor: _accentCoral,
                            size: 48,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Meal Log',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'View Log',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: _textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              const SectionHeader(
                title: 'Meal Tracking',
                accentColor: _accentCoral,
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: EdgeInsets.zero,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ScanMealScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [_primaryTeal, Color(0xFF0F766E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Scan Your Meal',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Quick AI-powered food scan',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: 'Scan Now',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ScanMealScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const SectionHeader(
                title: 'Profile & Account',
                accentColor: _softPurple,
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    AppListTileCard(
                      title: 'Edit Profile',
                      icon: Icons.person_outline,
                      iconColor: _softPurple,
                      iconBackground: _softPurpleLight,
                      onTap: _openProfileSetup,
                      showDivider: true,
                    ),
                    AppListTileCard(
                      title: 'Sign Out',
                      icon: Icons.logout,
                      iconColor: _softPink,
                      iconBackground: _softPinkLight,
                      onTap: () => _signOut(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
