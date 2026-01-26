import 'dart:async';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ui/components/app_card.dart';
import '../../ui/components/dashboard_action_row.dart';
import '../../ui/components/dashboard_metric_pill.dart';
import '../../ui/components/section_header.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../todos/ui/today_todos_screen.dart';
import '../reports/ui/weekly_report_screen.dart';
import '../settings/ui/water_reminder_settings_screen.dart';
import '../todos/data/todo_service.dart';

class HealthDashboardScreen extends StatefulWidget {
  const HealthDashboardScreen({super.key});

  @override
  State<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends State<HealthDashboardScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = true;
  double _todayCalories = 0;
  int _todayWater = 0;
  double? _weightKg;
  String? _activityLevel;
  bool _missingProfile = false;
  List<DateTime> _weekDays = [];
  Map<DateTime, double> _weeklyCalories = {};
  Map<DateTime, int> _weeklyWater = {};
  int _todayTodosTotal = 0;
  int _todayTodosDone = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
    });

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      _showSnackBar('No authenticated user found.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final weekStart = startOfDay.subtract(const Duration(days: 6));
    final weekDays = List<DateTime>.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );

    var todayCalories = _todayCalories;
    var todayWater = _todayWater;
    var weeklyCalories = <DateTime, double>{};
    var weeklyWater = <DateTime, int>{};
    double? weightKg;
    String? activityLevel;
    var missingProfile = false;
    var todayTodosTotal = 0;
    var todayTodosDone = 0;

    try {
      final mealRows = await _client
          .from('meal_logs')
          .select('servings, eaten_at, foods(food_nutrition(calories_kcal))')
          .eq('user_id', userId)
          .gte('eaten_at', weekStart.toIso8601String())
          .lt('eaten_at', endOfDay.toIso8601String());

      for (final row in mealRows) {
        final map = Map<String, dynamic>.from(row as Map);
        final servingsRaw = map['servings'];
        final servings = servingsRaw is num
            ? servingsRaw.toDouble()
            : double.tryParse(servingsRaw.toString()) ?? 1.0;
        final eatenAtRaw = map['eaten_at'];
        final eatenAt = eatenAtRaw is String
            ? DateTime.tryParse(eatenAtRaw)?.toLocal()
            : eatenAtRaw is DateTime
                ? eatenAtRaw.toLocal()
                : null;
        if (eatenAt == null) {
          continue;
        }

        double? caloriesPerServing;
        final foods = map['foods'];
        if (foods is Map) {
          final foodMap = Map<String, dynamic>.from(foods);
          final nutrition = foodMap['food_nutrition'];
          if (nutrition is List && nutrition.isNotEmpty) {
            final first = nutrition.first;
            if (first is Map) {
              final nutritionMap = Map<String, dynamic>.from(first);
              caloriesPerServing =
                  _parseNumber(nutritionMap['calories_kcal']);
            }
          } else if (nutrition is Map) {
            final nutritionMap = Map<String, dynamic>.from(nutrition);
            caloriesPerServing =
                _parseNumber(nutritionMap['calories_kcal']);
          }
        }

        final totalCalories =
            caloriesPerServing == null ? 0 : caloriesPerServing * servings;
        final dayKey = DateTime(
          eatenAt.year,
          eatenAt.month,
          eatenAt.day,
        );
        weeklyCalories[dayKey] =
            (weeklyCalories[dayKey] ?? 0) + totalCalories;
      }

      final waterRows = await _client
          .from('water_logs')
          .select('amount_ml, logged_at')
          .eq('user_id', userId)
          .gte('logged_at', weekStart.toIso8601String())
          .lt('logged_at', endOfDay.toIso8601String());

      for (final row in waterRows) {
        final map = Map<String, dynamic>.from(row as Map);
        final amountRaw = map['amount_ml'];
        final amount =
            amountRaw is num ? amountRaw.toInt() : int.tryParse('$amountRaw');
        final loggedAtRaw = map['logged_at'];
        final loggedAt = loggedAtRaw is String
            ? DateTime.tryParse(loggedAtRaw)?.toLocal()
            : loggedAtRaw is DateTime
                ? loggedAtRaw.toLocal()
                : null;
        if (loggedAt == null || amount == null) {
          continue;
        }
        final dayKey = DateTime(
          loggedAt.year,
          loggedAt.month,
          loggedAt.day,
        );
        weeklyWater[dayKey] = (weeklyWater[dayKey] ?? 0) + amount;
      }

      todayCalories = weeklyCalories[startOfDay] ?? 0;
      todayWater = weeklyWater[startOfDay] ?? 0;
    } catch (e) {
      _showSnackBar(_friendlySnack(e));
    }

    try {
      final metrics = await _client
          .from('user_metrics')
          .select('weight_kg, activity_level')
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      final weightRaw = metrics?['weight_kg'];
      weightKg = weightRaw is num
          ? weightRaw.toDouble()
          : double.tryParse('$weightRaw');
      activityLevel = metrics?['activity_level'] as String?;
      if (weightKg == null || activityLevel == null) {
        missingProfile = true;
      }
    } catch (e) {
      _showSnackBar(_friendlySnack(e));
      missingProfile = true;
    }

    try {
      final todos = await TodoService().fetchTodayTodos();
      todayTodosTotal = todos.length;
      todayTodosDone =
          todos.where((item) => item['is_done'] == true).length;
    } catch (_) {}

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _todayCalories = todayCalories;
      _todayWater = todayWater;
      _weightKg = weightKg;
      _activityLevel = activityLevel;
      _missingProfile = missingProfile;
      _weekDays = weekDays;
      _weeklyCalories = weeklyCalories;
      _weeklyWater = weeklyWater;
      _todayTodosTotal = todayTodosTotal;
      _todayTodosDone = todayTodosDone;
    });
  }

  double? _parseNumber(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value != null) {
      return double.tryParse(value.toString());
    }
    return null;
  }

  String _formatDayWithDate(DateTime day) {
    const labels = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    final label = labels[day.weekday - 1];
    final dd = day.day.toString().padLeft(2, '0');
    final mm = day.month.toString().padLeft(2, '0');
    final yyyy = day.year.toString().padLeft(4, '0');
    return '$label ($dd-$mm-$yyyy)';
  }

  String _formatTodayDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekdays = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    final month = months[date.month - 1];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday, $month ${date.day}';
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _friendlySnack(Object error) {
    if (error is AuthRetryableFetchException ||
        error is SocketException ||
        error is TimeoutException) {
      return "Couldn't load dashboard. Check internet and retry.";
    }
    return "Couldn't load dashboard.";
  }

  double _yAxisInterval(double maxY) {
    return maxY <= 1000 ? 250 : 500;
  }

  double _waterTargetMl() {
    final weight = _weightKg;
    if (weight == null || weight <= 0) {
      return 2000;
    }
    final base = weight * 35;
    final level = _activityLevel;
    final factor = level == 'high'
        ? 1.25
        : level == 'medium'
            ? 1.1
            : 1.0;
    return (base * factor).roundToDouble();
  }

  double _calorieTargetKcal() {
    final weight = _weightKg;
    if (weight == null || weight <= 0) {
      return 2000;
    }
    final base = weight * 30;
    final level = _activityLevel ?? 'medium';
    final factor = level == 'high'
        ? 1.2
        : level == 'low'
            ? 1.0
            : 1.1;
    return base * factor;
  }

  String _complianceStatus(int score) {
    if (score >= 80) {
      return 'Good';
    }
    if (score >= 50) {
      return 'Medium';
    }
    return 'Poor';
  }

  Widget _buildWeeklyCaloriesChart() {
    double maxY = 0;
    for (var i = 0; i < _weekDays.length; i++) {
      final day = _weekDays[i];
      final value = _weeklyCalories[day] ?? 0;
      if (value > maxY) {
        maxY = value;
      }
    }

    if (maxY <= 0) {
      maxY = 1;
    }

    final interval = _yAxisInterval(maxY);
    final roundedMaxY = (maxY / interval).ceil() * interval;

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < _weekDays.length; i++) {
      final day = _weekDays[i];
      final value = _weeklyCalories[day] ?? 0;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              width: 16,
              color: AppColors.coral,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: roundedMaxY,
                color: AppColors.border.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
      );
    }

    final allZero = _weekDays.every(
      (day) => (_weeklyCalories[day] ?? 0) == 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 176,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 12, top: 6),
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: roundedMaxY,
                  barGroups: groups,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppColors.border.withValues(alpha: 0.25),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          final isTick =
                              (value % interval).abs() < 0.001;
                          if (value == 0 || isTick) {
                            return Text(
                              value.toInt().toString(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= _weekDays.length) {
                            return const SizedBox.shrink();
                          }
                          const labels = [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ];
                          final day = _weekDays[index];
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 6,
                            child: Text(
                              labels[day.weekday - 1],
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (allZero)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 8),
            child: Text(
              'No logs this week yet',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _buildWeeklyWaterChart() {
    final spots = <FlSpot>[];
    double maxY = 0;
    for (var i = 0; i < _weekDays.length; i++) {
      final day = _weekDays[i];
      final value = (_weeklyWater[day] ?? 0).toDouble();
      if (value > maxY) {
        maxY = value;
      }
      spots.add(FlSpot(i.toDouble(), value));
    }

    if (maxY <= 0) {
      maxY = 1;
    }

    final interval = _yAxisInterval(maxY);
    final roundedMaxY = (maxY / interval).ceil() * interval;

    final allZero = _weekDays.every(
      (day) => (_weeklyWater[day] ?? 0) == 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 176,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 12, top: 6),
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (_weekDays.length - 1).toDouble(),
                  minY: 0,
                  maxY: roundedMaxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppColors.border.withValues(alpha: 0.25),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  clipData: FlClipData.all(),
                  lineTouchData: LineTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          final isTick =
                              (value % interval).abs() < 0.001;
                          if (value == 0 || isTick) {
                            return Text(
                              value.toInt().toString(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= _weekDays.length) {
                            return const SizedBox.shrink();
                          }
                          const labels = [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ];
                          final day = _weekDays[index];
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 6,
                            child: Text(
                              labels[day.weekday - 1],
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      barWidth: 3.5,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.teal.withValues(alpha: 0.25),
                            AppColors.teal.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                      color: AppColors.teal,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (allZero)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 8),
            child: Text(
              'No logs this week yet',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedCalories = _todayCalories > 0
        ? _todayCalories.toStringAsFixed(0)
        : '--';
    final formattedWater = _todayWater > 0 ? _todayWater.toString() : '--';
    final todosPercent = _todayTodosTotal == 0
        ? 0
        : ((_todayTodosDone / _todayTodosTotal) * 100).round();
    final todosValue =
        _todayTodosTotal == 0 ? '--' : '$todosPercent';
    final todayLabel = _formatTodayDate(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Health Dashboard')),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF0FDFA),
                AppColors.background,
              ],
            ),
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              todayLabel,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Today overview',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final columns =
                                    constraints.maxWidth >= 640 ? 3 : 2;
                                final textScale = MediaQuery
                                    .textScalerOf(context)
                                    .scale(1.0);
                                final pillHeight =
                                    100 + (textScale - 1.0) * 36;
                                final clampedPillHeight = pillHeight < 100
                                    ? 100
                                    : pillHeight > 180
                                        ? 180
                                        : pillHeight;
                                final totalSpacing =
                                    AppSpacing.md * (columns - 1);
                                final itemWidth = (constraints.maxWidth -
                                        totalSpacing) /
                                    columns;
                                final childRatio =
                                    itemWidth / clampedPillHeight;
                                final items = [
                                  DashboardMetricPill(
                                    label: 'Today Calories',
                                    value: formattedCalories,
                                    unit: 'kcal',
                                    color: AppColors.coral,
                                  ),
                                  DashboardMetricPill(
                                    label: 'Today Water',
                                    value: formattedWater,
                                    unit: 'ml',
                                    color: AppColors.teal,
                                  ),
                                  DashboardMetricPill(
                                    label: 'Today Tasks',
                                    value: todosValue,
                                    unit: '%',
                                    color: AppColors.purple,
                                  ),
                                ];
                                return GridView.count(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: AppSpacing.md,
                                  mainAxisSpacing: AppSpacing.md,
                                  childAspectRatio: childRatio,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: items,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const SectionHeader(title: 'Quick Actions'),
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            DashboardActionRow(
                              title: 'Today Tasks',
                              subtitle: 'View and check off tasks',
                              icon: Icons.check_circle_outline,
                              iconColor: AppColors.teal,
                              iconBackground:
                                  AppColors.teal.withValues(alpha: 0.12),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const TodayTodosScreen(),
                                  ),
                                );
                                if (mounted) {
                                  await _loadDashboard();
                                }
                              },
                              showDivider: true,
                            ),
                            DashboardActionRow(
                              title: 'Weekly Report',
                              subtitle: 'See your weekly summary',
                              icon: Icons.bar_chart_outlined,
                              iconColor: AppColors.coral,
                              iconBackground:
                                  AppColors.coral.withValues(alpha: 0.12),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const WeeklyReportScreen(),
                                  ),
                                );
                              },
                              showDivider: true,
                            ),
                            DashboardActionRow(
                              title: 'Water Reminders',
                              subtitle: 'Manage reminder schedule',
                              icon: Icons.notifications_none,
                              iconColor: AppColors.purple,
                              iconBackground:
                                  AppColors.purple.withValues(alpha: 0.12),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const WaterReminderSettingsScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const SectionHeader(title: 'Today Compliance'),
                      const SizedBox(height: AppSpacing.md),
                      Builder(
                        builder: (context) {
                          final waterTarget = _waterTargetMl();
                          final calorieTarget = _calorieTargetKcal();
                          final waterScore = waterTarget <= 0
                              ? 0.0
                              : (_todayWater / waterTarget) * 100;
                          final calorieScore = calorieTarget <= 0
                              ? 0.0
                              : (_todayCalories / calorieTarget) * 100;
                          final compliance = ((waterScore.clamp(0, 100) +
                                      calorieScore.clamp(0, 100)) /
                                  2)
                              .round();
                          final status = _complianceStatus(compliance);
                          final todosPercent = _todayTodosTotal == 0
                              ? 0
                              : ((_todayTodosDone / _todayTodosTotal) * 100)
                                  .round();

                          final statusColor = compliance >= 80
                              ? AppColors.teal
                              : compliance >= 50
                                  ? AppColors.coral
                                  : AppColors.pink;

                          return AppCard(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Today Compliance: $compliance%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                LinearProgressIndicator(
                                  value: compliance / 100,
                                  color: statusColor,
                                  backgroundColor:
                                      statusColor.withValues(alpha: 0.15),
                                  minHeight: 8,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.local_fire_department_outlined,
                                          size: 16,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Text(
                                          'Calories',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${_todayCalories.toStringAsFixed(0)} / ${calorieTarget.toStringAsFixed(0)} kcal',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.water_drop_outlined,
                                          size: 16,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Text(
                                          'Water',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '$_todayWater / ${waterTarget.toStringAsFixed(0)} ml',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline,
                                          size: 16,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Text(
                                          'Tasks',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '$todosPercent%',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: statusColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                if (_missingProfile) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'Set profile for accurate targets',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const SectionHeader(title: 'Weekly Trends'),
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Weekly Calories',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  'kcal',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _buildWeeklyCaloriesChart(),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppCard(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Weekly Water',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  'ml',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _buildWeeklyWaterChart(),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const SectionHeader(title: 'Weekly Breakdown'),
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: List.generate(_weekDays.length, (index) {
                            final day = _weekDays[index];
                            final label = _formatDayWithDate(day);
                            final calories =
                                _weeklyCalories[day]?.toStringAsFixed(0) ?? '0';
                            final water = _weeklyWater[day] ?? 0;
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.sm,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ),
                                      Text(
                                        '$calories kcal',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Text(
                                        '$water ml',
                                        textAlign: TextAlign.right,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                if (index < _weekDays.length - 1)
                                  const Divider(height: 1),
                              ],
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
