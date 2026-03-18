import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: const Color(0xFF152D4E),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildNotificationSwitch(
            title: 'Bill Reminders',
            subtitle: 'Receive notifications for new bills and payment deadlines.',
            value: true,
            onChanged: (value) {
              // TODO: Implement logic to save this preference
            },
          ),
          const Divider(color: Colors.white24),
          _buildNotificationSwitch(
            title: 'Supply Alerts',
            subtitle: 'Get notified 15 minutes before water supply starts in your area.',
            value: true,
            onChanged: (value) {
              // TODO: Implement logic to save this preference
            },
          ),
          const Divider(color: Colors.white24),
          _buildNotificationSwitch(
            title: 'Announcements',
            subtitle: 'Receive general announcements and maintenance alerts.',
            value: true,
            onChanged: (value) {
              // TODO: Implement logic to save this preference
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.cyanAccent,
      ),
    );
  }
}