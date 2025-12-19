import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MealHistoryItem {
  MealHistoryItem({
    required this.id,
    required this.foodName,
    required this.servings,
    required this.eatenAt,
    this.caloriesPerServing,
    this.confidence,
  });

  final String id;
  final String foodName;
  final double servings;
  final DateTime eatenAt;
  final double? caloriesPerServing;
  final double? confidence;

  double? get totalCalories => caloriesPerServing == null
      ? null
      : caloriesPerServing! * servings;
}

class MealHistoryScreen extends StatefulWidget {
  const MealHistoryScreen({super.key});

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen> {
  late final Future<List<MealHistoryItem>> _future = _loadHistory();

  Future<List<MealHistoryItem>> _loadHistory() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return [];
    }

    final response = await client
        .from('meal_logs')
        .select(
          'id, servings, eaten_at, confidence, foods(name, food_nutrition(calories_kcal))',
        )
        .eq('user_id', userId)
        .order('eaten_at', ascending: false);

    final rows = response as List<dynamic>? ?? [];

    return rows.map((raw) {
      final map = Map<String, dynamic>.from(raw as Map);
      final foods = map['foods'];
      String foodName = 'Unknown food';
      double? caloriesPerServing;

      if (foods is Map) {
        foodName = foods['name'] as String? ?? foodName;
        final nutrition = foods['food_nutrition'];
        if (nutrition is List && nutrition.isNotEmpty) {
          final first = nutrition.first;
          if (first is Map) {
            final kcal = first['calories_kcal'];
            if (kcal is num) {
              caloriesPerServing = kcal.toDouble();
            } else if (kcal != null) {
              caloriesPerServing = double.tryParse(kcal.toString());
            }
          }
        } else if (nutrition is Map) {
          final kcal = nutrition['calories_kcal'];
          if (kcal is num) {
            caloriesPerServing = kcal.toDouble();
          } else if (kcal != null) {
            caloriesPerServing = double.tryParse(kcal.toString());
          }
        }
      }

      final servingsRaw = map['servings'];
      final eatenAtRaw = map['eaten_at'];
      final confidenceRaw = map['confidence'];

      final servings = servingsRaw is num
          ? servingsRaw.toDouble()
          : double.tryParse(servingsRaw.toString()) ?? 1.0;
      final eatenAt = eatenAtRaw is String
          ? DateTime.tryParse(eatenAtRaw)?.toLocal()
          : eatenAtRaw is DateTime
              ? eatenAtRaw.toLocal()
              : null;

      return MealHistoryItem(
        id: map['id'].toString(),
        foodName: foodName,
        servings: servings,
        eatenAt: eatenAt ?? DateTime.now(),
        caloriesPerServing: caloriesPerServing,
        confidence: confidenceRaw is num
            ? confidenceRaw.toDouble()
            : confidenceRaw == null
                ? null
                : double.tryParse(confidenceRaw.toString()),
      );
    }).toList();
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final date =
        '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  String _formatNumber(double? value) {
    if (value == null) return '--';
    final isWhole = value % 1 == 0;
    return isWhole ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meal History')),
      body: FutureBuilder<List<MealHistoryItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load meal history: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('No meals logged yet.'),
            );
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final totalCalories = item.totalCalories;
              final confidence = item.confidence;
              return ListTile(
                title: Text(item.foodName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Servings: ${_formatNumber(item.servings)}'),
                    if (totalCalories != null)
                      Text('Calories: ${_formatNumber(totalCalories)} kcal'),
                    Text('Eaten at: ${_formatDateTime(item.eatenAt)}'),
                    if (confidence != null)
                      Text(
                        'Confidence: ${(confidence * 100).clamp(0, 100).toStringAsFixed(1)}%',
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
