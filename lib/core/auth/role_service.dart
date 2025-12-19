import 'package:supabase_flutter/supabase_flutter.dart';

class RoleService {
  RoleService(this._client);

  final SupabaseClient _client;

  Future<String> getCurrentRole() async {
    final user = _client.auth.currentUser;
    final userId = user?.id;
    if (userId == null) {
      throw StateError('No authenticated user found.');
    }
    final userEmail = user?.email;
    final metadataName = (user?.userMetadata?['name'] as String?)?.trim();
    final fallbackName =
        (metadataName != null && metadataName.isNotEmpty) ? metadataName : (user?.email?.split('@').first ?? '');

    Map<String, dynamic>? row = await _client
        .from('app_users')
        .select('role')
        .eq('id', userId)
        .limit(1)
        .maybeSingle();

    if (row == null) {
      await _client.from('app_users').upsert({
        'id': userId,
        'email': userEmail,
        'name': fallbackName,
        'role': 'user',
      }, onConflict: 'id');

      row = await _client
          .from('app_users')
          .select('role')
          .eq('id', userId)
          .limit(1)
          .maybeSingle();
    }

    final role = row?['role'] as String?;
    if (role == null) {
      throw StateError('Role not found for user $userId.');
    }
    return role;
  }

  Future<void> ensureProfileExists({required String email}) async {
    final user = _client.auth.currentUser;
    final userId = user?.id;
    if (userId == null) {
      throw StateError('No authenticated user found.');
    }
    final userEmail = user?.email ?? email;
    final metadataName = (user?.userMetadata?['name'] as String?)?.trim();
    final fallbackName =
        (metadataName != null && metadataName.isNotEmpty) ? metadataName : (user?.email?.split('@').first ?? '');

    await _client.from('app_users').upsert({
      'id': userId,
      'email': userEmail,
      'name': fallbackName,
      'role': 'user',
    }, onConflict: 'id');
  }
}
