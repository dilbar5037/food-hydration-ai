import 'package:flutter/material.dart';

import '../models/food_models.dart';

class FoodDetailScreen extends StatelessWidget {
  const FoodDetailScreen({super.key, required this.food});

  final Food food;

  String _formatNumber(double? value, {String unit = ''}) {
    if (value == null) return '--';
    final isWhole = value % 1 == 0;
    final text = isWhole ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return unit.isEmpty ? text : '$text $unit';
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, textAlign: TextAlign.right),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = food.nutrition;

    return Scaffold(
      appBar: AppBar(title: Text(food.displayName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: nutrition == null
            ? const Center(child: Text('Nutrition not available'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nutrition Details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildRow(
                    'Serving Size',
                    _formatNumber(nutrition.servingSizeG, unit: 'g'),
                  ),
                  _buildRow(
                    'Calories',
                    _formatNumber(nutrition.caloriesKcal, unit: 'kcal'),
                  ),
                  _buildRow(
                    'Carbs',
                    _formatNumber(nutrition.carbsG, unit: 'g'),
                  ),
                  _buildRow(
                    'Protein',
                    _formatNumber(nutrition.proteinG, unit: 'g'),
                  ),
                  _buildRow(
                    'Fat',
                    _formatNumber(nutrition.fatG, unit: 'g'),
                  ),
                ],
              ),
      ),
    );
  }
}
