import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_application/church_app/helpers/prayer_notification_service.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/favorites_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/services/church_user_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/copy_rights_widget.dart';
import 'package:flutter_application/church_app/widgets/praisethelord_card_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
                    _EditProfileSection(),
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

class _EditProfileSection extends ConsumerWidget {
  const _EditProfileSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);

    return userAsync.when(
      loading: () => const ListTile(
        leading: Icon(Icons.person_outline),
        title: Text('Loading...'),
      ),
      error: (error, _) => ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text('Error: $error'),
      ),
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        return ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(
            ref.t('settings.edit_profile', fallback: 'Edit Profile'),
          ),
          subtitle: Text(
            user.address.isNotEmpty ? user.address : user.location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _EditProfileSheet(user: user),
          ),
        );
      },
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
          if (!context.mounted) return;

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

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.user});

  final dynamic user;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _locationController;
  late final TextEditingController _addressController;
  bool _isSaving = false;
  bool _isFetchingLocation = false;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(text: widget.user.location);
    _addressController = TextEditingController(text: widget.user.address);
  }

  @override
  void dispose() {
    _locationController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fillCurrentLocation() async {
    final serviceDisabledMessage = ref.t(
      'auth.location_service_disabled',
      fallback: 'Location services are disabled',
    );
    final permissionDeniedMessage = ref.t(
      'auth.location_permission_denied',
      fallback: 'Location permission denied',
    );
    final permissionDeniedForeverMessage = ref.t(
      'auth.location_permission_denied_forever',
      fallback: 'Location permission denied permanently. Enable it from settings.',
    );
    final fetchFailedMessage = ref.t(
      'auth.location_fetch_failed',
      fallback: 'Unable to fetch current location',
    );

    setState(() {
      _isFetchingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw serviceDisabledMessage;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) throw permissionDeniedMessage;
      if (permission == LocationPermission.deniedForever) {
        throw permissionDeniedForeverMessage;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _locationController.text =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is String ? error : fetchFailedMessage),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    if (firebaseUser == null) return;

    final churchId = await ref.read(currentChurchIdProvider.future);
    if (churchId == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final repo = ChurchUsersRepository(
        firestore: ref.read(firestoreProvider),
        churchId: churchId,
      );

      await repo.updateProfile(
        uid: firebaseUser.uid,
        location: _locationController.text,
        address: _addressController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.t('settings.profile_updated', fallback: 'Profile updated'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.t('settings.edit_profile', fallback: 'Edit Profile'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: ref.t(
                  'auth.location_label',
                  fallback: 'Google Maps Location',
                ),
                helperText: ref.t(
                  'auth.location_helper',
                  fallback: 'Use current location or paste your Google Maps link',
                ),
                suffixIcon: _isFetchingLocation
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        onPressed: _fillCurrentLocation,
                        icon: const Icon(Icons.my_location),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isFetchingLocation ? null : _fillCurrentLocation,
                icon: const Icon(Icons.location_searching_outlined),
                label: Text(
                  ref.t(
                    'auth.location_use_current',
                    fallback: 'Use Current Location',
                  ),
                ),
              ),
            ),
            TextField(
              controller: _addressController,
              keyboardType: TextInputType.streetAddress,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: ref.t('auth.address_label', fallback: 'Address'),
                helperText: ref.t(
                  'auth.address_helper',
                  fallback: 'Enter your address manually',
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(ref.t('feed.update_action', fallback: 'Update')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
