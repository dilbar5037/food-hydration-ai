import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_service.dart';
import '../hydration/hydration_screen.dart';
import 'health_dashboard_screen.dart';
import 'scan_meal_screen.dart';
import 'meal_history_screen.dart';
import 'profile_setup_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  String? _activityLevel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivityLevel();
  }

  Future<void> _loadActivityLevel() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await client
          .from('user_metrics')
          .select('activity_level')
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _activityLevel = response?['activity_level'] as String?;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await widget.authService.signOut();
    if (context.mounted) {
      context.go('/login');
    }
  }

  Future<void> _openProfileSetup() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ProfileSetupScreen(),
      ),
    );
    if (result == true && mounted) {
      _loadActivityLevel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('User Home'),
            const SizedBox(height: 8),
            Text(
              _isLoading
                  ? 'Loading activity level...'
                  : 'Activity level: ${_activityLevel ?? '--'}',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _openProfileSetup,
              child: const Text('Edit Profile'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _signOut(context),
              child: const Text('Sign Out'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ScanMealScreen(),
                  ),
                );
              },
              child: const Text('Scan Meal'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MealHistoryScreen(),
                  ),
                );
              },
              child: const Text('Meal History'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HealthDashboardScreen(),
                  ),
                );
              },
              child: const Text('Dashboard'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HydrationScreen(),
                  ),
                );
              },
              child: const Text('Hydration'),
            ),
          ],
        ),
      ),
    );
  }
}
