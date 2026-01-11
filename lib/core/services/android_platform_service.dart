import 'dart:io';

import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

class AndroidPlatformService {
  static const MethodChannel _channel = MethodChannel('app.device');

  static Future<int?> getSdkInt() async {
    if (!Platform.isAndroid) {
      return null;
    }
    try {
      final value = await _channel.invokeMethod<int>('getSdkInt');
      return value;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getTimeZoneId() async {
    if (!Platform.isAndroid) {
      return null;
    }
    try {
      final value = await _channel.invokeMethod<String>('getTimeZone');
      if (value == null || value.trim().isEmpty) {
        return null;
      }
      return value;
    } catch (_) {
      return null;
    }
  }

  static Future<void> configureLocalTimeZone() async {
    final zoneId = await getTimeZoneId();
    if (zoneId == null) {
      return;
    }
    try {
      tz.setLocalLocation(tz.getLocation(zoneId));
    } catch (_) {}
  }
}
