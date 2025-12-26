import 'package:flutter/material.dart';

class ReminderModel {
  const ReminderModel({
    required this.id,
    required this.userId,
    required this.time,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final TimeOfDay time;
  final bool isActive;
  final DateTime createdAt;

  factory ReminderModel.fromMap(Map<String, dynamic> data) {
    try {
      final id = data['id']?.toString() ?? '';
      final userId = data['user_id']?.toString() ?? '';
      final timeRaw = data['reminder_time'];
      final time = _parseTime(timeRaw) ?? const TimeOfDay(hour: 9, minute: 0);
      final isActive = data['is_active'] == true;
      final createdRaw = data['created_at'];
      final createdAt = createdRaw is String
          ? DateTime.tryParse(createdRaw)?.toUtc()
          : createdRaw is DateTime
              ? createdRaw.toUtc()
              : null;
      return ReminderModel(
        id: id,
        userId: userId,
        time: time,
        isActive: isActive,
        createdAt: createdAt ?? DateTime.now().toUtc(),
      );
    } catch (_) {
      return ReminderModel(
        id: '',
        userId: '',
        time: const TimeOfDay(hour: 9, minute: 0),
        isActive: true,
        createdAt: DateTime.now().toUtc(),
      );
    }
  }

  Map<String, dynamic> toInsertMap() {
    try {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return {
        'reminder_time': '$hour:$minute:00',
        'is_active': isActive,
      };
    } catch (_) {
      return {
        'reminder_time': '09:00:00',
        'is_active': true,
      };
    }
  }

  ReminderModel copyWith({
    TimeOfDay? time,
    bool? isActive,
  }) {
    try {
      return ReminderModel(
        id: id,
        userId: userId,
        time: time ?? this.time,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
    } catch (_) {
      return this;
    }
  }

  String formattedTime() {
    try {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return '09:00';
    }
  }

  static TimeOfDay? _parseTime(dynamic value) {
    try {
      if (value is String) {
        final parts = value.split(':');
        if (parts.length >= 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour != null &&
              minute != null &&
              hour >= 0 &&
              hour <= 23 &&
              minute >= 0 &&
              minute <= 59) {
            return TimeOfDay(hour: hour, minute: minute);
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
