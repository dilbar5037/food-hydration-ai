import 'package:flutter/material.dart';

class ReminderTimePicker extends StatelessWidget {
  const ReminderTimePicker({
    super.key,
    required this.onPick,
  });

  final Future<void> Function(TimeOfDay) onPick;

  Future<void> _handlePick(BuildContext context) async {
    try {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (picked == null) {
        return;
      }
      await onPick(picked);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    try {
      return OutlinedButton.icon(
        onPressed: () => _handlePick(context),
        icon: const Icon(Icons.add),
        label: const Text('Add reminder'),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
