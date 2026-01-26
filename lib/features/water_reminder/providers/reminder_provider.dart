import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reminder_model.dart';
import '../services/reminder_service.dart';

class ReminderProvider extends ChangeNotifier {
  ReminderProvider({ReminderService? service})
      : _service = service ?? ReminderService();

  final ReminderService _service;

  bool _isLoading = false;
  List<ReminderModel> _reminders = [];
  int _missedCount = 0;

  bool get isLoading => _isLoading;
  List<ReminderModel> get reminders => List.unmodifiable(_reminders);
  int get missedCount => _missedCount;

  Future<void> load() async {
    try {
      _setLoading(true);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _reminders = [];
        _missedCount = 0;
        _setLoading(false);
        return;
      }
      final reminders = await _service.fetchUserReminders(userId);
      _reminders = _applyPastTimeStatus(reminders);
      await _service.syncMissedRemindersForToday();
      _missedCount = await _service.fetchMissedCount();
      _setLoading(false);
    } catch (e) {
      debugPrint('ReminderProvider load failed: $e');
      _setLoading(false);
    }
  }

  Future<bool> ensurePermissions() async {
    try {
      return await _service.ensurePermissions();
    } catch (e) {
      debugPrint('ReminderProvider permissions failed: $e');
      return false;
    }
  }

  Future<void> addReminder(TimeOfDay time) async {
    try {
      final created = await _service.addReminder(time);
      if (created == null) {
        return;
      }
      _reminders = [..._reminders, created]..sort(_compareTimes);
      await _service.scheduleReminderForToday(created);
      notifyListeners();
    } catch (e) {
      debugPrint('ReminderProvider add failed: $e');
    }
  }

  Future<void> toggleReminder(ReminderModel reminder, bool isActive) async {
    try {
      final updated = reminder.copyWith(isActive: isActive);
      await _service.updateReminder(updated);
      _reminders = _reminders
          .map((item) => item.id == reminder.id ? updated : item)
          .toList();
      if (isActive) {
        await _service.scheduleReminderForToday(updated);
      } else {
        await _service.cancelReminderForToday(updated);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('ReminderProvider toggle failed: $e');
    }
  }

  Future<void> deleteReminder(ReminderModel reminder) async {
    try {
      await _service.cancelReminderForToday(reminder);
      await _service.deleteReminder(reminder);
      _reminders = _reminders.where((item) => item.id != reminder.id).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('ReminderProvider delete failed: $e');
    }
  }

  Future<void> refreshMissed() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        return;
      }
      await _service.syncMissedRemindersForToday();
      final reminders = await _service.fetchUserReminders(userId);
      _reminders = _applyPastTimeStatus(reminders);
      _missedCount = await _service.fetchMissedCount();
      notifyListeners();
    } catch (e) {
      debugPrint('ReminderProvider refresh missed failed: $e');
    }
  }

  List<ReminderModel> _applyPastTimeStatus(List<ReminderModel> reminders) {
    final now = TimeOfDay.fromDateTime(DateTime.now());
    final nowMinutes = now.hour * 60 + now.minute;
    return reminders.map((reminder) {
      if (!reminder.isActive) {
        return reminder;
      }
      final reminderMinutes = reminder.time.hour * 60 + reminder.time.minute;
      if (reminderMinutes <= nowMinutes) {
        return reminder.copyWith(isActive: false);
      }
      return reminder;
    }).toList();
  }

  void _setLoading(bool value) {
    try {
      _isLoading = value;
      notifyListeners();
    } catch (_) {}
  }

  int _compareTimes(ReminderModel a, ReminderModel b) {
    try {
      final aMinutes = a.time.hour * 60 + a.time.minute;
      final bMinutes = b.time.hour * 60 + b.time.minute;
      return aMinutes.compareTo(bMinutes);
    } catch (_) {
      return 0;
    }
  }
}
