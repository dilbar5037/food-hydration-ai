import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  LocalNotificationService._internal();

  static final LocalNotificationService _instance =
      LocalNotificationService._internal();

  factory LocalNotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionGranted = false;
  bool _exactAlarmGranted = false;

  Future<bool> initialize() async {
    try {
      if (_initialized) {
        return _permissionGranted;
      }

      tz.initializeTimeZones();
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _notifications.initialize(initSettings);

      if (Platform.isAndroid) {
        final android = _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final notificationGranted =
            await android?.requestNotificationsPermission() ?? false;
        final exactGranted =
            await android?.requestExactAlarmsPermission() ?? false;
        _permissionGranted = notificationGranted;
        _exactAlarmGranted = exactGranted;
      } else {
        _permissionGranted = true;
        _exactAlarmGranted = true;
      }

      _initialized = true;
      return _permissionGranted;
    } catch (e) {
      debugPrint('LocalNotificationService init failed: $e');
      return false;
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required DateTime time,
    required String title,
    required String body,
  }) async {
    try {
      final hasPermission = await initialize();
      if (!hasPermission) {
        return;
      }

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'water_reminders',
          'Water Reminders',
          channelDescription: 'Daily water reminder alerts',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      );

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(time, tz.local),
        details,
        androidScheduleMode: _exactAlarmGranted
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('LocalNotificationService schedule failed: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _notifications.cancel(id);
    } catch (e) {
      debugPrint('LocalNotificationService cancel failed: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
    } catch (e) {
      debugPrint('LocalNotificationService cancelAll failed: $e');
    }
  }
}
