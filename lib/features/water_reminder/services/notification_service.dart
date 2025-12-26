import 'package:flutter/foundation.dart';

import '../../../core/services/local_notification_service.dart';
import '../models/reminder_model.dart';

class WaterReminderNotificationService {
  WaterReminderNotificationService({LocalNotificationService? local})
      : _local = local ?? LocalNotificationService();

  final LocalNotificationService _local;

  Future<bool> ensurePermissions() async {
    try {
      return await _local.initialize();
    } catch (e) {
      debugPrint('WaterReminderNotificationService init failed: $e');
      return false;
    }
  }

  Future<void> scheduleReminder({
    required ReminderModel reminder,
    required DateTime scheduledLocal,
  }) async {
    try {
      final id = _notificationId(reminder.id, scheduledLocal);
      await _local.scheduleNotification(
        id: id,
        time: scheduledLocal,
        title: 'Water Reminder',
        body: 'Time to drink some water.',
      );
    } catch (e) {
      debugPrint('WaterReminderNotificationService schedule failed: $e');
    }
  }

  Future<void> cancelReminder({
    required ReminderModel reminder,
    required DateTime scheduledLocal,
  }) async {
    try {
      final id = _notificationId(reminder.id, scheduledLocal);
      await _local.cancelNotification(id);
    } catch (e) {
      debugPrint('WaterReminderNotificationService cancel failed: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _local.cancelAllNotifications();
    } catch (e) {
      debugPrint('WaterReminderNotificationService cancelAll failed: $e');
    }
  }

  int _notificationId(String reminderId, DateTime scheduledLocal) {
    try {
      final dayKey = DateTime(
        scheduledLocal.year,
        scheduledLocal.month,
        scheduledLocal.day,
      ).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
      final hash = reminderId.hashCode;
      return (hash ^ dayKey ^ scheduledLocal.hour ^ scheduledLocal.minute) &
          0x7fffffff;
    } catch (_) {
      return DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    }
  }
}
