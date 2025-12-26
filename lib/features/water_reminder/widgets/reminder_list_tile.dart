import 'package:flutter/material.dart';

import '../models/reminder_model.dart';

class ReminderListTile extends StatelessWidget {
  const ReminderListTile({
    super.key,
    required this.reminder,
    required this.onToggle,
    required this.onDelete,
  });

  final ReminderModel reminder;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    try {
      final timeLabel = reminder.formattedTime();
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          title: Text(
            timeLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(reminder.isActive ? 'Active' : 'Paused'),
          leading: const Icon(Icons.water_drop_outlined),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: reminder.isActive,
                onChanged: onToggle,
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete reminder',
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
