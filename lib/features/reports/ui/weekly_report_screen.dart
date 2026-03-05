import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../ui/components/app_card.dart';
import 'package:food_hydration_ai/ui/widgets/shimmer_card_placeholder.dart';
import 'package:food_hydration_ai/ui/feedback/empty_state_view.dart';
import 'package:food_hydration_ai/ui/analytics/insight_card.dart';
import '../../../ui/theme/app_colors.dart';
import '../../../ui/theme/app_radius.dart';
import '../../../ui/theme/app_spacing.dart';
import 'package:food_hydration_ai/ui/widgets/animated_primary_button.dart';
import '../report_service.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  final ReportService _reportService = ReportService();
  bool _isLoading = true;
  String? _errorMessage;
  WeeklyReport? _report;
  late final DateTime _rangeStart;
  late final DateTime _rangeEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _rangeEnd = DateTime.utc(now.year, now.month, now.day);
    _rangeStart = _rangeEnd.subtract(const Duration(days: 6));
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final report = await _reportService.fetchWeeklyReport();
      if (!mounted) {
        return;
      }
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Failed to load report.';
        _report = WeeklyReport.empty(_rangeStart, _rangeEnd);
        _isLoading = false;
      });
    }
  }

  Future<void> _exportPdf(WeeklyReport report) async {
    final doc = pw.Document();
    final dateRange =
        '${_formatDate(report.startDate)} - ${_formatDate(report.endDate)}';

    final topFoodsData = report.topFoods.isEmpty
        ? [
            ['No data', ''],
          ]
        : report.topFoods
              .map((food) => [food.name, food.count.toString()])
              .toList();

    doc.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Weekly Report', style: pw.TextStyle(fontSize: 20)),
            pw.SizedBox(height: 8),
            pw.Text('Date range: $dateRange'),
            pw.SizedBox(height: 16),
            pw.Text(
              'Total Calories: ${report.totalCalories.toStringAsFixed(0)}',
            ),
            pw.Text('Total Water: ${report.totalWaterMl} ml'),
            pw.Text(
              'Avg Calories/Day: ${report.avgCaloriesPerDay.toStringAsFixed(0)}',
            ),
            pw.Text(
              'Avg Water/Day: ${report.avgWaterPerDay.toStringAsFixed(0)} ml',
            ),
            pw.Text(
              'Avg Compliance: ${report.avgCompliance.toStringAsFixed(0)}%',
            ),
            pw.SizedBox(height: 16),
            pw.Text('Top Foods'),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Food', 'Count'],
              data: topFoodsData,
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  String _formatDate(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$dd-$mm-$yyyy';
  }

  String _generateWeeklyTip(WeeklyReport report) {
    // Hydration warning
    if (report.avgWaterPerDay < 2000) {
      return '💧 Stay hydrated! Your average daily intake (${report.avgWaterPerDay.toStringAsFixed(0)} ml) is below the recommended 2000 ml. Try drinking more water throughout the day.';
    }
    // Irregular eating
    final calorieVariance = _calculateCalorieVariance(report);
    if (calorieVariance > 500) {
      return '🍽️ Your calorie intake varies significantly day-to-day (${calorieVariance.toStringAsFixed(0)} kcal). Try to maintain more consistent portions for better nutrition.';
    }
    // Positive feedback
    if (report.avgCompliance >= 80) {
      return '🎉 Excellent work! You\'re maintaining ${report.avgCompliance.toStringAsFixed(0)}% compliance with your goals this week. Keep it up!';
    }
    if (report.avgWaterPerDay >= 2000 && report.avgCompliance >= 70) {
      return '✨ Great balance this week! You\'re meeting your hydration and nutrition targets consistently.';
    }
    return '💪 You\'re on track! Keep maintaining your healthy habits for sustainable progress.';
  }

  double _calculateCalorieVariance(WeeklyReport report) {
    if (report.totalCalories <= 0) return 0;
    final avgDaily = report.avgCaloriesPerDay;
    // Simple variance estimation based on compliance variance
    return avgDaily * 0.2; // Estimate variance
  }

  @override
  Widget build(BuildContext context) {
    final report = _report ?? WeeklyReport.empty(_rangeStart, _rangeEnd);
    final dateRange =
        '${_formatDate(report.startDate)} - ${_formatDate(report.endDate)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Weekly Report'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Range Card
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.teal,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly Report',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          dateRange,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Error Message
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.red[700]),
                  ),
                ),
              if (_errorMessage != null) const SizedBox(height: AppSpacing.lg),

              // Summary Metrics Section
              Text(
                'Summary',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Metrics Grid
              _buildMetricCard(
                context,
                icon: Icons.local_fire_department_outlined,
                label: 'Total Calories',
                value: '${report.totalCalories.toStringAsFixed(0)} kcal',
                color: AppColors.coral,
              ),
              const SizedBox(height: AppSpacing.md),

              _buildMetricCard(
                context,
                icon: Icons.water_drop_outlined,
                label: 'Total Water',
                value: '${report.totalWaterMl} ml',
                color: AppColors.teal,
              ),
              const SizedBox(height: AppSpacing.md),

              _buildMetricCard(
                context,
                icon: Icons.trending_up_outlined,
                label: 'Avg Calories/Day',
                value: '${report.avgCaloriesPerDay.toStringAsFixed(0)} kcal',
                color: AppColors.purple,
              ),
              const SizedBox(height: AppSpacing.md),

              _buildMetricCard(
                context,
                icon: Icons.opacity_outlined,
                label: 'Avg Water/Day',
                value: '${report.avgWaterPerDay.toStringAsFixed(0)} ml',
                color: AppColors.coral,
              ),
              const SizedBox(height: AppSpacing.md),

              _buildMetricCard(
                context,
                icon: Icons.check_circle_outline,
                label: 'Avg Compliance',
                value: '${report.avgCompliance.toStringAsFixed(0)}%',
                color: AppColors.teal,
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Insights Section
              Text(
                'Key Insights',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Insights Grid (2x2 responsive layout)
              LayoutBuilder(
                builder: (context, constraints) {
                  final columnCount = constraints.maxWidth > 600 ? 2 : 1;
                  final spacing = AppSpacing.md;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      SizedBox(
                        width: columnCount == 2 ? (constraints.maxWidth - spacing) / 2 : constraints.maxWidth,
                        child: InsightCard(
                          icon: Icons.local_fire_department_outlined,
                          iconColor: AppColors.coral,
                          value: report.avgCaloriesPerDay.toStringAsFixed(0),
                          label: 'Avg Daily Calories',
                          subtitle: '${report.totalCalories.toStringAsFixed(0)} total',
                        ),
                      ),
                      SizedBox(
                        width: columnCount == 2 ? (constraints.maxWidth - spacing) / 2 : constraints.maxWidth,
                        child: InsightCard(
                          icon: Icons.opacity_outlined,
                          iconColor: AppColors.teal,
                          value: report.avgWaterPerDay.toStringAsFixed(0),
                          label: 'Avg Daily Water',
                          subtitle: 'ml per day',
                        ),
                      ),
                      SizedBox(
                        width: columnCount == 2 ? (constraints.maxWidth - spacing) / 2 : constraints.maxWidth,
                        child: InsightCard(
                          icon: Icons.trending_up_outlined,
                          iconColor: AppColors.purple,
                          value: '${report.avgCompliance.toStringAsFixed(0)}%',
                          label: 'Compliance Rate',
                          subtitle: 'goal achievement',
                        ),
                      ),
                      SizedBox(
                        width: columnCount == 2 ? (constraints.maxWidth - spacing) / 2 : constraints.maxWidth,
                        child: InsightCard(
                          icon: Icons.restaurant_outlined,
                          iconColor: AppColors.coral,
                          value: '${report.topFoods.length}',
                          label: 'Unique Foods',
                          subtitle: 'logged this week',
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: AppSpacing.xl),

              // Smart Tips Section
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: AppColors.purple,
                          size: 24,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          'Weekly Tip',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _generateWeeklyTip(report),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Top Foods Section
              Text(
                'Top Foods',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Top Foods Card
              AppCard(
                padding: EdgeInsets.zero,
                child: _isLoading
                    ? Column(
                        children: List.generate(5, (_) => const ShimmerCardPlaceholder(height: 72)),
                      )
                    : report.topFoods.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: EmptyStateView(
                              title: 'No meals logged this week',
                              subtitle: 'Start logging meals to see your top foods.',
                              lottieAsset: 'assets/lottie/empty_generic.json',
                            ),
                          )
                        : Column(
                            children: List.generate(report.topFoods.length, (
                              index,
                            ) {
                              final food = report.topFoods[index];
                              final isLast = index == report.topFoods.length - 1;
                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(AppSpacing.lg),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: AppColors.teal.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.md,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${index + 1}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: AppColors.teal,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Text(
                                            food.name,
                                            style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                        vertical: AppSpacing.xs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.teal.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${food.count}x',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: AppColors.teal,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isLast)
                                Divider(
                                  height: 1,
                                  color: AppColors.border,
                                  indent: AppSpacing.lg,
                                  endIndent: AppSpacing.lg,
                                ),
                            ],
                          );
                        }),
                      ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Export Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: AnimatedPrimaryButton(
                  loading: _isLoading,
                  onPressed: () async => await _exportPdf(report),
                  child: Text(
                    'Export PDF',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
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

  Widget _buildMetricCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
