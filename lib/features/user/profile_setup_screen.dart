import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final _client = Supabase.instance.client;

  String _activityLevel = 'low';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _error = 'No authenticated user found.';
        _isLoading = false;
      });
      return;
    }

    try {
      final existing = await _client
          .from('user_metrics')
          .select()
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      if (existing == null) {
        await _client.from('user_metrics').insert({
          'user_id': userId,
          'activity_level': 'low',
        });
        _activityLevel = 'low';
      } else {
        final age = existing['age'] as int?;
        final weight = existing['weight_kg'];
        final height = existing['height_cm'];
        final level = existing['activity_level'] as String?;

        _ageController.text = age?.toString() ?? '';
        _weightController.text =
            weight != null ? weight.toString() : '';
        _heightController.text =
            height != null ? height.toString() : '';
        _activityLevel = level ?? 'low';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _error = 'No authenticated user found.';
      });
      return;
    }

    final ageText = _ageController.text.trim();
    final weightText = _weightController.text.trim();
    final heightText = _heightController.text.trim();

    final age = ageText.isEmpty ? null : int.tryParse(ageText);
    final weight =
        weightText.isEmpty ? null : double.tryParse(weightText);
    final height =
        heightText.isEmpty ? null : double.tryParse(heightText);

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await _client.from('user_metrics').update({
        'age': age,
        'weight_kg': weight,
        'height_cm': height,
        'activity_level': _activityLevel,
      }).eq('user_id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _heightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Height (cm)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _activityLevel,
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _activityLevel = value;
                    });
                  }
                },
                decoration:
                    const InputDecoration(labelText: 'Activity level'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
