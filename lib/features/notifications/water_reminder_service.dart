import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'water_reminder_repository.dart';
import '../../core/services/android_platform_service.dart';

class WaterReminderService {
  WaterReminderService._internal();

  static final WaterReminderService _instance =
      WaterReminderService._internal();

  factory WaterReminderService() => _instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static const String _channelId = 'water_reminders_v2';
  static const String _channelName = 'Water Reminders';
  final WaterReminderRepository _repository = WaterReminderRepository();
  bool _initialized = false;

  Future<void> initAndSchedule() async {
    try {
      await _ensureInitialized();
      await _repository.markMissedBefore(
        DateTime.now().toUtc().subtract(const Duration(minutes: 30)),
      );

      final settings = await _repository.fetchSettings();
      if (!settings.enabled) {
        return;
      }

      final hasPermission = await _hasPermission();
      if (!hasPermission) {
        return;
      }

      final nowLocal = DateTime.now();
      final todayLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
      final startUtc = todayLocal.toUtc();
      final endUtc = todayLocal.add(const Duration(days: 1)).toUtc();
      final existing = await _repository.fetchEventTimestampsForDay(
        startUtc: startUtc,
        endUtc: endUtc,
      );

      for (final time in settings.times) {
        final parsed = _parseTime(time);
        if (parsed == null) {
          continue;
        }
        final scheduledLocal = DateTime(
          nowLocal.year,
          nowLocal.month,
          nowLocal.day,
          parsed.hour,
          parsed.minute,
        );
        if (!scheduledLocal.isAfter(nowLocal)) {
          continue;
        }
        final scheduledUtc = scheduledLocal.toUtc();
        if (existing.contains(scheduledUtc.millisecondsSinceEpoch)) {
          continue;
        }

        await _scheduleNotification(
          id: _notificationId(parsed.hour, parsed.minute),
          scheduledLocal: scheduledLocal,
        );
        await _repository.insertPendingEvent(scheduledUtc);
      }
    } catch (_) {}
  }

  Future<void> onWaterLogged() async {
    try {
      final nowUtc = DateTime.now().toUtc();
      await _repository.markCompletedInWindow(
        startUtc: nowUtc.subtract(const Duration(minutes: 30)),
        endUtc: nowUtc,
      );

      final totalWater = await _fetchTodayWaterTotal();
      final goal = await _fetchDailyGoalMl();
      if (goal > 0 && totalWater >= goal) {
        await cancelRemainingForToday();
      }
    } catch (_) {}
  }

  Future<void> cancelRemainingForToday() async {
    try {
      final settings = await _repository.fetchSettings();
      await cancelByTimes(settings.times);
      await _repository.cancelPendingAfter(DateTime.now().toUtc());
    } catch (_) {}
  }

  Future<void> cancelByTimes(List<String> times) async {
    try {
      for (final time in times) {
        final parsed = _parseTime(time);
        if (parsed == null) {
          continue;
        }
        final id = _notificationId(parsed.hour, parsed.minute);
        await _notifications.cancel(id);
      }
    } catch (_) {}
  }

  Future<bool> _hasPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    tz.initializeTimeZones();
    await AndroidPlatformService.configureLocalTimeZone();
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings);
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Daily water reminder alerts',
        importance: Importance.high,
      ),
    );
    _initialized = true;
  }

  Future<void> _scheduleNotification({
    required int id,
    required DateTime scheduledLocal,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Daily water reminder alerts',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _notifications.zonedSchedule(
      id,
      'Water Reminder',
      'Log some water to stay on track.',
      tz.TZDateTime.from(scheduledLocal, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  int _notificationId(int hour, int minute) {
    return 5000 + (hour * 100) + minute;
  }

  _ParsedTime? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return _ParsedTime(hour: hour, minute: minute);
  }

  Future<int> _fetchTodayWaterTotal() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return 0;
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final response = await client
        .from('water_logs')
        .select('amount_ml, logged_at')
        .eq('user_id', userId)
        .gte('logged_at', startOfDay.toIso8601String())
        .lt('logged_at', endOfDay.toIso8601String());

    final rows = response as List<dynamic>? ?? [];
    var total = 0;
    for (final row in rows) {
      final amount = (row as Map)['amount_ml'];
      if (amount is num) {
        total += amount.toInt();
      }
    }
    return total;
  }

  Future<int> _fetchDailyGoalMl() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return 0;
    }

    try {
      final response = await client
          .from('settings')
          .select('value_json')
          .eq('key', 'app_defaults')
          .maybeSingle();
      final data = response as Map<String, dynamic>?;
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
      final metrics = await client
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

  double? _parseNumber(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value != null) {
      return double.tryParse(value.toString());
    }
    return null;
  }

}

class _ParsedTime {
  const _ParsedTime({required this.hour, required this.minute});

  final int hour;
  final int minute;
}
