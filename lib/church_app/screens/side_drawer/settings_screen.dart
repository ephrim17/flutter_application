import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/copy_rights_widget.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: Column(
        children: [
          /// 🔹 Scrollable content
          Expanded(
            child: ListView(
              children: const [
                Divider(),
                _ProfileSection(),
                Divider(),
                _AppearanceSection(),
                Divider(),
                _PrayerReminderSection(),
                Divider(),
                _StorageSection(),
                Divider(),
              ],
            ),
          ),

          /// 🔹 Fixed bottom copyright
          const Padding(
            padding: EdgeInsets.all(16),
            child: CopyrightWidget(),
          ),
        ],
      ),
    );
  }
}


class ThemeController {
  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier(ThemeMode.system);

  static void toggle(bool isDark) {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeNotifier,
      builder: (_, mode, __) {
        return SwitchListTile(
          secondary: const Icon(Icons.dark_mode_outlined),
          title: const Text("Dark Mode"),
          value: mode == ThemeMode.dark,
          onChanged: (value) {
            ThemeController.toggle(value);
          },
        );
      },
    );
  }
}


class _ProfileSection extends StatelessWidget {
  const _ProfileSection();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: const Text("Date of Birth"),
      subtitle: const Text("Tap to update"),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(2000),
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
        );

        if (picked != null) {
          // Save to local storage
          // await prefs.setString("dob", picked.toIso8601String());
        }
      },
    );
  }
}





class _PrayerReminderSection extends StatefulWidget {
  const _PrayerReminderSection();

  @override
  State<_PrayerReminderSection> createState() =>
      _PrayerReminderSectionState();
}

class _PrayerReminderSectionState
    extends State<_PrayerReminderSection> {
  bool enabled = false;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_active_outlined),
      title: const Text("Prayer Reminders"),
      subtitle: const Text("Enable local prayer notifications"),
      value: enabled,
      onChanged: (value) {
        setState(() => enabled = value);

        if (value) {
          // Schedule notifications
        } else {
          // Cancel notifications
        }
      },
    );
  }
}



class _StorageSection extends StatelessWidget {
  const _StorageSection();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.delete_outline, color: Colors.red),
      title: const Text("Clear All Local Data"),
      onTap: () async {
        final confirm = await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Confirm"),
            content: const Text(
              "Are you sure you want to clear all local data?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Clear"),
              ),
            ],
          ),
        );

        if (confirm == true) {
          // final prefs = await SharedPreferences.getInstance();
          // await prefs.clear();
        }
      },
    );
  }
}
