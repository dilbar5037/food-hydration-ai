import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/date_time_formatter.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_radius.dart';
import '../../ui/theme/app_spacing.dart';

class MealHistoryItem {
  MealHistoryItem({
    required this.id,
    required this.foodName,
    required this.servings,
    required this.eatenAt,
    this.caloriesPerServing,
    this.carbsPerServing,
    this.proteinPerServing,
    this.fatPerServing,
    this.confidence,
  });

  final String id;
  final String foodName;
  final double servings;
  final DateTime eatenAt;
  final double? caloriesPerServing;
  final double? carbsPerServing;
  final double? proteinPerServing;
  final double? fatPerServing;
  final double? confidence;

  double? get totalCalories => caloriesPerServing == null
      ? null
      : caloriesPerServing! * servings;
  double? get totalCarbs =>
      carbsPerServing == null ? null : carbsPerServing! * servings;
  double? get totalProtein =>
      proteinPerServing == null ? null : proteinPerServing! * servings;
  double? get totalFat => fatPerServing == null ? null : fatPerServing! * servings;
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
          'id, servings, eaten_at, confidence, foods(display_name, food_nutrition(calories_kcal, carbs_g, protein_g, fat_g))',
        )
        .eq('user_id', userId)
        .order('eaten_at', ascending: false);

    final rows = response as List<dynamic>? ?? [];

    return rows.map((raw) {
      final map = Map<String, dynamic>.from(raw as Map);
      final foods = map['foods'];
      String foodName = 'Unknown food';
      double? caloriesPerServing;
      double? carbsPerServing;
      double? proteinPerServing;
      double? fatPerServing;
      double? parseNumber(dynamic value) {
        if (value is num) {
          return value.toDouble();
        }
        if (value != null) {
          return double.tryParse(value.toString());
        }
        return null;
      }

      if (foods is Map) {
        foodName = foods['display_name'] as String? ?? foodName;
        final nutrition = foods['food_nutrition'];
        if (nutrition is List && nutrition.isNotEmpty) {
          final first = nutrition.first;
          if (first is Map) {
            caloriesPerServing = parseNumber(first['calories_kcal']);
            carbsPerServing = parseNumber(first['carbs_g']);
            proteinPerServing = parseNumber(first['protein_g']);
            fatPerServing = parseNumber(first['fat_g']);
          }
        } else if (nutrition is Map) {
          caloriesPerServing = parseNumber(nutrition['calories_kcal']);
          carbsPerServing = parseNumber(nutrition['carbs_g']);
          proteinPerServing = parseNumber(nutrition['protein_g']);
          fatPerServing = parseNumber(nutrition['fat_g']);
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
        carbsPerServing: carbsPerServing,
        proteinPerServing: proteinPerServing,
        fatPerServing: fatPerServing,
        confidence: confidenceRaw is num
            ? confidenceRaw.toDouble()
            : confidenceRaw == null
                ? null
                : double.tryParse(confidenceRaw.toString()),
      );
    }).toList();
  }

  String _formatNumber(double? value) {
    if (value == null) return '--';
    final isWhole = value % 1 == 0;
    return isWhole ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Meal History'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: FutureBuilder<List<MealHistoryItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Failed to load meal history: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red[700],
                      ),
                ),
              ),
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No meals logged yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildMealCard(context, item);
            },
          );
        },
      ),
    );
  }

  Widget _buildMealCard(BuildContext context, MealHistoryItem item) {
    final totalCalories = item.totalCalories;
    final totalCarbs = item.totalCarbs;
    final totalProtein = item.totalProtein;
    final totalFat = item.totalFat;
    final confidence = item.confidence;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Meal name + Confidence badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.foodName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Servings: ${_formatNumber(item.servings)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (confidence != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.teal.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '${(confidence * 100).clamp(0, 100).toStringAsFixed(1)}%',
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
              const SizedBox(height: AppSpacing.md),

              // Calories highlight
              if (totalCalories != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.coral.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_outlined,
                        size: 18,
                        color: AppColors.coral,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${_formatNumber(totalCalories)} kcal',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.coral,
                            ),
                      ),
                    ],
                  ),
                ),
              if (totalCalories == null)
                Text(
                  '-- kcal',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                ),
              const SizedBox(height: AppSpacing.md),

              // Nutrients row
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNutrientChip(
                      context,
                      label: 'Carbs',
                      value: '${_formatNumber(totalCarbs)} g',
                      color: AppColors.purple,
                    ),
                    _buildNutrientChip(
                      context,
                      label: 'Protein',
                      value: '${_formatNumber(totalProtein)} g',
                      color: AppColors.teal,
                    ),
                    _buildNutrientChip(
                      context,
                      label: 'Fat',
                      value: '${_formatNumber(totalFat)} g',
                      color: AppColors.coral,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Eaten at
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    DateTimeFormatter.formatDateTime(item.eatenAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutrientChip(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
