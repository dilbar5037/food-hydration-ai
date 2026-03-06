import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../ui/theme/app_colors.dart';
import '../../../ui/theme/app_spacing.dart';
import '../../../ui/components/app_card.dart';
import '../../../ui/widgets/app_loading_view.dart';
import '../utils/daily_task_utils.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class TodayTodosScreen extends StatefulWidget {
  const TodayTodosScreen({super.key});

  @override
  State<TodayTodosScreen> createState() => _TodayTodosScreenState();
}

class _TodayTodosScreenState extends State<TodayTodosScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = true;
  int _mealsToday = 0;
  int _waterTodayMl = 0;
  int _goalMl = 2000; // default fallback; overwritten from user_metrics

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  /// Fetches today's meal count and total water intake from Supabase.
  /// Does NOT modify any data — read-only queries only.
  Future<void> _loadActivity() async {
    setState(() => _isLoading = true);

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay =
        DateTime(now.year, now.month, now.day + 1).toIso8601String();

    int meals = 0;
    int water = 0;
    int goal = 2000; // fallback

    try {
      // Fetch personal hydration goal from user_metrics
      // (same formula as hydration_screen.dart: weight_kg × 35 × activityFactor)
      final metrics = await _client
          .from('user_metrics')
          .select('weight_kg, activity_level')
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      final weightRaw = metrics?['weight_kg'];
      final activityLevel = metrics?['activity_level']?.toString();
      if (weightRaw != null) {
        final weightKg = (weightRaw as num).toDouble();
        final factor = activityLevel == 'high'
            ? 1.25
            : activityLevel == 'medium'
                ? 1.1
                : 1.0;
        goal = (weightKg * 35 * factor).round();
      }
    } catch (_) {}

    try {
      // Count today's meal logs
      final mealRows = await _client
          .from('meal_logs')
          .select('id')
          .eq('user_id', userId)
          .gte('eaten_at', startOfDay)
          .lt('eaten_at', endOfDay);
      meals = (mealRows as List<dynamic>).length;
    } catch (_) {}

    try {
      // Sum today's water intake
      final waterRows = await _client
          .from('water_logs')
          .select('amount_ml')
          .eq('user_id', userId)
          .gte('logged_at', startOfDay)
          .lt('logged_at', endOfDay);
      for (final row in (waterRows as List<dynamic>)) {
        final val = row['amount_ml'];
        if (val is num) water += val.toInt();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _mealsToday = meals;
      _waterTodayMl = water;
      _goalMl = goal;
      _isLoading = false;
    });
  }

  /// Builds the 7 auto-computed tasks from today's activity.
  List<DailyTask> _buildTasks() {
    return buildDailyTasks(
      mealsToday: _mealsToday,
      waterTodayMl: _waterTodayMl,
      goalMl: _goalMl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _buildTasks();
    final completedCount = tasks.where((t) => t.completed).length;
    final total = tasks.length;
    final progress = total == 0 ? 0.0 : completedCount / total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadActivity,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: AppLoadingView())
          : RefreshIndicator(
              onRefresh: _loadActivity,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // ── Progress header ────────────────────────────────────────
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Daily Progress',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '$completedCount / $total tasks',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Animated % labels row
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: progress),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, animatedValue, _) {
                            final pct = (animatedValue * 100).round();
                            final barColor = completedCount == total
                                ? AppColors.teal
                                : AppColors.coral;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  // Current %
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Current: $pct%',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: barColor,
                                            ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: AppSpacing.sm),

                                // Animated gradient progress bar track
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final trackWidth = constraints.maxWidth;
                                    final fillWidth =
                                        trackWidth * animatedValue;
                                    return Stack(
                                      children: [
                                        // Background track
                                        Container(
                                          height: 14,
                                          width: trackWidth,
                                          decoration: BoxDecoration(
                                            color: AppColors.border
                                                .withValues(alpha: 0.18),
                                            borderRadius:
                                                BorderRadius.circular(100),
                                          ),
                                        ),
                                        // Filled gradient bar
                                        Container(
                                          height: 14,
                                          width: fillWidth.clamp(
                                              0.0, trackWidth),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(100),
                                            gradient: LinearGradient(
                                              colors: completedCount == total
                                                  ? [
                                                      AppColors.teal,
                                                      const Color(0xFF0ED2A8),
                                                    ]
                                                  : [
                                                      AppColors.coral,
                                                      const Color(0xFFFFB347),
                                                    ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: barColor
                                                    .withValues(alpha: 0.35),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Percentage tick at fill position
                                        if (animatedValue > 0.05)
                                          Positioned(
                                            left: (fillWidth - 1).clamp(
                                                0.0, trackWidth - 2),
                                            top: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 2,
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.6),
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: AppSpacing.sm),

                                // Status message
                                Text(
                                  completedCount == total
                                      ? '🎉 All tasks completed!'
                                      : '${total - completedCount} task${total - completedCount == 1 ? '' : 's'} remaining',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: AppColors.textSecondary),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ── Task list ──────────────────────────────────────────────
                  ...tasks.asMap().entries.map((entry) {
                    final task = entry.value;
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.md),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            // Auto-completion icon
                            Icon(
                              task.completed
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: task.completed
                                  ? AppColors.teal
                                  : AppColors.textMuted,
                              size: 26,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            // Title + subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: task.completed
                                              ? AppColors.textPrimary
                                              : AppColors.textPrimary,
                                          decoration: task.completed
                                              ? TextDecoration.lineThrough
                                              : null,
                                          decorationColor:
                                              AppColors.textSecondary,
                                        ),
                                  ),
                                  if (task.subtitle != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      task.subtitle!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: task.completed
                                                ? AppColors.teal
                                                : AppColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: Text(
                      'Tasks auto-complete as you log meals & water',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
    );
  }
}
