import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAutoRefreshGuard {
  SupabaseAutoRefreshGuard({
    Connectivity? connectivity,
    Duration debounce = const Duration(milliseconds: 400),
  })  : _connectivity = connectivity ?? Connectivity(),
        _debounce = debounce;

  final Connectivity _connectivity;
  final Duration _debounce;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounceTimer;

  void start() {
    try {
      _subscription ??=
          _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
      _scheduleToggle(_connectivity.checkConnectivity());
    } catch (e) {
      debugPrint('SupabaseAutoRefreshGuard start failed: $e');
    }
  }

  void stop() {
    try {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _subscription?.cancel();
      _subscription = null;
    } catch (e) {
      debugPrint('SupabaseAutoRefreshGuard stop failed: $e');
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> result) {
    try {
      _scheduleToggle(Future.value(result));
    } catch (e) {
      debugPrint('SupabaseAutoRefreshGuard change failed: $e');
    }
  }

  void _scheduleToggle(Future<List<ConnectivityResult>> resultFuture) {
    try {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_debounce, () async {
        try {
          final result = await resultFuture;
          final isOffline =
              result.isEmpty || result.contains(ConnectivityResult.none);
          if (isOffline) {
            try {
              Supabase.instance.client.auth.stopAutoRefresh();
            } catch (e) {
              debugPrint('SupabaseAutoRefreshGuard stop failed: $e');
            }
          } else {
            try {
              Supabase.instance.client.auth.startAutoRefresh();
            } catch (e) {
              debugPrint('SupabaseAutoRefreshGuard start failed: $e');
            }
          }
        } catch (e) {
          debugPrint('SupabaseAutoRefreshGuard debounce failed: $e');
        }
      });
    } catch (e) {
      debugPrint('SupabaseAutoRefreshGuard schedule failed: $e');
    }
  }
}
