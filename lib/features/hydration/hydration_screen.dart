import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../user/profile_setup_screen.dart';

class HydrationScreen extends StatefulWidget {
  const HydrationScreen({super.key});

  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = true;
  bool _needsProfile = false;
  int _goalMl = 0;
  int _consumedMl = 0;
  List<_WaterLogEntry> _todayLogs = [];
  List<_WeeklyTotal> _weeklyTotals = [];

  @override
  void initState() {
    super.initState();
    _loadHydration();
  }

  double _activityFactor(String? level) {
    switch (level) {
      case 'medium':
        return 1.1;
      case 'high':
        return 1.25;
      case 'low':
      default:
        return 1.0;
    }
  }

  Future<void> _loadHydration() async {
    setState(() {
      _isLoading = true;
      _needsProfile = false;
    });

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      _showSnackBar('No authenticated user found.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    bool needsProfile = _needsProfile;
    int goalMl = _goalMl;
    int consumedMl = _consumedMl;
    List<_WaterLogEntry> todayLogs = _todayLogs;
    List<_WeeklyTotal> weeklyTotals = _weeklyTotals;

    try {
      final metrics = await _client
          .from('user_metrics')
          .select('weight_kg, activity_level')
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      final weightValue = metrics?['weight_kg'];
      final activityLevel = metrics?['activity_level'] as String?;

      if (metrics == null || weightValue == null || activityLevel == null) {
        needsProfile = true;
      } else {
        needsProfile = false;
        final weightKg = (weightValue as num).toDouble();
        final base = weightKg * 35;
        final factor = _activityFactor(activityLevel);
        goalMl = (base * factor).round();

        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final logs = await _client
            .from('water_logs')
            .select('amount_ml, logged_at')
            .eq('user_id', userId)
            .gte('logged_at', startOfDay.toIso8601String())
            .lt('logged_at', endOfDay.toIso8601String())
            .order('logged_at', ascending: false);

        consumedMl = 0;
        todayLogs = [];
        for (final row in logs) {
          final amount = row['amount_ml'];
          final loggedAtRaw = row['logged_at'];
          if (amount is int) {
            consumedMl += amount;
          } else if (amount is num) {
            consumedMl += amount.toInt();
          }
          final parsed = loggedAtRaw is String
              ? DateTime.tryParse(loggedAtRaw)
              : loggedAtRaw is DateTime
                  ? loggedAtRaw
                  : null;
          if (parsed != null) {
            final amountValue = amount is num ? amount.toInt() : 0;
            todayLogs.add(
              _WaterLogEntry(
                time: parsed.toLocal(),
                amountMl: amountValue,
              ),
            );
          }
        }
        if (todayLogs.length > 10) {
          todayLogs = todayLogs.take(10).toList();
        }

        final weekStart = startOfDay.subtract(const Duration(days: 6));
        final weekEnd = endOfDay;
        final weekLogs = await _client
            .from('water_logs')
            .select('amount_ml, logged_at')
            .eq('user_id', userId)
            .gte('logged_at', weekStart.toIso8601String())
            .lt('logged_at', weekEnd.toIso8601String());

        final totalsByDay = <DateTime, int>{};
        for (final row in weekLogs) {
          final amount = row['amount_ml'];
          final loggedAtRaw = row['logged_at'];
          final parsed = loggedAtRaw is String
              ? DateTime.tryParse(loggedAtRaw)
              : loggedAtRaw is DateTime
                  ? loggedAtRaw
                  : null;
          if (parsed == null) {
            continue;
          }
          final local = parsed.toLocal();
          final dayKey = DateTime(local.year, local.month, local.day);
          final amountValue = amount is num ? amount.toInt() : 0;
          totalsByDay[dayKey] = (totalsByDay[dayKey] ?? 0) + amountValue;
        }

        weeklyTotals = List<_WeeklyTotal>.generate(7, (index) {
          final day = weekStart.add(Duration(days: index));
          final total = totalsByDay[day] ?? 0;
          return _WeeklyTotal(date: day, totalMl: total);
        });
      }
    } catch (e) {
      _showSnackBar(e.toString());
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _needsProfile = needsProfile;
      _goalMl = goalMl;
      _consumedMl = consumedMl;
      _todayLogs = todayLogs;
      _weeklyTotals = weeklyTotals;
    });
  }

  Future<void> _addWater(int amount) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      _showSnackBar('No authenticated user found.');
      return;
    }

    try {
      await _client.from('water_logs').insert({
        'user_id': userId,
        'amount_ml': amount,
        'logged_at': DateTime.now().toIso8601String(),
      });
      await _loadHydration();
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  Future<void> _openProfileSetup() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ProfileSetupScreen(),
      ),
    );
    if (result == true && mounted) {
      _loadHydration();
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDayWithDate(DateTime day) {
    const labels = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    final label = labels[day.weekday - 1];
    final dd = day.day.toString().padLeft(2, '0');
    final mm = day.month.toString().padLeft(2, '0');
    final yyyy = day.year.toString().padLeft(4, '0');
    return '$label ($dd-$mm-$yyyy)';
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        _goalMl > 0 ? (_consumedMl / _goalMl).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Hydration')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _isLoading
              ? const CircularProgressIndicator()
              : _needsProfile
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Please complete your profile (weight & activity level) to enable hydration tracking.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _openProfileSetup,
                          child: const Text('Edit Profile'),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Daily Goal: $_goalMl ml'),
                          const SizedBox(height: 8),
                          Text('Consumed Today: $_consumedMl ml'),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 12,
                            children: [
                              ElevatedButton(
                                onPressed: () => _addWater(100),
                                child: const Text('+100ml'),
                              ),
                              ElevatedButton(
                                onPressed: () => _addWater(250),
                                child: const Text('+250ml'),
                              ),
                              ElevatedButton(
                                onPressed: () => _addWater(500),
                                child: const Text('+500ml'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Today Logs',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_todayLogs.isEmpty)
                            const Text('No water logs yet today')
                          else
                            Column(
                              children: _todayLogs.map((entry) {
                                final time = entry.time;
                                final hour =
                                    time.hour.toString().padLeft(2, '0');
                                final minute =
                                    time.minute.toString().padLeft(2, '0');
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('$hour:$minute'),
                                      Text('${entry.amountMl} ml'),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Weekly Summary',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: _weeklyTotals.map((entry) {
                              final label = _formatDayWithDate(entry.date);
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(label),
                                    Text('${entry.totalMl} ml'),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      ),
        ),
      ),
    );
  }
}

class _WaterLogEntry {
  const _WaterLogEntry({required this.time, required this.amountMl});

  final DateTime time;
  final int amountMl;
}

class _WeeklyTotal {
  const _WeeklyTotal({required this.date, required this.totalMl});

  final DateTime date;
  final int totalMl;
}
