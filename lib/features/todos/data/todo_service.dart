import 'package:supabase_flutter/supabase_flutter.dart';

class TodoService {
  TodoService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> ensureDefaultTodosForToday() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    final today = _todayUtcDate();
    final existing = await _client
        .from('user_todos')
        .select('id')
        .eq('user_id', userId)
        .eq('todo_date', today)
        .limit(1);

    if (existing.isNotEmpty) {
      return;
    }

    await _client.from('user_todos').insert([
      {
        'user_id': userId,
        'title': 'Log all meals today',
        'category': 'diet',
        'is_done': false,
        'todo_date': today,
      },
      {
        'user_id': userId,
        'title': 'Drink at least 2000 ml water',
        'category': 'hydration',
        'is_done': false,
        'todo_date': today,
      },
      {
        'user_id': userId,
        'title': 'Avoid sugary drinks today',
        'category': 'diet',
        'is_done': false,
        'todo_date': today,
      },
    ]);
  }

  Future<List<Map<String, dynamic>>> fetchTodayTodos() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return [];
    }

    final today = _todayUtcDate();
    final response = await _client
        .from('user_todos')
        .select()
        .eq('user_id', userId)
        .eq('todo_date', today)
        .order('created_at');

    final data = response as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> setTodoDone(String id, bool done) async {
    await _client.from('user_todos').update({'is_done': done}).eq('id', id);
  }

  String _todayUtcDate() {
    final now = DateTime.now().toUtc();
    final date = DateTime.utc(now.year, now.month, now.day);
    return date.toIso8601String().split('T').first;
  }
}
