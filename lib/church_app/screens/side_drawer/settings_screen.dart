import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/prayer_notification_service.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/favorites_provider.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/copy_rights_widget.dart';
import 'package:flutter_application/church_app/widgets/praisethelord_card_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: ref.t('settings.title', fallback: 'Settings'),
        ),
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
                    _LogoutSection(),
                  ],
                ),
            ),
          ),

          //Spacer(),
          Padding(
            padding: EdgeInsets.all(15.0),
            child: PraiseTheLordCard(),
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

class _LogoutSection extends ConsumerWidget {
  const _LogoutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.logout),
      title: Text(
        ref.t('drawer.logout', fallback: 'Logout'),
      ),
      onTap: () async {
        Navigator.of(context).pop();
        await FirebaseAuth.instance.signOut();
      },
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
      title: Text(
        ref.t('settings.dark_mode', fallback: 'Dark Mode'),
      ),
      value: themeMode == ThemeMode.dark,
      onChanged: (value) {
        ref.read(themeProvider.notifier).toggle(value);
      },
    );
  }
}

class _PrayerReminderSection extends ConsumerStatefulWidget {
  const _PrayerReminderSection();

  @override
  ConsumerState<_PrayerReminderSection> createState() =>
      _PrayerReminderSectionState();
}

class _PrayerReminderSectionState extends ConsumerState<_PrayerReminderSection> {
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
      try {
        await PrayerNotificationService.instance.scheduleDaily(picked);
        setState(() {
          selectedTime = picked;
          enabled = true;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${ref.t('settings.prayer_schedule_failed', fallback: 'Failed to schedule reminder')}: $e",
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined),
          title: Text(
            ref.t('settings.prayer_reminders', fallback: 'Prayer Reminders'),
          ),
          subtitle: Text(
            enabled && selectedTime != null
                ? "${ref.t('settings.prayer_daily_at_prefix', fallback: 'Daily at')} ${selectedTime!.format(context)}"
                : ref.t(
                    'settings.prayer_reminders_subtitle_off',
                    fallback: 'Enable daily prayer reminder',
                  ),
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
            child: Text(
              ref.t(
                'settings.edit_reminder_time',
                fallback: 'Edit Reminder Time',
              ),
            ),
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
      title: Text(
        ref.t('settings.clear_local_data', fallback: 'Clear All Local Data'),
      ),
      onTap: () async {
        final confirm = await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(
              ref.t('settings.confirm', fallback: 'Confirm'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            content: Text(
              ref.t(
                'settings.clear_confirm_message',
                fallback: 'Are you sure you want to clear all local data?',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  ref.t('settings.cancel', fallback: 'Cancel'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  ref.t('settings.clear', fallback: 'Clear'),
                ),
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
            SnackBar(
              content: Text(
                ref.t(
                  'settings.local_data_cleared',
                  fallback: 'All local data cleared',
                ),
              ),
            ),
          );
        }
      },
    );
  }
}
