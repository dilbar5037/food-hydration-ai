import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food_models.dart';

class FoodsRepo {
  FoodsRepo(this._client);

  final SupabaseClient _client;

  Future<List<Food>> fetchFoods() async {
    final response = await _client
        .from('foods')
        .select(
          'id,name,is_active,food_nutrition(basis,serving_size_g,calories_kcal,carbs_g,protein_g,fat_g)',
        )
        .eq('is_active', true)
        .order('name');

    final data = response as List<dynamic>? ?? [];
    return data
        .map(
          (item) => Food.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }
}
