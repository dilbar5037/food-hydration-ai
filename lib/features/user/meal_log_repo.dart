import 'package:supabase_flutter/supabase_flutter.dart';

import '../foods/models/food_models.dart';

class MealLogRepo {
  MealLogRepo(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> findFoodByLabel(String label) async {
    final result = await _client
        .from('foods')
        .select('id,name')
        .eq('is_active', true)
        .ilike('name', label)
        .maybeSingle();
    return result == null ? null : Map<String, dynamic>.from(result);
  }

  Future<FoodNutrition?> fetchNutrition(String foodId) async {
    final result = await _client
        .from('food_nutrition')
        .select(
          'basis,serving_size_g,calories_kcal,carbs_g,protein_g,fat_g',
        )
        .eq('food_id', foodId)
        .maybeSingle();
    if (result == null) return null;
    return FoodNutrition.fromJson(Map<String, dynamic>.from(result));
  }

  Future<void> insertMealLog({
    required String userId,
    String? foodId,
    required double servings,
    required double confidence,
    required String imagePath,
    DateTime? eatenAt,
  }) async {
    final payload = <String, dynamic>{
      'user_id': userId,
      'food_id': foodId,
      'servings': servings,
      'eaten_at': (eatenAt ?? DateTime.now()).toIso8601String(),
      'confidence': confidence,
      'image_path': imagePath,
    };

    await _client.from('meal_logs').insert(payload);
  }
}
