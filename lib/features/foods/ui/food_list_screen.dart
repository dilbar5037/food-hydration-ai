import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/foods_repo.dart';
import '../models/food_models.dart';
import 'food_detail_screen.dart';

class FoodListScreen extends StatefulWidget {
  const FoodListScreen({super.key});

  @override
  State<FoodListScreen> createState() => _FoodListScreenState();
}

class _FoodListScreenState extends State<FoodListScreen> {
  late final FoodsRepo _repo = FoodsRepo(Supabase.instance.client);
  late final Future<List<Food>> _foodsFuture = _repo.fetchFoods();

  String _formatNumber(double? value) {
    if (value == null) return '--';
    final isWhole = value % 1 == 0;
    return isWhole ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food List')),
      body: FutureBuilder<List<Food>>(
        future: _foodsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load foods: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final foods = snapshot.data ?? [];
          if (foods.isEmpty) {
            return const Center(child: Text('No foods found.'));
          }

          return ListView.separated(
            itemCount: foods.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final food = foods[index];
              final calories = food.nutrition?.caloriesKcal;
              return ListTile(
                title: Text(food.name),
                subtitle: calories != null
                    ? Text('Calories: ${_formatNumber(calories)} kcal')
                    : null,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FoodDetailScreen(food: food),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
