import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food_scan_log.dart';

class FoodScanLogService {
  FoodScanLogService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> logScan({
    required String label,
    required double confidence,
    String? imagePath,
    String? dedupeKey,
    bool rethrowErrors = false,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    final log = FoodScanLog(
      userId: userId,
      predictedLabel: label,
      confidence: confidence,
      imagePath: imagePath,
      dedupeKey: dedupeKey,
    );

    try {
      await _client.from('food_scan_logs').insert(log.toJson());
    } catch (e) {
      debugPrint('Failed to log scan: $e');
      if (rethrowErrors) {
        throw Exception('Failed to log scan: $e');
      }
    }
  }
}
