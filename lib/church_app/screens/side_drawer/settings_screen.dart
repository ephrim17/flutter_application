import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/prayer_notification_service.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/favorites_provider.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/copy_rights_widget.dart';
import 'package:flutter_application/church_app/widgets/live_it_up_card_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(text: "Settings"),
      ),
      body: Column(
        children: [
          /// 🔹 Scrollable content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView(
                  children: const [
                    _AppearanceSection(),
                    _PrayerReminderSection(),
                    _StorageSection(),
                  ],
                ),
            ),
          ),

          Spacer(),
          Padding(
            padding: EdgeInsets.all(15.0),
            child: AnimatedLiveItUpCard(),
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

final themeProvider = StateNotifierProvider<ThemeController, ThemeMode>(
  (ref) => ThemeController(),
);

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system);

  void toggle(bool isDark) {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  void setSystem() {
    state = ThemeMode.system;
  }
}

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return SwitchListTile(
      secondary: const Icon(Icons.dark_mode_outlined),
      title: const Text("Dark Mode"),
      value: themeMode == ThemeMode.dark,
      onChanged: (value) {
        ref.read(themeProvider.notifier).toggle(value);
      },
    );
  }
}

class _PrayerReminderSection extends StatefulWidget {
  const _PrayerReminderSection();

  @override
  State<_PrayerReminderSection> createState() => _PrayerReminderSectionState();
}

class _PrayerReminderSectionState extends State<_PrayerReminderSection> {
  bool enabled = false;
  TimeOfDay? selectedTime;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final service = PrayerNotificationService.instance;
    final isOn = await service.isEnabled();
    final time = await service.getSavedTime();

    setState(() {
      enabled = isOn;
      selectedTime = time;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      selectedTime = picked;
      await PrayerNotificationService.instance.scheduleDaily(picked);
      setState(() => enabled = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text("Prayer Reminders"),
          subtitle: Text(
            enabled && selectedTime != null
                ? "Daily at ${selectedTime!.format(context)}"
                : "Enable daily prayer reminder",
          ),
          value: enabled,
          onChanged: (value) async {
            final service = PrayerNotificationService.instance;

            if (value) {
              final granted = await service.requestPermissions(context);

              if (!granted) return;

              await _pickTime();
            } else {
              await service.cancel();
              setState(() {
                enabled = false;
                selectedTime = null;
              });
            }
          },
        ),
        if (enabled)
          TextButton(
            onPressed: _pickTime,
            child: const Text("Edit Reminder Time"),
          ),
      ],
    );
  }
}

class _StorageSection extends ConsumerWidget {
  const _StorageSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.delete_outline, color: Colors.red),
      title: const Text("Clear All Local Data"),
      onTap: () async {
        final confirm = await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text("Confirm", style: Theme.of(context).textTheme.bodyMedium,),
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
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();

          // 🔥 Clear favorites provider
          await ref.read(favoritesProvider.notifier).clearAll();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("All local data cleared"),
            ),
          );
        }
      },
    );
  }
}
