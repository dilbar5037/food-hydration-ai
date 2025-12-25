import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = false;
  bool _loadingUsers = false;

  List<_ScanCount> _topScans = [];
  List<Map<String, dynamic>> _mealLogs = [];

  List<_UserOption> _users = [];
  String? _selectedUserId; // null => All users

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadReports();
  }

  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() => _loading = true);

    await Future.wait([
      _loadTopScans(),
      _loadMealLogs(),
    ]);

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => _loadingUsers = true);

    try {
      final response = await _client
          .from('app_users')
          .select('id,email,role')
          .eq('role', 'user')
          .order('email');

      final data = response as List<dynamic>? ?? [];
      final users = data
          .whereType<Map<String, dynamic>>()
          .map((row) => _UserOption(
                id: row['id']?.toString() ?? '',
                email: row['email']?.toString() ?? 'Unknown',
              ))
          .where((u) => u.id.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _users = users;
        if (_selectedUserId != null &&
            !_users.any((user) => user.id == _selectedUserId)) {
          _selectedUserId = null;
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingUsers = false);
      }
    }
  }

  Future<void> _loadTopScans() async {
    List<dynamic> data = [];

    // Your table name is food_scan_logs (from screenshot)
    // Columns: id, user_id, predicted_label, confidence, servings, eaten_at, image_path
    try {
      var query = _client.from('food_scan_logs').select('*');
      if (_selectedUserId != null) {
        query = query.eq('user_id', _selectedUserId!);
      }

      // Try ordering by eaten_at first (exists), fall back to no order
      try {
        data = await query.order('eaten_at', ascending: false).limit(1000);
      } catch (_) {
        data = await query.limit(1000);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load scan logs: $error')),
        );
      }
      data = [];
    }

    final counts = <String, int>{};

    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;

      final raw = item['predicted_label']?.toString();
      final normalized = _normalizeLabel(raw);

      counts[normalized] = (counts[normalized] ?? 0) + 1;
    }

    final scanCounts = counts.entries
        .map((e) => _ScanCount(label: _prettyLabel(e.key), count: e.value))
        .toList();

    scanCounts.sort((a, b) => b.count.compareTo(a.count));

    if (!mounted) return;
    setState(() {
      _topScans = scanCounts.take(5).toList();
    });
  }

  Future<void> _loadMealLogs() async {
    try {
      var query = _client.from('meal_logs').select('*');
      if (_selectedUserId != null) {
        query = query.eq('user_id', _selectedUserId!);
      }

      final response = await query.order('eaten_at', ascending: false).limit(10);

      final data = response as List<dynamic>? ?? [];
      final logs = data.whereType<Map<String, dynamic>>().toList();

      await _attachFoodNames(logs);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load meal logs: $error')),
        );
      }
      if (mounted) {
        setState(() => _mealLogs = []);
      }
    }
  }

  Future<void> _attachFoodNames(List<Map<String, dynamic>> logs) async {
    final foodIds = <String>{};

    for (final log in logs) {
      final id = log['food_id']?.toString();
      if (id != null && id.isNotEmpty) {
        foodIds.add(id);
      }
    }

    final Map<String, String> idToName = {};

    if (foodIds.isNotEmpty) {
      try {
        final response = await _client
            .from('foods')
            .select('id,display_name')
            .inFilter('id', foodIds.toList());

        final data = response as List<dynamic>? ?? [];
        for (final food in data) {
          if (food is Map<String, dynamic>) {
            final id = food['id']?.toString();
            final name = food['display_name']?.toString();
            if (id != null && name != null && name.trim().isNotEmpty) {
              idToName[id] = name.trim();
            }
          }
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load foods: $error')),
          );
        }
      }
    }

    final enriched = logs.map((log) {
      final foodId = log['food_id']?.toString();
      final displayName =
          (foodId != null && foodId.isNotEmpty) ? idToName[foodId] : null;

      return {
        ...log,
        'display_name': displayName,
      };
    }).toList();

    if (!mounted) return;
    setState(() => _mealLogs = enriched);
  }

  String _normalizeLabel(String? raw) {
    final v = raw?.trim();
    if (v == null || v.isEmpty) return 'unknown';
    return v.toLowerCase();
  }

  // Optional prettify (keeps unknown readable)
  String _prettyLabel(String normalized) {
    if (normalized == 'unknown') return 'Unknown';
    if (normalized.isEmpty) return 'Unknown';
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Unknown';
    if (value is DateTime) return value.toLocal().toString();
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return 'Unknown';
    return parsed.toLocal().toString();
  }

  String _formatCalories(dynamic value) {
    if (value == null) return '';
    if (value is num) return value.toString();
    final parsed = double.tryParse(value.toString());
    if (parsed == null) return '';
    final isWhole = parsed % 1 == 0;
    return isWhole ? parsed.toStringAsFixed(0) : parsed.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Reports')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String?>(
                    value: _selectedUserId,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Users'),
                      ),
                      ..._users.map(
                        (u) => DropdownMenuItem<String?>(
                          value: u.id,
                          child: Text(u.email),
                        ),
                      ),
                    ],
                    onChanged: _loadingUsers
                        ? null
                        : (value) {
                            setState(() => _selectedUserId = value);
                            _loadReports();
                          },
                    decoration: const InputDecoration(
                      labelText: 'Filter by user',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Top scans
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Top 5 Scanned Foods',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          if (_topScans.isEmpty)
                            const Text('No scan logs yet')
                          else
                            Column(
                              children: _topScans
                                  .map(
                                    (item) => Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text(item.label)),
                                        Text(item.count.toString()),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Meal logs
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Last 10 Meal Logs',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          if (_mealLogs.isEmpty)
                            const Text('No data')
                          else
                            Column(
                              children: _mealLogs.map((log) {
                                final label = log['display_name']?.toString();
                                final foodId = log['food_id']?.toString();

                                final title = (label != null &&
                                        label.trim().isNotEmpty)
                                    ? label.trim()
                                    : (foodId != null && foodId.isNotEmpty)
                                        ? 'Food: $foodId'
                                        : 'Unknown food';

                                final calories = _formatCalories(
                                  log['calories_kcal'] ?? log['calories'],
                                );

                                final eatenAt = _formatDate(log['eaten_at']);

                                final subtitle = calories.isEmpty
                                    ? eatenAt
                                    : '$eatenAt - $calories kcal';

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(title),
                                  subtitle: Text(subtitle),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanCount {
  const _ScanCount({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;
}

class _UserOption {
  const _UserOption({
    required this.id,
    required this.email,
  });

  final String id;
  final String email;
}
