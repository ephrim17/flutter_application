import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/helpers/prayer_notification_service.dart';
import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/super_admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/favorites_provider.dart';
import 'package:flutter_application/church_app/providers/loading_access_provider.dart';
import 'package:flutter_application/church_app/providers/preflow_theme_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart'
    show selectedChurchProvider;
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/select-church-screen.dart';
import 'package:flutter_application/church_app/services/church_user_repository.dart';
import 'package:flutter_application/church_app/services/notification_service.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/copy_rights_widget.dart';
import 'package:flutter_application/church_app/widgets/praisethelord_card_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:permission_handler/permission_handler.dart';
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
      body: Scrollbar(
        thumbVisibility: true,
        child: ListView(
          padding: const EdgeInsets.all(8),
          children: const [
            _EditProfileSection(),
            _AppearanceSection(),
            _PushNotificationSection(),
            _PrayerReminderSection(),
            _StorageSection(),
            _LogoutSection(),
            SizedBox(height: 12),
            PraiseTheLordCard(),
            CopyrightWidget(),
          ],
        ),
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
      loading: () => ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(
          ref.t('settings.loading_profile', fallback: 'Loading...'),
        ),
      ),
      error: (error, _) => ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(
          ref
              .t('settings.error_loading_profile', fallback: 'Error: {error}')
              .replaceAll('{error}', '$error'),
        ),
      ),
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        return ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(
            ref.t('settings.edit_profile_title', fallback: 'Edit Profile'),
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
        final navigator = Navigator.of(context);
        ref.read(logginAccessLoadingProvider.notifier).state = false;
        ref.read(forcePreflowThemeProvider.notifier).state = true;
        await ChurchLocalStorage().clearChurch();
        await ChurchLocalStorage().clearSubscribedChurchTopic();
        await ref.read(favoritesProvider.notifier).clearAll();
        ref.read(selectedChurchProvider.notifier).state = null;
        await ref.read(superAdminEntryModeProvider.notifier).setMode(
              SuperAdminEntryMode.normal,
            );
        ref.invalidate(currentChurchIdProvider);
        ref.invalidate(appUserProvider);
        ref.invalidate(getCurrentUserProvider);
        navigator.pushAndRemoveUntil(
          PageRouteBuilder(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) => const SelectChurchScreen(),
          ),
          (route) => false,
        );
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

class _PushNotificationSection extends ConsumerStatefulWidget {
  const _PushNotificationSection();

  @override
  ConsumerState<_PushNotificationSection> createState() =>
      _PushNotificationSectionState();
}

class _PushNotificationSectionState
    extends ConsumerState<_PushNotificationSection>
    with WidgetsBindingObserver {
  NotificationSettings? _settings;
  bool _isLoading = true;
  bool _isBusy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ref.t(
          'settings.push_status_unavailable',
          fallback: 'Unable to check notification status right now',
        );
      });
    }
  }

  bool get _isAuthorized {
    final status = _settings?.authorizationStatus;
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  String _subtitleText() {
    if (_errorMessage != null) {
      return _errorMessage!;
    }

    if (_settings == null) {
      return ref.t('common.loading', fallback: 'Loading...');
    }

    switch (_settings!.authorizationStatus) {
      case AuthorizationStatus.authorized:
        return ref.t(
          'settings.push_enabled',
          fallback: 'Enabled and synced for church updates',
        );
      case AuthorizationStatus.provisional:
        return ref.t(
          'settings.push_provisional',
          fallback: 'Enabled with provisional permission',
        );
      case AuthorizationStatus.denied:
        return ref.t(
          'settings.push_blocked',
          fallback: 'Blocked at system level. Open settings to enable.',
        );
      case AuthorizationStatus.notDetermined:
        return ref.t(
          'settings.push_not_determined',
          fallback: 'Not enabled yet',
        );
    }
  }

  Future<void> _handleAction() async {
    if (_isBusy) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.t(
              'settings.push_not_signed_in',
              fallback: 'Sign in to manage push notifications',
            ),
          ),
        ),
      );
      return;
    }

    final churchId = await ref.read(currentChurchIdProvider.future);
    if (!mounted) return;
    if (churchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.t(
              'settings.push_no_church',
              fallback: 'Select a church before enabling notifications',
            ),
          ),
        ),
      );
      return;
    }

    final status = _settings?.authorizationStatus;

    setState(() {
      _isBusy = true;
    });

    try {
      if (status == AuthorizationStatus.denied) {
        await openAppSettings();
      } else {
        await handleNotificationSetup(context: context, ref: ref);
      }
    } finally {
      await _loadStatus();
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionLabel =
        _settings?.authorizationStatus == AuthorizationStatus.denied
            ? ref.t('settings.push_manage', fallback: 'Manage')
            : _isAuthorized
                ? ref.t('settings.push_refresh', fallback: 'Refresh')
                : ref.t('settings.push_enable', fallback: 'Enable');

    return ListTile(
      leading: const Icon(Icons.notifications_outlined),
      title: Text(
        ref.t('settings.push_notifications', fallback: 'Push Notifications'),
      ),
      subtitle: Text(_subtitleText()),
      trailing: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: _isBusy ? null : _handleAction,
              child: _isBusy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(actionLabel),
            ),
    );
  }
}

