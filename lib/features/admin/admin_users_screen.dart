import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final List<Map<String, dynamic>> _users = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  String _formatCreatedAt(dynamic value) {
    if (value == null) return 'Unknown';
    if (value is DateTime) {
      return value.toLocal().toString();
    }
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return 'Unknown';
    return parsed.toLocal().toString();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final response = await _client
          .from('app_users')
          .select('id,email,role,created_at')
          .order('created_at', ascending: false)
          .limit(200);

      final data = response as List<dynamic>? ?? [];
      final users = data.whereType<Map<String, dynamic>>().toList();
      if (!mounted) return;
      setState(() {
        _users
          ..clear()
          ..addAll(users);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _editUserRole({
    required String userId,
    required String currentRole,
    required String email,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId != null && currentUserId == userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot edit your own role.')),
      );
      return;
    }

    var selectedRole = currentRole;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var saving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleSave() async {
              setDialogState(() => saving = true);
              try {
                await _client.rpc('admin_set_user_role', params: {
                  'p_user_id': userId,
                  'p_new_role': selectedRole,
                });
                if (!mounted) return;
                Navigator.of(dialogContext).pop();
                _loadUsers();
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update role: $error')),
                  );
                }
              } finally {
                if (mounted) {
                  setDialogState(() => saving = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Edit Role'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(email),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('admin')),
                      DropdownMenuItem(value: 'mentor', child: Text('mentor')),
                      DropdownMenuItem(value: 'user', child: Text('user')),
                    ],
                    onChanged: saving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setDialogState(() => selectedRole = value);
                          },
                    decoration: const InputDecoration(labelText: 'Role'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : handleSave,
                  child: saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users & Roles')),
      body: Column(
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          Expanded(
            child: _users.isEmpty
                ? Center(
                    child:
                        Text(_loading ? 'Loading users...' : 'No users found.'),
                  )
                : ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final userId = user['id']?.toString() ?? '';
                      final email = user['email']?.toString() ?? 'Unknown';
                      final role = user['role']?.toString() ?? 'unknown';
                      final createdAt = _formatCreatedAt(user['created_at']);
                      return ListTile(
                        title: Text(email),
                        subtitle: Text('Role: $role · $createdAt'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: userId.isEmpty
                              ? null
                              : () => _editUserRole(
                                    userId: userId,
                                    currentRole: role,
                                    email: email,
                                  ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
