import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../ui/components/app_card.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;

  // ── Existing metrics ──────────────────────────────────────────────────────
  int totalUsers = 0;
  int newUsersThisWeek = 0;

  int mealsToday = 0;
  double avgMealsPerUser = 0;
  int totalMeals = 0;

  int scansToday = 0;
  String mostScannedFood = '—';

  int peakHour = 0;

  List<int> last7DaysMealCounts = List.filled(7, 0);

  // ── New metrics ───────────────────────────────────────────────────────────
  int activeUsersToday = 0;
  double avgWaterIntakeMl = 0;
  List<_TopFood> topFoods = [];
  int systemHealthMs = -1;   // -1 = unmeasured
  int errorCountToday = 0;   // incremented in catch blocks

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (mounted) setState(() => _loading = true);

    final now = DateTime.now().toUtc();
    final startOfToday = DateTime.utc(now.year, now.month, now.day);
    final startOfTomorrow = startOfToday.add(const Duration(days: 1));
    final weekAgo = startOfToday.subtract(const Duration(days: 6));

    // ── System health: measure round-trip latency ─────────────────────────
    final sw = Stopwatch()..start();
    try {
      await _client.from('profiles').select('id').limit(1);
      sw.stop();
      systemHealthMs = sw.elapsedMilliseconds;
    } catch (_) {
      sw.stop();
      systemHealthMs = -1;
      errorCountToday++;
    }

    // ── Users ─────────────────────────────────────────────────────────────
    try {
      final profilesResp = await _client.from('profiles').select('id,created_at');
      final profiles = ((profilesResp as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      totalUsers = profiles.length;

      newUsersThisWeek = profiles.where((p) {
        final raw = p['created_at'];
        if (raw == null) return false;
        final parsed = DateTime.tryParse(raw.toString());
        return parsed != null && parsed.toUtc().isAfter(weekAgo);
      }).length;
    } catch (_) {
      errorCountToday++;
    }

    // ── Meals ─────────────────────────────────────────────────────────────
    List<Map<String, dynamic>> allMeals = [];
    try {
      final mealsTodayResp = await _client
          .from('meal_logs')
          .select('id,user_id,eaten_at,food_name')
          .gte('eaten_at', startOfToday.toIso8601String())
          .lt('eaten_at', startOfTomorrow.toIso8601String());
      final mealsTodayList = ((mealsTodayResp as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      mealsToday = mealsTodayList.length;

      // Active users today = distinct user_ids in today's meals
      final uniqueUserIds = mealsTodayList
          .map((m) => m['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      activeUsersToday = uniqueUserIds.length;

      final allMealsResp = await _client
          .from('meal_logs')
          .select('id,user_id,eaten_at,food_name');
      allMeals = ((allMealsResp as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      totalMeals = allMeals.length;
      avgMealsPerUser = totalUsers > 0 ? totalMeals / totalUsers : 0;
    } catch (_) {
      errorCountToday++;
    }

    // ── Top Foods (last 7 days) ────────────────────────────────────────────
    try {
      final weekMeals = allMeals.where((m) {
        final raw = m['eaten_at'];
        if (raw == null) return false;
        final d = DateTime.tryParse(raw.toString());
        return d != null && d.toUtc().isAfter(weekAgo);
      }).toList();

      final foodCounts = <String, int>{};
      for (final m in weekMeals) {
        final name = (m['food_name']?.toString() ?? '').trim();
        if (name.isEmpty) continue;
        foodCounts[name] = (foodCounts[name] ?? 0) + 1;
      }
      final sorted = foodCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topFoods = sorted
          .take(5)
          .map((e) => _TopFood(name: e.key, count: e.value))
          .toList();
    } catch (_) {
      errorCountToday++;
    }

    // ── Scans ─────────────────────────────────────────────────────────────
    List<Map<String, dynamic>> recentScans = [];
    try {
      final scansTodayResp = await _client
          .from('food_scan_logs')
          .select('id,predicted_label,eaten_at')
          .gte('eaten_at', startOfToday.toIso8601String())
          .lt('eaten_at', startOfTomorrow.toIso8601String());
      final scansTodayList = ((scansTodayResp as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      scansToday = scansTodayList.length;

      final recentScansResp = await _client
          .from('food_scan_logs')
          .select('predicted_label,eaten_at')
          .order('eaten_at', ascending: false)
          .limit(1000);
      recentScans = ((recentScansResp as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final counts = <String, int>{};
      for (final s in recentScans) {
        final raw = s['predicted_label']?.toString() ?? 'unknown';
        final key = raw.trim().isEmpty ? 'unknown' : raw.trim();
        counts[key] = (counts[key] ?? 0) + 1;
      }
      if (counts.isNotEmpty) {
        final top = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        mostScannedFood = top.first.key;
      }
    } catch (_) {
      errorCountToday++;
    }

    // ── Hydration ─────────────────────────────────────────────────────────
    try {
      final hydrationResp = await _client
          .from('hydration_logs')
          .select('total_water_ml')
          .gte('logged_at', startOfToday.toIso8601String())
          .lt('logged_at', startOfTomorrow.toIso8601String());
      final hydrationList = ((hydrationResp as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      if (hydrationList.isNotEmpty) {
        final total = hydrationList.fold<double>(
          0,
          (sum, h) =>
              sum + (double.tryParse(h['total_water_ml']?.toString() ?? '0') ?? 0),
        );
        avgWaterIntakeMl = total / hydrationList.length;
      }
    } catch (_) {
      errorCountToday++;
    }

    // ── Peak hour ─────────────────────────────────────────────────────────
    try {
      final timestamps = <DateTime>[];
      for (final m in allMeals) {
        final raw = m['eaten_at'];
        if (raw == null) continue;
        final parsed = DateTime.tryParse(raw.toString());
        if (parsed != null) timestamps.add(parsed.toUtc());
      }
      for (final s in recentScans) {
        final raw = s['eaten_at'];
        if (raw == null) continue;
        final parsed = DateTime.tryParse(raw.toString());
        if (parsed != null) timestamps.add(parsed.toUtc());
      }
      final hourCounts = <int, int>{};
      for (final t in timestamps) {
        final h = t.toLocal().hour;
        hourCounts[h] = (hourCounts[h] ?? 0) + 1;
      }
      if (hourCounts.isNotEmpty) {
        final ordered = hourCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        peakHour = ordered.first.key;
      }
    } catch (_) {
      errorCountToday++;
    }

    // ── Last 7 days meal counts ───────────────────────────────────────────
    try {
      final dayCounts = List<int>.filled(7, 0);
      for (final m in allMeals) {
        final raw = m['eaten_at'];
        if (raw == null) continue;
        final parsed = DateTime.tryParse(raw.toString());
        if (parsed == null) continue;
        final diff = parsed.toUtc().difference(weekAgo).inDays;
        if (diff >= 0 && diff < 7) dayCounts[diff]++;
      }
      last7DaysMealCounts = dayCounts;
    } catch (_) {
      errorCountToday++;
    }

    if (mounted) setState(() => _loading = false);
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildStatGrid() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        AdminStatCard(title: 'Total Users', value: '$totalUsers', icon: Icons.people, color: AppColors.teal),
        AdminStatCard(title: 'Active Today', value: '$activeUsersToday', icon: Icons.person_pin_circle, color: const Color(0xFF0EA5E9)),
        AdminStatCard(title: 'Meals Today', value: '$mealsToday', icon: Icons.restaurant, color: AppColors.coral),
        AdminStatCard(title: 'Scans Today', value: '$scansToday', icon: Icons.camera_alt, color: AppColors.purple),
        AdminStatCard(title: 'Avg Water (ml)', value: avgWaterIntakeMl > 0 ? avgWaterIntakeMl.toStringAsFixed(0) : '—', icon: Icons.water_drop, color: const Color(0xFF06B6D4)),
        AdminStatCard(title: 'Peak Hour', value: () { final h = peakHour % 12 == 0 ? 12 : peakHour % 12; final p = peakHour >= 12 ? 'PM' : 'AM'; return '$h:00 $p'; }(), icon: Icons.schedule, color: AppColors.pink),
      ],
    );
  }

  Widget _buildBarChart() {
    final items = last7DaysMealCounts;
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= items.length) return const SizedBox.shrink();
                  final day = DateTime.now().subtract(Duration(days: 6 - idx));
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text('${day.month}/${day.day}', style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(items.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [BarChartRodData(toY: items[i].toDouble(), color: AppColors.teal, width: 14, borderRadius: BorderRadius.circular(4))],
            );
          }),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildTopFoodsPanel() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.local_fire_department, color: AppColors.coral, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Text('Top Foods This Week', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: AppSpacing.md),
          if (topFoods.isEmpty)
            Text('No meal data this week.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary))
          else
            ...topFoods.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final food = entry.value;
              final rankColors = [AppColors.coral, AppColors.teal, AppColors.purple, AppColors.pink, AppColors.textSecondary];
              final rankColor = rankColors[entry.key];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(children: [
                  SizedBox(
                    width: 24,
                    child: Text('#$rank', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: rankColor, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(food.name, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(color: rankColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text('${food.count}×', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: rankColor, fontWeight: FontWeight.w600)),
                  ),
                ]),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSystemHealthCard() {
    final isConnected = systemHealthMs >= 0;
    final latencyLabel = isConnected ? '$systemHealthMs ms' : 'Unreachable';
    final latencyColor = systemHealthMs < 200
        ? const Color(0xFF16A34A)
        : systemHealthMs < 600
            ? AppColors.coral
            : Colors.red;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: (isConnected ? const Color(0xFF16A34A) : Colors.red).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: isConnected ? const Color(0xFF16A34A) : Colors.red, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Text('System Health', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: AppSpacing.md),
          _HealthRow(label: 'Supabase Connection', value: isConnected ? '✅ Connected' : '❌ Disconnected', valueColor: isConnected ? const Color(0xFF16A34A) : Colors.red),
          _HealthRow(label: 'API Latency', value: latencyLabel, valueColor: latencyColor),
          _HealthRow(label: 'Errors This Session', value: '$errorCountToday', valueColor: errorCountToday == 0 ? const Color(0xFF16A34A) : AppColors.coral),
          _HealthRow(label: 'Most Scanned Food', value: mostScannedFood, valueColor: AppColors.textPrimary),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(icon: Icons.refresh, label: 'Refresh Analytics', color: AppColors.teal, onTap: _loadStats),
      _QuickAction(icon: Icons.file_download_outlined, label: 'Export Meal Logs', color: AppColors.coral, onTap: () => _showPlaceholder('Export Meal Logs')),
      _QuickAction(icon: Icons.group_outlined, label: 'Export User List', color: AppColors.purple, onTap: () => _showPlaceholder('Export User List')),
      _QuickAction(icon: Icons.summarize_outlined, label: 'Weekly Report', color: AppColors.pink, onTap: () => _showPlaceholder('Generate Weekly Report')),
    ];

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      children: actions.map((a) => _buildQuickActionTile(a)).toList(),
    );
  }

  Widget _buildQuickActionTile(_QuickAction action) {
    return AppCard(
      onTap: action.onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: action.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(action.icon, color: action.color, size: 20),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(action.label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
      ]),
    );
  }

  void _showPlaceholder(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action — coming soon'), duration: const Duration(seconds: 2)),
    );
  }

  String _generateInsight() {
    if (scansToday > mealsToday && scansToday > 0) return '📷 Users scan food but are not logging meals — consider adding meal-log prompts after scans.';
    if (avgMealsPerUser < 2) return '📉 Low engagement: avg ${avgMealsPerUser.toStringAsFixed(1)} meals/user. Consider push notification reminders.';
    if (newUsersThisWeek > (totalUsers * 0.05)) return '🚀 App growth accelerating — $newUsersThisWeek new users this week!';
    if (activeUsersToday == 0) return '😴 No user activity recorded today yet.';
    return '✅ System operating within expected ranges. $activeUsersToday users active today.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Intelligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadStats,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header card ──────────────────────────────────────────────
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('System Intelligence', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Live App Behaviour Overview', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Stat grid ────────────────────────────────────────────────
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                _buildStatGrid(),

              const SizedBox(height: AppSpacing.xl),

              // ── Weekly bar chart ─────────────────────────────────────────
              Text('Meals (last 7 days)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.md),
              _buildBarChart(),

              const SizedBox(height: AppSpacing.xl),

              // ── Top Foods ────────────────────────────────────────────────
              _buildTopFoodsPanel(),

              const SizedBox(height: AppSpacing.lg),

              // ── System Health ────────────────────────────────────────────
              _buildSystemHealthCard(),

              const SizedBox(height: AppSpacing.xl),

              // ── Quick Actions ────────────────────────────────────────────
              Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.md),
              _buildQuickActions(),

              const SizedBox(height: AppSpacing.lg),

              // ── Insights ─────────────────────────────────────────────────
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('System Insights', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.md),
                    Text(_generateInsight(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.5)),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Supporting data classes ───────────────────────────────────────────────────

class _TopFood {
  const _TopFood({required this.name, required this.count});
  final String name;
  final int count;
}

class _QuickAction {
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class AdminStatCard extends StatelessWidget {
  const AdminStatCard({super.key, required this.title, required this.value, required this.icon, required this.color});

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.label, required this.value, required this.valueColor});
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary))),
          Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: valueColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
