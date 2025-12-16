import 'package:supabase_flutter/supabase_flutter.dart';

class RoleService {
  RoleService(this._client);

  final SupabaseClient _client;

  Future<String> getCurrentRole() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('No authenticated user found.');
    }

    final response = await _client
        .from('app_users')
        .select('role')
        .eq('id', userId)
        .limit(1)
        .maybeSingle();

    final role = response?['role'] as String?;
    if (role == null) {
      throw StateError('Role not found for user $userId.');
    }
    return role;
  }

  Future<void> ensureProfileExists({required String email}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('No authenticated user found.');
    }

    final existing = await _client
        .from('app_users')
        .select('id')
        .eq('id', userId)
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      return;
    }

    final name = email.split('@').first;
    await _client.from('app_users').insert({
      'id': userId,
      'role': 'user',
      'name': name,
    });
  }
}
