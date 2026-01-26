import 'package:supabase_flutter/supabase_flutter.dart';

class WeeklyReport {
  const WeeklyReport({
    required this.startDate,
    required this.endDate,
    required this.totalCalories,
    required this.totalWaterMl,
    required this.avgCaloriesPerDay,
    required this.avgWaterPerDay,
    required this.avgCompliance,
    required this.topFoods,
  });

  final DateTime startDate;
  final DateTime endDate;
  final double totalCalories;
  final int totalWaterMl;
  final double avgCaloriesPerDay;
  final double avgWaterPerDay;
  final double avgCompliance;
  final List<TopFood> topFoods;

  factory WeeklyReport.empty(DateTime startDate, DateTime endDate) {
    return WeeklyReport(
      startDate: startDate,
      endDate: endDate,
      totalCalories: 0,
      totalWaterMl: 0,
      avgCaloriesPerDay: 0,
      avgWaterPerDay: 0,
      avgCompliance: 0,
      topFoods: const [],
    );
  }
}

class TopFood {
  const TopFood({required this.name, required this.count});

  final String name;
  final int count;
}

class ReportService {
  ReportService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<WeeklyReport> fetchWeeklyReport() async {
    final range = _weeklyRangeUtc();
    final startDay = range.start;
    final endDay = range.end;
    final endExclusive = endDay.add(const Duration(days: 1));
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return WeeklyReport.empty(startDay, endDay);
    }

    final goals = await _fetchGoals(userId);
    final caloriesByDay = <DateTime, double>{};
    final waterByDay = <DateTime, int>{};
    final todosByDay = <DateTime, _TodoCounts>{};
    final foodCounts = <String, int>{};

    double totalCalories = 0;
    int totalWater = 0;

    try {
      final response = await _client
          .from('meal_logs')
          .select(
            'servings, eaten_at, foods(display_name, food_nutrition(calories_kcal))',
          )
          .eq('user_id', userId)
          .gte('eaten_at', startDay.toIso8601String())
          .lt('eaten_at', endExclusive.toIso8601String());

      final rows = response as List<dynamic>? ?? [];
      for (final raw in rows) {
        final map = Map<String, dynamic>.from(raw);
        final eatenAt = _parseDateTime(map['eaten_at']);
        if (eatenAt == null) {
          continue;
        }
        final dayKey = DateTime.utc(
          eatenAt.year,
          eatenAt.month,
          eatenAt.day,
        );
        final servings = _parseNumber(map['servings']) ?? 1.0;

        double? caloriesPerServing;
        String foodName = 'Unknown food';
        final foods = map['foods'];
        if (foods is Map) {
          foodName = foods['display_name'] as String? ?? foodName;
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

        final mealCalories =
            caloriesPerServing == null ? 0 : caloriesPerServing * servings;
        totalCalories += mealCalories;
        caloriesByDay[dayKey] = (caloriesByDay[dayKey] ?? 0) + mealCalories;
        foodCounts[foodName] = (foodCounts[foodName] ?? 0) + 1;
      }
    } catch (_) {}

    try {
      final response = await _client
          .from('water_logs')
          .select('amount_ml, logged_at')
          .eq('user_id', userId)
          .gte('logged_at', startDay.toIso8601String())
          .lt('logged_at', endExclusive.toIso8601String());

      final rows = response as List<dynamic>? ?? [];
      for (final raw in rows) {
        final map = Map<String, dynamic>.from(raw);
        final loggedAt = _parseDateTime(map['logged_at']);
        final amountRaw = map['amount_ml'];
        final amount = amountRaw is num
            ? amountRaw.toInt()
            : int.tryParse('$amountRaw');
        if (loggedAt == null || amount == null) {
          continue;
        }
        final dayKey = DateTime.utc(
          loggedAt.year,
          loggedAt.month,
          loggedAt.day,
        );
        totalWater += amount;
        waterByDay[dayKey] = (waterByDay[dayKey] ?? 0) + amount;
      }
    } catch (_) {}

    try {
      final startDateStr = _formatDate(startDay);
      final endDateStr = _formatDate(endExclusive);
      final response = await _client
          .from('user_todos')
          .select('todo_date, is_done')
          .eq('user_id', userId)
          .gte('todo_date', startDateStr)
          .lt('todo_date', endDateStr);

      final rows = response as List<dynamic>? ?? [];
      for (final raw in rows) {
        final map = Map<String, dynamic>.from(raw);
        final todoDate = _parseDate(map['todo_date']);
        if (todoDate == null) {
          continue;
        }
        final dayKey = DateTime.utc(
          todoDate.year,
          todoDate.month,
          todoDate.day,
        );
        final isDone = map['is_done'] == true;
        final counts = todosByDay.putIfAbsent(dayKey, () => _TodoCounts());
        counts.total += 1;
        if (isDone) {
          counts.done += 1;
        }
      }
    } catch (_) {}

    double complianceSum = 0;
    for (var i = 0; i < 7; i++) {
      final day = startDay.add(Duration(days: i));
      final dayKey = DateTime.utc(day.year, day.month, day.day);
      final dayCalories = caloriesByDay[dayKey] ?? 0;
      final dayWater = waterByDay[dayKey] ?? 0;
      final todoCounts = todosByDay[dayKey];

      final caloriesRatio = goals.caloriesGoal <= 0
          ? 0
          : (dayCalories / goals.caloriesGoal).clamp(0, 1);
      final waterRatio = goals.waterGoal <= 0
          ? 0
          : (dayWater / goals.waterGoal).clamp(0, 1);
      final todoRatio = todoCounts == null || todoCounts.total == 0
          ? 0
          : todoCounts.done / todoCounts.total;

      complianceSum += (caloriesRatio + waterRatio + todoRatio) / 3;
    }

    final avgCaloriesPerDay = totalCalories / 7;
    final avgWaterPerDay = totalWater / 7;
    final avgCompliance = (complianceSum / 7) * 100;

    final foods = foodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topFoods = foods
        .take(5)
        .map((entry) => TopFood(name: entry.key, count: entry.value))
        .toList();

    return WeeklyReport(
      startDate: startDay,
      endDate: endDay,
      totalCalories: totalCalories,
      totalWaterMl: totalWater,
      avgCaloriesPerDay: avgCaloriesPerDay,
      avgWaterPerDay: avgWaterPerDay,
      avgCompliance: avgCompliance,
      topFoods: topFoods,
    );
  }

