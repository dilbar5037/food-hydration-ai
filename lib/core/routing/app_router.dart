import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/role_service.dart';
import '../../features/admin/admin_home_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/mentor/mentor_home_screen.dart';
import '../../features/foods/ui/food_scan_screen.dart';
import '../../features/todos/data/todo_service.dart';
import '../../features/user/user_home_screen.dart';
import '../../features/water_reminder/services/reminder_service.dart';

class AppRouter {
  AppRouter._();

  static final SupabaseClient _client = Supabase.instance.client;
  static final AuthService authService = AuthService(_client);
  static final RoleService roleService = RoleService(_client);
  static final _AuthStateNotifier _authNotifier = _AuthStateNotifier();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: _authNotifier,
    redirect: (context, state) {
      final isLoggedIn = authService.currentSession != null;
      final loggingIn = state.uri.path == '/login';
      final signingUp = state.uri.path == '/signup';

      if (!isLoggedIn && !loggingIn && !signingUp) {
        return '/login';
      }

      if (isLoggedIn && (loggingIn || signingUp)) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => RoleGate(
          roleService: roleService,
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          authService: authService,
          roleService: roleService,
        ),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => SignupScreen(
          authService: authService,
          roleService: roleService,
        ),
      ),
      GoRoute(
        path: '/user',
        builder: (context, state) => UserHomeScreen(
          authService: authService,
        ),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => AdminHomeScreen(
          authService: authService,
        ),
      ),
      GoRoute(
        path: '/mentor',
        builder: (context, state) => MentorHomeScreen(
          authService: authService,
        ),
      ),
      GoRoute(
        path: '/food-scan',
        builder: (context, state) => const FoodScanScreen(),
      ),
    ],
  );
}

class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class RoleGate extends StatefulWidget {
  const RoleGate({super.key, required this.roleService});

  final RoleService roleService;

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  late Future<String> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = _resolveRole();
  }

  Future<String> _resolveRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return 'unauthenticated';
    }
    await widget.roleService.ensureProfileExists(email: user.email ?? '');
    try {
      await TodoService().ensureDefaultTodosForToday();
    } catch (_) {
      // Skip failures to avoid blocking routing.
    }
    try {
      await ReminderService().initializeReminders(user.id);
    } catch (_) {
      // Skip failures to avoid blocking routing.
    }
    return widget.roleService.getCurrentRole();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingScreen();
        }

        if (snapshot.hasError) {
          return _ErrorScreen(
            message: snapshot.error.toString(),
            onRetry: () {
              setState(() {
                _roleFuture = _resolveRole();
              });
            },
          );
        }

        final role = snapshot.data;
        switch (role) {
          case 'admin':
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/admin');
            });
            break;
          case 'mentor':
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/mentor');
            });
            break;
          case 'user':
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/user');
            });
            break;
          default:
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/login');
            });
        }

        return const _LoadingScreen();
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Unable to load role'),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
