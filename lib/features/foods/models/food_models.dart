class FoodNutrition {
  const FoodNutrition({
    this.servingSizeG,
    this.caloriesKcal,
    this.carbsG,
    this.proteinG,
    this.fatG,
  });

  final double? servingSizeG;
  final double? caloriesKcal;
  final double? carbsG;
  final double? proteinG;
  final double? fatG;

  factory FoodNutrition.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value.toString());
      return parsed;
    }

    return FoodNutrition(
      servingSizeG: toDouble(json['serving_size_g']),
      caloriesKcal: toDouble(json['calories_kcal']),
      carbsG: toDouble(json['carbs_g']),
      proteinG: toDouble(json['protein_g']),
      fatG: toDouble(json['fat_g']),
    );
  }
}

class Food {
  const Food({
    required this.id,
    required this.foodKey,
    required this.displayName,
    this.nutrition,
  });

  final String id;
  final String foodKey;
  final String displayName;
  final FoodNutrition? nutrition;

  factory Food.fromJson(Map<String, dynamic> json) {
    FoodNutrition? nutrition;
    final nutritionData = json['food_nutrition'];

    if (nutritionData is List && nutritionData.isNotEmpty) {
      final first = nutritionData.first;
      if (first is Map<String, dynamic>) {
        nutrition = FoodNutrition.fromJson(first);
      }
    } else if (nutritionData is Map<String, dynamic>) {
      nutrition = FoodNutrition.fromJson(nutritionData);
    }

    return Food(
      id: json['id'] as String,
      foodKey: json['food_key'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      nutrition: nutrition,
    );
  }
}
