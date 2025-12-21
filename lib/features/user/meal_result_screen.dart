import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../foods/models/food_models.dart';
import 'meal_log_repo.dart';

class MealResultScreen extends StatefulWidget {
  const MealResultScreen({
    super.key,
    required this.imagePath,
    required this.predictedLabel,
    required this.confidence,
  });

  final String imagePath;
  final String predictedLabel;
  final double confidence;

  @override
  State<MealResultScreen> createState() => _MealResultScreenState();
}

class _MealResultScreenState extends State<MealResultScreen> {
  final MealLogRepo _repo = MealLogRepo(Supabase.instance.client);

  bool _isLoading = true;
  bool _isSaving = false;
  String? _foodId;
  FoodNutrition? _nutrition;
  String? _error;
  double _servings = 1.0;

  @override
  void initState() {
    super.initState();
    _loadNutrition();
  }

  Future<void> _loadNutrition() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final food = await _repo.findFoodByLabel(widget.predictedLabel);
      final foodId = food?['id'] as String?;
      FoodNutrition? nutrition;
      if (foodId != null) {
        nutrition = await _repo.fetchNutrition(foodId);
      }
      if (!mounted) return;
      setState(() {
        _foodId = foodId;
        _nutrition = nutrition;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save({String? foodId}) async {
    if (_isSaving) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to log a meal.')),
        );
      }
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repo.insertMealLog(
        userId: userId,
        foodId: foodId,
        servings: _servings,
        confidence: widget.confidence,
        imagePath: widget.imagePath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal saved')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save meal: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _changeServings(double delta) {
    setState(() {
      final next = (_servings + delta).clamp(0.5, 10.0);
      _servings = double.parse(next.toStringAsFixed(1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.imagePath);
    final confidencePercent = (widget.confidence * 100).clamp(0, 100);

    return Scaffold(
      appBar: AppBar(title: const Text('Meal Result')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Image selected ✅'),
                    const SizedBox(height: 12),
                    if (file.existsSync())
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          file,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Predicted: ${widget.predictedLabel}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Confidence: ${confidencePercent.toStringAsFixed(1)}%',
                    ),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      Text(
                        'Error loading nutrition: $_error',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadNutrition,
                        child: const Text('Retry'),
                      ),
                    ] else if (_foodId == null || _nutrition == null) ...[
                      const Text('Food not recognized in database'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Try Again'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : () => _save(foodId: null),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Save as Unknown'),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Nutrition',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _buildRow(
                        'Calories',
                        _formatNumber(_nutrition?.caloriesKcal, unit: 'kcal'),
                      ),
                      _buildRow(
                        'Carbs',
                        _formatNumber(_nutrition?.carbsG, unit: 'g'),
                      ),
                      _buildRow(
                        'Protein',
                        _formatNumber(_nutrition?.proteinG, unit: 'g'),
                      ),
                      _buildRow(
                        'Fat',
                        _formatNumber(_nutrition?.fatG, unit: 'g'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Servings'),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: _isSaving ? null : () => _changeServings(-0.5),
                            icon: const Icon(Icons.remove),
                          ),
                          Text(
                            _formatNumber(_servings),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            onPressed: _isSaving ? null : () => _changeServings(0.5),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : () => _save(foodId: _foodId),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Confirm'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
