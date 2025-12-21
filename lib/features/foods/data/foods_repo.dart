import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food_models.dart';

class FoodsRepo {
  FoodsRepo(this._client);

  final SupabaseClient _client;

  Future<List<Food>> fetchFoods() async {
    final response = await _client
        .from('foods')
        .select(
          'id,food_key,display_name,food_nutrition(serving_size_g,calories_kcal,carbs_g,protein_g,fat_g)',
        )
        .order('display_name');

    final data = response as List<dynamic>? ?? [];
    return data
        .map(
          (item) => Food.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }
}
