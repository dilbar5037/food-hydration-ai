import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../foods/models/food_models.dart';

class AdminFoodsScreen extends StatefulWidget {
  const AdminFoodsScreen({super.key});

  @override
  State<AdminFoodsScreen> createState() => _AdminFoodsScreenState();
}

class _AdminFoodsScreenState extends State<AdminFoodsScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final List<Food> _foods = [];
  bool _loading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  String _formatNumber(double? value) {
    if (value == null) return '--';
    final isWhole = value % 1 == 0;
    return isWhole ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  List<Food> get _filteredFoods {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return List<Food>.from(_foods);
    return _foods
        .where(
          (food) =>
              food.displayName.toLowerCase().contains(query) ||
              food.foodKey.toLowerCase().contains(query),
        )
        .toList();
  }

  Future<void> _loadFoods() async {
    setState(() => _loading = true);
    try {
      final response = await _client
          .from('foods')
          .select('id,food_key,display_name')
          .order('display_name');

      final data = response as List<dynamic>? ?? [];
      final foods = data
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => Food(
              id: item['id'] as String,
              foodKey: item['food_key'] as String? ?? '',
              displayName: item['display_name'] as String? ?? '',
            ),
          )
          .toList();

      final Map<String, FoodNutrition> nutritionByFoodId = {};
      if (foods.isNotEmpty) {
        final ids = foods.map((food) => food.id).toList();
        final quotedIds = ids.map((id) => '"$id"').join(',');
        final nutritionResponse = await _client
            .from('food_nutrition')
            .select(
              'food_id,serving_size_g,calories_kcal,carbs_g,protein_g,fat_g',
            )
            .filter('food_id', 'in', '($quotedIds)');

        final nutritionData = nutritionResponse as List<dynamic>? ?? [];
        for (final item in nutritionData) {
          if (item is Map<String, dynamic>) {
            final foodId = item['food_id']?.toString();
            if (foodId != null) {
              nutritionByFoodId[foodId] = FoodNutrition.fromJson(item);
            }
          }
        }
      }

      final merged = foods
          .map(
            (food) => Food(
              id: food.id,
              foodKey: food.foodKey,
              displayName: food.displayName,
              nutrition: nutritionByFoodId[food.id],
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _foods
          ..clear()
          ..addAll(merged);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load foods: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openFoodDialog({required Food food}) async {
    final nameController = TextEditingController(text: food.displayName);
    final caloriesController = TextEditingController(
      text: food.nutrition?.caloriesKcal?.toString() ?? '',
    );
    final carbsController = TextEditingController(
      text: food.nutrition?.carbsG?.toString() ?? '',
    );
    final proteinController = TextEditingController(
      text: food.nutrition?.proteinG?.toString() ?? '',
    );
    final fatController = TextEditingController(
      text: food.nutrition?.fatG?.toString() ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var saving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleSave() async {
                final displayName = nameController.text.trim();

                final caloriesText = caloriesController.text.trim();
                final carbsText = carbsController.text.trim();
              final proteinText = proteinController.text.trim();
              final fatText = fatController.text.trim();

              final hasAnyNutrition = caloriesText.isNotEmpty ||
                  carbsText.isNotEmpty ||
                  proteinText.isNotEmpty ||
                  fatText.isNotEmpty;
              final hasAllNutrition = caloriesText.isNotEmpty &&
                  carbsText.isNotEmpty &&
                  proteinText.isNotEmpty &&
                  fatText.isNotEmpty;

              if (hasAnyNutrition && !hasAllNutrition) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Fill all nutrition fields or leave them blank.',
                    ),
                  ),
                );
                return;
              }

              double? parseValue(String value) {
                if (value.isEmpty) return null;
                return double.tryParse(value);
              }

              final calories = parseValue(caloriesText);
              final carbs = parseValue(carbsText);
              final protein = parseValue(proteinText);
              final fat = parseValue(fatText);

              if (hasAllNutrition &&
                  (calories == null ||
                      carbs == null ||
                      protein == null ||
                      fat == null)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nutrition values must be valid numbers.'),
                  ),
                );
                return;
              }

              setDialogState(() => saving = true);
              try {
                if (displayName.isNotEmpty &&
                    displayName != food.displayName) {
                  await _client.from('foods').update(
                    {'display_name': displayName},
                  ).eq('id', food.id);
                }

                if (hasAllNutrition) {
                  await _client.from('food_nutrition').upsert(
                    {
                      'food_id': food.id,
                      'serving_size_g': 100,
                      'calories_kcal': calories,
                      'carbs_g': carbs,
                      'protein_g': protein,
                      'fat_g': fat,
                    },
                    onConflict: 'food_id',
                  );
                }

                if (!mounted) return;
                Navigator.of(dialogContext).pop();
                _loadFoods();
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Save failed. Check RLS policies.'),
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setDialogState(() => saving = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Edit Food'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: caloriesController,
                      decoration:
                          const InputDecoration(labelText: 'Calories (kcal)'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: carbsController,
                      decoration:
                          const InputDecoration(labelText: 'Carbs (g)'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: proteinController,
                      decoration:
                          const InputDecoration(labelText: 'Protein (g)'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: fatController,
                      decoration: const InputDecoration(labelText: 'Fat (g)'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : handleSave,
                  child: saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final foods = _filteredFoods;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Foods')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search foods',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          Expanded(
            child: foods.isEmpty
                ? Center(
                    child: Text(
                      _loading ? 'Loading foods...' : 'No foods found.',
                    ),
                  )
                : ListView.separated(
                    itemCount: foods.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final food = foods[index];
                      final calories = food.nutrition?.caloriesKcal;
                      return ListTile(
                        title: Text(food.displayName),
                        subtitle:
                            Text('Calories: ${_formatNumber(calories)} kcal'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _openFoodDialog(food: food),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
