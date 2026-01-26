import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'android_platform_service.dart';

class LocalNotificationService {
  LocalNotificationService._internal();

  static final LocalNotificationService _instance =
      LocalNotificationService._internal();

  factory LocalNotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static const String _channelId = 'water_reminders_v2';
  static const String _channelName = 'Water Reminders';
  bool _initialized = false;
  bool _permissionGranted = false;

  Future<bool> initialize() async {
    try {
      if (_initialized) {
        return _permissionGranted;
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

      final sdkInt = await AndroidPlatformService.getSdkInt();
      if (sdkInt != null) {
        debugPrint('Android SDK: $sdkInt');
      }
      if (sdkInt != null) {
        final android = _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final notificationGranted =
            await android?.requestNotificationsPermission();
        _permissionGranted = notificationGranted ?? true;
        if (sdkInt < 33) {
          _permissionGranted = true;
        }
    } else {
      _permissionGranted = true;
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

      if (kDebugMode) {
        debugPrint(
          'LocalNotificationService schedule id=$id now=${DateTime.now()} time=$time tz=${tz.local.name}',
        );
      }
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
        title,
        body,
        tz.TZDateTime.from(time, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('LocalNotificationService schedule failed: $e');
    }
  }

  Future<void> showNotificationNow({
    required int id,
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
          _channelId,
          _channelName,
          channelDescription: 'Daily water reminder alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      await _notifications.show(id, title, body, details);
    } catch (e) {
      debugPrint('LocalNotificationService show failed: $e');
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
