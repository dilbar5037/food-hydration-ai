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
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: false,
    ),
  );

  try {
    SupabaseAutoRefreshGuard().start();
  } catch (e) {
    debugPrint('Auto refresh guard start failed: $e');
  }

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
