class FoodNutrition {
  const FoodNutrition({
    this.basis,
    this.servingSizeG,
    this.caloriesKcal,
    this.carbsG,
    this.proteinG,
    this.fatG,
  });

  final String? basis;
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
      basis: json['basis'] as String?,
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
    required this.name,
    required this.isActive,
    this.nutrition,
  });

  final String id;
  final String name;
  final bool isActive;
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
      name: json['name'] as String,
      isActive: json['is_active'] as bool? ?? false,
      nutrition: nutrition,
    );
  }
}
