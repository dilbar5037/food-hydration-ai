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
    final fallbackName = (metadataName != null && metadataName.isNotEmpty)
        ? metadataName
        : (userEmail?.split('@').first ?? '');

    Map<String, dynamic>? row = await _client
        .from('app_users')
        .select('role')
        .eq('id', userId)
        .maybeSingle();

    if (row == null) {
      // ONLY create profile fields, NEVER role
      await _client.from('app_users').insert({
        'id': userId,
        'email': userEmail,
        'name': fallbackName,
      });

      row = await _client
          .from('app_users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
    }

    final role = row?['role'] as String?;
    if (role == null) {
      throw StateError('Role not found for user $userId');
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
    final fallbackName = (metadataName != null && metadataName.isNotEmpty)
        ? metadataName
        : userEmail.split('@').first;

    final existing = await _client
        .from('app_users')
        .select('id')
        .eq('id', userId)
        .maybeSingle();

    if (existing != null) return;

    // Insert profile WITHOUT role
    await _client.from('app_users').insert({
      'id': userId,
      'email': userEmail,
      'name': fallbackName,
    });
  }
}
