import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _waterController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _waterController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final response = await _client
          .from('settings')
          .select('key,value_json')
          .eq('key', 'app_defaults')
          .maybeSingle();

      final data = response as Map<String, dynamic>?;
      final valueJson = data?['value_json'];
      if (valueJson is Map<String, dynamic>) {
        final calories = valueJson['default_daily_calories_kcal'];
        final water = valueJson['default_daily_water_ml'];
        if (calories != null) {
          _caloriesController.text = calories.toString();
        }
        if (water != null) {
          _waterController.text = water.toString();
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    final caloriesText = _caloriesController.text.trim();
    final waterText = _waterController.text.trim();
    final calories = double.tryParse(caloriesText);
    final water = double.tryParse(waterText);

    if (calories == null || water == null || calories <= 0 || water <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid numbers greater than 0.')),
      );
      return;
    }

    try {
      await _client.from('settings').upsert(
        {
          'key': 'app_defaults',
          'value_json': {
            'default_daily_calories_kcal': calories,
            'default_daily_water_ml': water,
          },
        },
        onConflict: 'key',
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _caloriesController,
              decoration: const InputDecoration(
                labelText: 'Default Daily Calories (kcal)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _waterController,
              decoration: const InputDecoration(
                labelText: 'Default Daily Water (ml)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: _loading ? null : _saveSettings,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
