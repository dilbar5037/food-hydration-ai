import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          final nutrition = foods['food_nutrition'];
          if (nutrition is List && nutrition.isNotEmpty) {
            final first = nutrition.first;
            if (first is Map) {
              caloriesPerServing = _parseNumber(first['calories_kcal']);
            }
          } else if (nutrition is Map) {
            caloriesPerServing = _parseNumber(nutrition['calories_kcal']);
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
      _showSnackBar(e.toString());
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
      _showSnackBar(e.toString());
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

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  double _niceInterval(double maxY) {
    if (maxY <= 200) {
      return 50;
    }
    if (maxY <= 500) {
      return 100;
    }
    if (maxY <= 1000) {
      return 200;
    }
    if (maxY <= 2500) {
      return 500;
    }
    return 1000;
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
    if (_weekDays.isEmpty || _weeklyCalories.isEmpty) {
      return const Text('No data available');
    }

    final groups = <BarChartGroupData>[];
    double maxY = 0;
    for (var i = 0; i < _weekDays.length; i++) {
      final day = _weekDays[i];
      final value = _weeklyCalories[day] ?? 0;
      if (value > maxY) {
        maxY = value;
      }
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              width: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      );
    }

    if (maxY <= 0) {
      maxY = 1;
    }

    final interval = _yAxisInterval(maxY);
    final roundedMaxY = (maxY / interval).ceil() * interval;

    return SizedBox(
      height: 160,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Padding(
          padding: const EdgeInsets.only(left: 8, right: 18),
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: roundedMaxY,
              barGroups: groups,
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: interval,
                    getTitlesWidget: (value, meta) {
                      final isTick =
                          (value % interval).abs() < 0.001;
                      if (value == 0 || isTick) {
                        return Text(value.toInt().toString());
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
                          style: const TextStyle(fontSize: 10),
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
    );
  }

  Widget _buildWeeklyWaterChart() {
    if (_weekDays.isEmpty || _weeklyWater.isEmpty) {
      return const Text('No data available');
    }

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

    return SizedBox(
      height: 160,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Padding(
          padding: const EdgeInsets.only(left: 8, right: 18),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (_weekDays.length - 1).toDouble(),
              minY: 0,
              maxY: roundedMaxY,
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: false),
              clipData: FlClipData.all(),
              lineTouchData: LineTouchData(enabled: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: interval,
                    getTitlesWidget: (value, meta) {
                      final isTick =
                          (value % interval).abs() < 0.001;
                      if (value == 0 || isTick) {
                        return Text(value.toInt().toString());
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
                          style: const TextStyle(fontSize: 10),
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
                  barWidth: 3,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Dashboard')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _isLoading
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TodayTodosScreen(),
                            ),
                          );
                        },
                        child: const Text('Today Tasks'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const WeeklyReportScreen(),
                            ),
                          );
                        },
                        child: const Text('Weekly Report'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const WaterReminderSettingsScreen(),
                            ),
                          );
                        },
                        child: const Text('Water Reminders'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Today Calories: ${_todayCalories.toStringAsFixed(0)} kcal',
                      ),
                      const SizedBox(height: 8),
                      Text('Today Water: $_todayWater ml'),
                      const SizedBox(height: 16),
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

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Today Compliance: $compliance%',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: compliance / 100,
                                color: Theme.of(context).colorScheme.primary,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.2),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Calories: ${_todayCalories.toStringAsFixed(0)} / ${calorieTarget.toStringAsFixed(0)} kcal',
                              ),
                              Text(
                                'Water: $_todayWater / ${waterTarget.toStringAsFixed(0)} ml',
                              ),
                              Text('Today Tasks: $todosPercent%'),
                              const SizedBox(height: 6),
                              Text(
                                status,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                              ),
                              if (_missingProfile) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Set profile for accurate targets',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall,
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Weekly Calories',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _buildWeeklyCaloriesChart(),
                      const SizedBox(height: 12),
                      Column(
                        children: _weekDays.map((day) {
                          final label = _formatDayWithDate(day);
                          final total =
                              _weeklyCalories[day]?.toStringAsFixed(0) ?? '0';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(label),
                                Text('$total kcal'),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Weekly Water',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _buildWeeklyWaterChart(),
                      const SizedBox(height: 12),
                      Column(
                        children: _weekDays.map((day) {
                          final label = _formatDayWithDate(day);
                          final total = _weeklyWater[day] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(label),
                                Text('$total ml'),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