class _PrayerReminderSection extends ConsumerStatefulWidget {
  const _PrayerReminderSection();

  @override
  ConsumerState<_PrayerReminderSection> createState() =>
      _PrayerReminderSectionState();
}

class _PrayerReminderSectionState
    extends ConsumerState<_PrayerReminderSection> {
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
          final hasOnboardingFlag = prefs.containsKey('onboarding_completed');
          final onboardingCompleted =
              prefs.getBool('onboarding_completed') ?? false;
          await prefs.clear();
          if (hasOnboardingFlag) {
            await prefs.setBool(
              'onboarding_completed',
              onboardingCompleted,
            );
          }

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

  final AppUser user;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;
  late final TextEditingController _addressController;
  bool _isSaving = false;
  bool _isFetchingLocation = false;
  DateTime? _dob;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.user.phone);
    _locationController = TextEditingController(text: widget.user.location);
    _addressController = TextEditingController(text: widget.user.address);
    _dob = widget.user.dob;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String _formatDob(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
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
      fallback:
          'Location permission denied permanently. Enable it from settings.',
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
      if (permission == LocationPermission.denied) {
        throw permissionDeniedMessage;
      }
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
    if (!mounted || churchId == null) return;

    final phone = _phoneController.text.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.t(
              'settings.profile_phone_invalid',
              fallback: 'Enter a valid 10-digit phone number',
            ),
          ),
        ),
      );
      return;
    }
    if (_locationController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.t(
              'settings.profile_address_location_required',
              fallback: 'Address and maps location are required',
            ),
          ),
        ),
      );
      return;
    }
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.t(
              'settings.profile_birthday_required',
              fallback: 'Please select your birthday',
            ),
          ),
        ),
      );
      return;
    }

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
        phone: phone,
        location: _locationController.text,
        address: _addressController.text,
        category: widget.user.category,
        familyId: widget.user.familyId,
        dob: _dob,
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
              ref.t('settings.edit_profile_title', fallback: 'Edit Profile'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _SettingsReviewCard(
              rows: [
                _SettingsReviewRow(
                  ref.t('members.name_label', fallback: 'Name'),
                  widget.user.name,
                ),
                _SettingsReviewRow(
                  ref.t('members.email_label', fallback: 'Email'),
                  widget.user.email,
                ),
                _SettingsReviewRow(
                  ref.t('members.category_label', fallback: 'Category'),
                  widget.user.category,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: ref.t('auth.phone_label', fallback: 'Phone Number'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _dob ?? DateTime(2000),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (pickedDate == null) return;
                setState(() {
                  _dob = pickedDate;
                });
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: ref.t('auth.birthday_label', fallback: 'Birthday'),
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _formatDob(_dob).isEmpty
                      ? ref.t(
                          'auth.birthday_hint',
                          fallback: 'Select your birthday',
                        )
                      : _formatDob(_dob),
                ),
              ),
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
                  fallback:
                      'Use current location or paste your Google Maps link',
                ),
                border: const OutlineInputBorder(),
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
                border: const OutlineInputBorder(),
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

class _SettingsReviewCard extends StatelessWidget {
  const _SettingsReviewCard({required this.rows});

  final List<_SettingsReviewRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: rows
            .where((row) => row.value.trim().isNotEmpty)
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        row.label,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        row.value,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SettingsReviewRow {
  const _SettingsReviewRow(this.label, this.value);

  final String label;
  final String value;
}
