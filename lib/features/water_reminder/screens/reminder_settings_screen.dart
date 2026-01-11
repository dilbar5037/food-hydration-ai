import 'dart:async';

import 'package:flutter/material.dart';

import '../models/reminder_model.dart';
import '../providers/reminder_provider.dart';
import '../widgets/reminder_list_tile.dart';
import '../widgets/reminder_time_picker.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() =>
      _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  late final ReminderProvider _provider;
  Timer? _missedTimer;

  @override
  void initState() {
    super.initState();
    try {
      _provider = ReminderProvider();
      _provider.addListener(_onProviderChanged);
      _load();
      _missedTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _provider.refreshMissed(),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      _missedTimer?.cancel();
      _provider.removeListener(_onProviderChanged);
      _provider.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _onProviderChanged() {
    try {
      if (mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      await _provider.load();
    } catch (_) {}
  }

  Future<void> _handleAdd(TimeOfDay time) async {
    try {
      final hasPermission = await _provider.ensurePermissions();
      if (!hasPermission) {
        _showSnackBar('Notification permission denied');
        return;
      }
      final now = TimeOfDay.fromDateTime(DateTime.now());
      final nowMinutes = now.hour * 60 + now.minute;
      final selectedMinutes = time.hour * 60 + time.minute;
      await _provider.addReminder(time);
      if (selectedMinutes <= nowMinutes) {
        _showSnackBar('Time already passed today; reminder will run tomorrow.');
      }
    } catch (_) {
      _showSnackBar('Failed to add reminder');
    }
  }

  Future<void> _handleToggle(ReminderModel reminder, bool value) async {
    try {
      if (value) {
        final hasPermission = await _provider.ensurePermissions();
        if (!hasPermission) {
          _showSnackBar('Notification permission denied');
          return;
        }
      }
      await _provider.toggleReminder(reminder, value);
    } catch (_) {
      _showSnackBar('Failed to update reminder');
    }
  }

  Future<void> _handleDelete(ReminderModel reminder) async {
    try {
      await _provider.deleteReminder(reminder);
    } catch (_) {
      _showSnackBar('Failed to delete reminder');
    }
  }

  void _showSnackBar(String message) {
    try {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    try {
      final reminders = _provider.reminders;
      final isLoading = _provider.isLoading;
      final missedCount = _provider.missedCount;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Water Reminders'),
          actions: [
            IconButton(
              onPressed: isLoading ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stay hydrated with custom reminders.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Missed reminders'),
                          Text(
                            missedCount.toString(),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ReminderTimePicker(onPick: _handleAdd),
                    const SizedBox(height: 16),
                    if (reminders.isEmpty)
                      const Text('No reminder times yet.')
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: reminders.length,
                          itemBuilder: (context, index) {
                            final reminder = reminders[index];
                            return ReminderListTile(
                              reminder: reminder,
                              onToggle: (value) =>
                                  _handleToggle(reminder, value),
                              onDelete: () => _handleDelete(reminder),
                            );
                          },
                        ),
                      ),
                  ],
                ),
        ),
      );
    } catch (_) {
      return const Scaffold(
        body: Center(child: Text('Unable to load reminders')),
      );
    }
  }
}
