import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reminder_model.dart';
import 'notification_service.dart';

class ReminderService {
  ReminderService._internal();

  static final ReminderService _instance = ReminderService._internal();

  factory ReminderService() => _instance;

  final SupabaseClient _client = Supabase.instance.client;
  final WaterReminderNotificationService _notificationService =
      WaterReminderNotificationService();
  DateTime? _initializedDay;
  String? _initializedUserId;

  Future<void> initializeReminders(String userId) async {
    try {
      final today = _startOfDay(DateTime.now());
      if (_initializedDay == today && _initializedUserId == userId) {
        return;
      }

      final hasPermission = await _notificationService.ensurePermissions();
      if (!hasPermission) {
        return;
      }

      final reminders = await fetchUserReminders(userId);
      await _scheduleOrLogForToday(reminders);
      _initializedDay = today;
      _initializedUserId = userId;
    } catch (e) {
      debugPrint('ReminderService initialize failed: $e');
    }
  }

  Future<void> syncMissedRemindersForToday() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return;
      }
      final reminders = await fetchUserReminders(userId);
      final now = DateTime.now();
      for (final reminder in reminders) {
        if (!reminder.isActive) {
          continue;
        }
        final scheduledLocal = _scheduleForToday(reminder.time);
        if (scheduledLocal.isAfter(now)) {
          continue;
        }
        // Allow a short grace window so we don't cancel near-due alarms.
        final grace = scheduledLocal.add(const Duration(minutes: 1));
        if (now.isBefore(grace)) {
          continue;
        }
        await logMissedReminder(
          reminder.id,
          scheduledAt: scheduledLocal.toUtc(),
        );
      }
    } catch (e) {
      debugPrint('ReminderService syncMissed failed: $e');
    }
  }

  Future<bool> ensurePermissions() async {
    try {
      return await _notificationService.ensurePermissions();
    } catch (e) {
      debugPrint('ReminderService permissions failed: $e');
      return false;
    }
  }

  Future<void> cancelRemainingRemindersForToday() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return;
      }
      final reminders = await fetchUserReminders(userId);
      final now = DateTime.now();
      for (final reminder in reminders) {
        if (!reminder.isActive) {
          continue;
        }
        final scheduledLocal = _scheduleForToday(reminder.time);
        if (scheduledLocal.isAfter(now)) {
          await _notificationService.cancelReminder(
            reminder: reminder,
            scheduledLocal: scheduledLocal,
          );
        }
      }
    } catch (e) {
      debugPrint('ReminderService cancelRemaining failed: $e');
    }
  }

  Future<void> logMissedReminder(
    String reminderId, {
    DateTime? scheduledAt,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return;
      }
      final scheduled = (scheduledAt ?? DateTime.now()).toUtc();
      final existing = await _client
          .from('missed_reminders')
          .select('id')
          .eq('user_id', userId)
          .eq('reminder_id', reminderId)
          .eq('scheduled_at', scheduled.toIso8601String())
          .maybeSingle();

      if (existing != null) {
        return;
      }

      await _client.from('missed_reminders').insert({
        'user_id': userId,
        'reminder_id': reminderId,
        'scheduled_at': scheduled.toIso8601String(),
      });
    } catch (e) {
      debugPrint('ReminderService logMissed failed: $e');
    }
  }

  Future<List<ReminderModel>> fetchUserReminders(String userId) async {
    try {
      final response = await _client
          .from('user_reminders')
          .select('id, user_id, reminder_time, is_active, created_at')
          .eq('user_id', userId)
          .order('reminder_time');
      final rows = response as List<dynamic>? ?? [];
      return rows
          .map((row) =>
              ReminderModel.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugPrint('ReminderService fetch failed: $e');
      return [];
    }
  }

  Future<ReminderModel?> addReminder(TimeOfDay time) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return null;
      }
      final reminder = ReminderModel(
        id: '',
        userId: userId,
        time: time,
        isActive: true,
        createdAt: DateTime.now().toUtc(),
      );
      final response = await _client
          .from('user_reminders')
          .insert({
            'user_id': userId,
            ...reminder.toInsertMap(),
          })
          .select()
          .single();
      return ReminderModel.fromMap(
        Map<String, dynamic>.from(response as Map),
      );
    } catch (e) {
      debugPrint('ReminderService add failed: $e');
      return null;
    }
  }

  Future<void> updateReminder(ReminderModel reminder) async {
    try {
      await _client.from('user_reminders').update({
        'reminder_time': '${reminder.formattedTime()}:00',
        'is_active': reminder.isActive,
      }).eq('id', reminder.id);
    } catch (e) {
      debugPrint('ReminderService update failed: $e');
    }
  }

  Future<void> deleteReminder(ReminderModel reminder) async {
    try {
      await _client.from('user_reminders').delete().eq('id', reminder.id);
    } catch (e) {
      debugPrint('ReminderService delete failed: $e');
    }
  }

  Future<int> fetchMissedCount() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return 0;
      }
      final response = await _client
          .from('missed_reminders')
          .select('id')
          .eq('user_id', userId);
      final rows = response as List<dynamic>? ?? [];
      return rows.length;
    } catch (e) {
      debugPrint('ReminderService missed count failed: $e');
      return 0;
    }
  }

  Future<void> scheduleReminderForToday(ReminderModel reminder) async {
    try {
      if (!reminder.isActive) {
        return;
      }
      final hasPermission = await _notificationService.ensurePermissions();
      if (!hasPermission) {
        return;
      }
      final scheduledLocal = _nextOccurrence(reminder.time);
      await _notificationService.scheduleReminder(
        reminder: reminder,
        scheduledLocal: scheduledLocal,
      );
    } catch (e) {
      debugPrint('ReminderService scheduleToday failed: $e');
    }
  }

  Future<void> cancelReminderForToday(ReminderModel reminder) async {
    try {
      final scheduledLocal = _nextOccurrence(reminder.time);
      await _notificationService.cancelReminder(
        reminder: reminder,
        scheduledLocal: scheduledLocal,
      );
    } catch (e) {
      debugPrint('ReminderService cancelToday failed: $e');
    }
  }

  Future<bool> isDailyGoalMet() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return false;
      }
      final totalWater = await _fetchTodayWaterTotal(userId);
      final goal = await _fetchDailyGoalMl(userId);
      return goal > 0 && totalWater >= goal;
    } catch (e) {
      debugPrint('ReminderService goal check failed: $e');
      return false;
    }
  }

  Future<int> _fetchTodayWaterTotal(String userId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _client
          .from('water_logs')
          .select('amount_ml, logged_at')
          .eq('user_id', userId)
          .gte('logged_at', startOfDay.toIso8601String())
          .lt('logged_at', endOfDay.toIso8601String());

      final rows = response as List<dynamic>? ?? [];
      var total = 0;
      for (final row in rows) {
        final amount = row['amount_ml'];
        if (amount is num) {
          total += amount.toInt();
        }
      }
      return total;
    } catch (e) {
      debugPrint('ReminderService water total failed: $e');
      return 0;
    }
  }

  Future<int> _fetchDailyGoalMl(String userId) async {
    try {
      final response = await _client
          .from('settings')
          .select('value_json')
          .eq('key', 'app_defaults')
          .maybeSingle();
      final data = response is Map<String, dynamic> ? response : null;
      final valueJson = data?['value_json'];
      if (valueJson is Map<String, dynamic>) {
        final water = valueJson['default_daily_water_ml'];
        final waterGoal = _parseNumber(water);
        if (waterGoal != null && waterGoal > 0) {
          return waterGoal.round();
        }
      }
    } catch (_) {}

    try {
      final metrics = await _client
          .from('user_metrics')
          .select('weight_kg, activity_level')
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      final weightValue = metrics?['weight_kg'];
      final activityLevel = metrics?['activity_level'] as String?;
      if (weightValue is num && weightValue > 0) {
        final base = weightValue.toDouble() * 35;
        final factor = activityLevel == 'high'
            ? 1.25
            : activityLevel == 'medium'
                ? 1.1
                : 1.0;
        return (base * factor).round();
      }
    } catch (_) {}

    return 2000;
  }

  Future<void> _scheduleOrLogForToday(List<ReminderModel> reminders) async {
    try {
      final now = DateTime.now();
      for (final reminder in reminders) {
        if (!reminder.isActive) {
          continue;
        }
        final scheduledLocal = _scheduleForToday(reminder.time);
        if (scheduledLocal.isAfter(now)) {
          await _notificationService.scheduleReminder(
            reminder: reminder,
            scheduledLocal: scheduledLocal,
          );
        } else {
          await logMissedReminder(
            reminder.id,
            scheduledAt: scheduledLocal.toUtc(),
          );
          final nextLocal = _nextOccurrence(reminder.time);
          if (nextLocal.isAfter(now)) {
            await _notificationService.scheduleReminder(
              reminder: reminder,
              scheduledLocal: nextLocal,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('ReminderService scheduleOrLog failed: $e');
    }
  }

  DateTime _scheduleForToday(TimeOfDay time) {
    try {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, time.hour, time.minute);
    } catch (_) {
      return DateTime.now();
    }
  }

  DateTime _nextOccurrence(TimeOfDay time) {
    try {
      final now = DateTime.now();
      final today =
          DateTime(now.year, now.month, now.day, time.hour, time.minute);
      if (today.isAfter(now)) {
        return today;
      }
      return today.add(const Duration(days: 1));
    } catch (_) {
      return DateTime.now();
    }
  }

  DateTime _startOfDay(DateTime date) {
    try {
      return DateTime(date.year, date.month, date.day);
    } catch (_) {
      return DateTime.now();
    }
  }

  double? _parseNumber(dynamic value) {
    try {
      if (value is num) {
        return value.toDouble();
      }
      if (value != null) {
        return double.tryParse(value.toString());
      }
    } catch (_) {}
    return null;
  }
}
