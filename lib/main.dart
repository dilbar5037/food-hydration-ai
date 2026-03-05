import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'core/routing/app_router.dart';
import 'core/services/supabase_auto_refresh_guard.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SupabaseConfig.assertValid();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
  );

  // Critical: Runs before app UI to prevent stale Supabase session login failure
  // MUST complete before runApp() to ensure clean session state
  try {
    final supabaseClient = Supabase.instance.client;
    final currentSession = supabaseClient.auth.currentSession;

    if (currentSession != null) {
      try {
        // Attempt to refresh potentially stale session
        await supabaseClient.auth.refreshSession();

        // Server validation required because refreshSession may return locally
        // cached invalid token. getUser() validates against Supabase server.
        // If the token is truly invalid, this will throw AuthException.
        try {
          await supabaseClient.auth.getUser();
        } on AuthException catch (_) {
          // Session validation failed with server, clear invalid session
          await supabaseClient.auth.signOut();
        }
      } on AuthException catch (_) {
        // Session refresh failed with auth error, clear stale session
        await supabaseClient.auth.signOut();
      } catch (e) {
        // Unexpected error during refresh, clear session to be safe
        try {
          await supabaseClient.auth.signOut();
        } catch (_) {
          // Ignore signout errors
        }
      }
    }
  } catch (_) {
    // Silently ignore recovery errors - let app proceed
  }

  // Start auto refresh guard AFTER recovery is complete
  try {
    SupabaseAutoRefreshGuard().start();
  } catch (e) {
    debugPrint('Auto refresh guard start failed: $e');
  }

  // Only run app after session recovery is fully complete
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Supabase Auth Routing',
      theme: AppTheme.lightTheme(),
      routerConfig: AppRouter.router,
    );
  }
}
