import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../ui/components/app_card.dart';
import '../../../ui/theme/app_colors.dart';
import '../../../ui/theme/app_radius.dart';
import '../../../ui/theme/app_spacing.dart';
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
            ['No data', '']
          ]
        : report.topFoods
            .map((food) => [food.name, food.count.toString()])
            .toList();

    doc.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Weekly Report',
              style: pw.TextStyle(fontSize: 20),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Date range: $dateRange'),
            pw.SizedBox(height: 16),
            pw.Text('Total Calories: ${report.totalCalories.toStringAsFixed(0)}'),
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

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
    );
  }

  String _formatDate(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
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
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          dateRange,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
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
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red[700],
                        ),
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
                value:
                    '${report.totalCalories.toStringAsFixed(0)} kcal',
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
                value:
                    '${report.avgCaloriesPerDay.toStringAsFixed(0)} kcal',
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
                child: report.topFoods.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            Icon(
                              Icons.restaurant_outlined,
                              size: 48,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'No meals logged this week',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: List.generate(
                          report.topFoods.length,
                          (index) {
                            final food = report.topFoods[index];
                            final isLast =
                                index == report.topFoods.length - 1;
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(
                                    AppSpacing.lg,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppColors.teal
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(
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
                                                  fontWeight:
                                                      FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: AppSpacing.md,
                                      ),
                                      Expanded(
                                        child: Text(
                                          food.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight:
                                                    FontWeight.w500,
                                              ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                          horizontal:
                                              AppSpacing.sm,
                                          vertical: AppSpacing.xs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.teal
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(
                                                20,
                                              ),
                                        ),
                                        child: Text(
                                          '${food.count}x',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: AppColors.teal,
                                                fontWeight:
                                                    FontWeight.w600,
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
                          },
                        ),
                      ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Export Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      _isLoading ? null : () => _exportPdf(report),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadius.md),
                    ),
                    disabledBackgroundColor:
                        AppColors.teal.withOpacity(0.5),
                  ),
                  child: Text(
                    'Export PDF',
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
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
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