  Future<_Goals> _fetchGoals(String userId) async {
    double? caloriesGoal;
    double? waterGoal;

    try {
      final response = await _client
          .from('settings')
          .select('value_json')
          .eq('key', 'app_defaults')
          .maybeSingle();
      final data = response is Map<String, dynamic> ? response : null;
      final valueJson = data?['value_json'];
      if (valueJson is Map<String, dynamic>) {
        caloriesGoal = _parseNumber(valueJson['default_daily_calories_kcal']);
        waterGoal = _parseNumber(valueJson['default_daily_water_ml']);
      }
    } catch (_) {}

    if ((caloriesGoal ?? 0) > 0 && (waterGoal ?? 0) > 0) {
      return _Goals(
        caloriesGoal: caloriesGoal!,
        waterGoal: waterGoal!,
      );
    }

    try {
      final response = await _client
          .from('user_metrics')
          .select('weight_kg, activity_level')
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      final weightRaw = response?['weight_kg'];
      final weightKg = _parseNumber(weightRaw);
      final activityLevel = response?['activity_level'] as String?;
      if (weightKg != null && weightKg > 0) {
        final baseWater = weightKg * 35;
        final waterFactor = activityLevel == 'high'
            ? 1.25
            : activityLevel == 'medium'
                ? 1.1
                : 1.0;
        final baseCalories = weightKg * 30;
        final calorieFactor = activityLevel == 'high'
            ? 1.2
            : activityLevel == 'low'
                ? 1.0
                : 1.1;

        caloriesGoal = baseCalories * calorieFactor;
        waterGoal = (baseWater * waterFactor).roundToDouble();
      }
    } catch (_) {}

    return _Goals(
      caloriesGoal: caloriesGoal ?? 2000,
      waterGoal: waterGoal ?? 2000,
    );
  }

  _WeeklyRange _weeklyRangeUtc() {
    final now = DateTime.now().toUtc();
    final endDay = DateTime.utc(now.year, now.month, now.day);
    final startDay = endDay.subtract(const Duration(days: 6));
    return _WeeklyRange(start: startDay, end: endDay);
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc();
    }
    return null;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
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

  String _formatDate(DateTime date) {
    return date.toIso8601String().split('T').first;
  }
}

class _WeeklyRange {
  const _WeeklyRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class _Goals {
  const _Goals({required this.caloriesGoal, required this.waterGoal});

  final double caloriesGoal;
  final double waterGoal;
}

class _TodoCounts {
  int total = 0;
  int done = 0;
}
