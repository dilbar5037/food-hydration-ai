import 'package:flutter/material.dart';

import '../../water_reminder/screens/reminder_settings_screen.dart';

class WaterReminderSettingsScreen extends StatelessWidget {
  const WaterReminderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      return const ReminderSettingsScreen();
    } catch (_) {
      return const Scaffold(
        body: Center(child: Text('Unable to load reminders')),
      );
    }
  }
}
