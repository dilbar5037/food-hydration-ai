import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class WaterReminderSettings {
  const WaterReminderSettings({
    required this.enabled,
    required this.times,
  });

  final bool enabled;
  final List<String> times;
}

class WaterReminderRepository {
  WaterReminderRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<WaterReminderSettings> fetchSettings() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const WaterReminderSettings(
        enabled: false,
        times: [],
      );
    }

    try {
      final response = await _client
          .from('user_notification_settings')
          .select('water_reminders_enabled, water_reminder_times')
          .eq('user_id', userId)
          .maybeSingle();

      final enabled =
          response?['water_reminders_enabled'] as bool? ?? true;
      final times = _parseTimes(response?['water_reminder_times']);
      return WaterReminderSettings(enabled: enabled, times: times);
    } catch (_) {
      return const WaterReminderSettings(
        enabled: true,
        times: ['10:30', '13:30', '16:30', '19:30'],
      );
    }
  }

  Future<void> saveSettings(WaterReminderSettings settings) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    await _client.from('user_notification_settings').upsert(
      {
        'user_id': userId,
        'water_reminders_enabled': settings.enabled,
        'water_reminder_times': jsonEncode(settings.times),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id',
    );
  }

  Future<Set<int>> fetchEventTimestampsForDay({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return {};
    }

    final response = await _client
        .from('water_reminder_events')
        .select('scheduled_at')
        .eq('user_id', userId)
        .gte('scheduled_at', startUtc.toIso8601String())
        .lt('scheduled_at', endUtc.toIso8601String());

    final rows = response as List<dynamic>? ?? [];
    final timestamps = <int>{};
    for (final row in rows) {
      final map = Map<String, dynamic>.from(row as Map);
      final scheduledAt = _parseDateTime(map['scheduled_at']);
      if (scheduledAt != null) {
        timestamps.add(scheduledAt.millisecondsSinceEpoch);
      }
    }
    return timestamps;
  }

  Future<void> insertPendingEvent(DateTime scheduledAtUtc) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    await _client.from('water_reminder_events').insert({
      'user_id': userId,
      'scheduled_at': scheduledAtUtc.toIso8601String(),
      'fired_at': scheduledAtUtc.toIso8601String(),
      'status': 'pending',
    });
  }

  Future<void> markMissedBefore(DateTime cutoffUtc) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    await _client
        .from('water_reminder_events')
        .update({'status': 'missed'})
        .eq('user_id', userId)
        .eq('status', 'pending')
        .lt('scheduled_at', cutoffUtc.toIso8601String());
  }

  Future<void> markCompletedInWindow({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    final response = await _client
        .from('water_reminder_events')
        .select('id, scheduled_at')
        .eq('user_id', userId)
        .eq('status', 'pending')
        .gte('scheduled_at', startUtc.toIso8601String())
        .lte('scheduled_at', endUtc.toIso8601String())
        .order('scheduled_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) {
      return;
    }

    await _client
        .from('water_reminder_events')
        .update({'status': 'completed'})
        .eq('id', response['id']);
  }

  Future<void> cancelPendingAfter(DateTime cutoffUtc) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    await _client
        .from('water_reminder_events')
        .update({'status': 'cancelled'})
        .eq('user_id', userId)
        .eq('status', 'pending')
        .gt('scheduled_at', cutoffUtc.toIso8601String());
  }

  List<String> _parseTimes(dynamic value) {
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return ['10:30', '13:30', '16:30', '19:30'];
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc();
    }
    return null;
  }
}
