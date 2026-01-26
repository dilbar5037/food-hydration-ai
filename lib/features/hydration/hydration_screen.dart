import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ui/components/app_card.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../notifications/water_reminder_service.dart';
import '../user/profile_setup_screen.dart';
import '../water_reminder/services/reminder_service.dart';

class HydrationScreen extends StatefulWidget {
  const HydrationScreen({super.key});

  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen>
    with WidgetsBindingObserver {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = true;
  bool _needsProfile = false;
  int _goalMl = 0;
  int _consumedMl = 0;
  List<_WaterLogEntry> _todayLogs = [];
  List<_WeeklyTotal> _weeklyTotals = [];
  RealtimeChannel? _waterLogsChannel;
  Timer? _realtimeDebounce;
  String? _realtimeUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHydration();
    _initRealtime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtimeDebounce?.cancel();
    if (_waterLogsChannel != null) {
      _client.removeChannel(_waterLogsChannel!);
      _waterLogsChannel = null;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isLoading) {
      _loadHydration();
    }
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

  void _initRealtime() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }
    if (_realtimeUserId == userId && _waterLogsChannel != null) {
      return;
    }
    if (_waterLogsChannel != null) {
      _client.removeChannel(_waterLogsChannel!);
      _waterLogsChannel = null;
    }
    _realtimeUserId = userId;

    final channel = _client.channel('water_logs_realtime_$userId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'water_logs',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        _scheduleRealtimeRefresh();
      },
    );

    _waterLogsChannel = channel..subscribe();
  }

  void _scheduleRealtimeRefresh() {
    if (_isLoading || _needsProfile) {
      return;
    }
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || _isLoading) {
        return;
      }
      _loadHydration();
    });
  }

  Future<void> _loadHydration() async {
    _initRealtime();
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
      try {
        await WaterReminderService().onWaterLogged();
      } catch (_) {}
      try {
        final reminderService = ReminderService();
        final goalMet = await reminderService.isDailyGoalMet();
        if (goalMet) {
          await reminderService.cancelRemainingRemindersForToday();
        }
      } catch (_) {}
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

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildHeroCard(double progress) {
    final percent = (progress * 100).round();
    final statusText = percent >= 100
        ? 'Goal met'
        : percent >= 50
            ? 'On track'
            : 'Behind';
    final statusColor = percent >= 100
        ? AppColors.teal
        : percent >= 50
            ? AppColors.coral
            : AppColors.pink;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE0F2FE),
            Color(0xFFF0FDFA),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hydration',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Today',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_consumedMl ml',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'of $_goalMl ml',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      backgroundColor: Colors.white.withOpacity(0.6),
                      color: AppColors.teal,
                    ),
                    Text(
                      '$percent%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddButtons() {
    return Row(
      children: [
        Expanded(child: _buildAddButton(100)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildAddButton(250)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildAddButton(500)),
      ],
    );
  }

  Widget _buildAddButton(int amount) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _addWater(amount),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.water_drop_outlined,
                size: 18,
                color: AppColors.teal,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '+$amount ml',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.teal,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayLogsCard() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today Logs',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${_todayLogs.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_todayLogs.isEmpty)
            Text(
              'No logs yet today',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _todayLogs.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final entry = _todayLogs[index];
                return Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.teal.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.teal,
                          width: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _formatTime(entry.time),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Text(
                      '${entry.amountMl} ml',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildWeeklySummaryCard() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Summary',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _weeklyTotals.length,
            separatorBuilder: (_, __) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final entry = _weeklyTotals[index];
              final label = _formatDayWithDate(entry.date);
              final ratio = _goalMl > 0
                  ? (entry.totalMl / _goalMl).clamp(0.0, 1.0)
                  : 0.0;
              final percent = (ratio * 100).round();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${entry.totalMl} ml',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: AppColors.border.withOpacity(0.2),
                      color: AppColors.teal.withOpacity(0.7),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        _goalMl > 0 ? (_consumedMl / _goalMl).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Hydration')),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF0FDFA),
                AppColors.background,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _needsProfile
                    ? Center(
                        child: Column(
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
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeroCard(progress),
                            const SizedBox(height: AppSpacing.xl),
                            _buildQuickAddButtons(),
                            const SizedBox(height: AppSpacing.xl),
                            _buildTodayLogsCard(),
                            const SizedBox(height: AppSpacing.xl),
                            _buildWeeklySummaryCard(),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                        ),
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
