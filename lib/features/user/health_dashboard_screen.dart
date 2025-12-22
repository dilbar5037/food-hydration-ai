import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  List<DateTime> _weekDays = [];
  Map<DateTime, double> _weeklyCalories = {};
  Map<DateTime, int> _weeklyWater = {};

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

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _todayCalories = todayCalories;
      _todayWater = todayWater;
      _weekDays = weekDays;
      _weeklyCalories = weeklyCalories;
      _weeklyWater = weeklyWater;
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
                      Text(
                        'Today Calories: ${_todayCalories.toStringAsFixed(0)} kcal',
                      ),
                      const SizedBox(height: 8),
                      Text('Today Water: $_todayWater ml'),
                      const SizedBox(height: 24),
                      Text(
                        'Weekly Calories',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
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
