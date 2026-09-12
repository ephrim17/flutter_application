import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/self_signup_membership_helper.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/models/user_identity_model.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/helpers/prayer_notification_service.dart';
import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/super_admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/favorites_provider.dart';
import 'package:flutter_application/church_app/providers/loading_access_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart'
    show selectedChurchProvider, churchesProvider, churchByIdProvider;
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/entry/auth_choice_screen.dart';
import 'package:flutter_application/church_app/screens/select-church-screen.dart';
import 'package:flutter_application/church_app/services/side_drawer/members_repository.dart';
import 'package:flutter_application/church_app/services/user_identity_repository.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_errors.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:flutter_application/church_app/services/notification_service.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/app_profile_avatar.dart';
import 'package:flutter_application/church_app/widgets/church_profile_editor_sheet.dart';
import 'package:flutter_application/church_app/widgets/copy_rights_widget.dart';
import 'package:flutter_application/church_app/widgets/praisethelord_card_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:image_picker/image_picker.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userIdentityProvider);
    final selectedChurch = ref.watch(selectedChurchProvider);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: ref.t('settings.title'),
        ),
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _SettingsHeroCard(
              userAsync: userAsync,
              churchName: selectedChurch?.name ?? '',
            ),
            const SizedBox(height: sectionSpacing),
            _SettingsSectionLabel(
              title: ref.t('settings.profile_title'),
              subtitle: ref.t('settings.profile_subtitle'),
            ),
            const SizedBox(height: 10),
            const _SettingsGroupCard(
              children: [
                _EditProfileSection(),
              ],
            ),
            const SizedBox(height: sectionSpacing),
            _SettingsSectionLabel(
              title: ref.t('settings.preferences_title'),
              subtitle: ref.t('settings.preferences_subtitle'),
            ),
            const SizedBox(height: 10),
            const _SettingsGroupCard(
              children: [
                _AppearanceSection(),
                _PushNotificationSection(),
                _PrayerReminderSection(),
              ],
            ),
            const SizedBox(height: sectionSpacing),
            _SettingsSectionLabel(
              title: ref.t('settings.feedback_title'),
              subtitle: ref.t('settings.feedback_subtitle'),
            ),
            const SizedBox(height: 10),
            const _SettingsGroupCard(
              children: [
                _FeedbackSection(),
              ],
            ),
            const _ChurchProfileGroup(),
            const SizedBox(height: sectionSpacing),
            _SettingsSectionLabel(
              title: ref.t('settings.account_title'),
              subtitle: ref.t('settings.account_subtitle'),
            ),
            const SizedBox(height: 10),
            const _SettingsGroupCard(
              children: [
                _StorageSection(),
                _LeaveChurchSection(),
                _RegisterAnotherChurchSection(),
                _LogoutSection(),
                _DeleteAccountSection(),
              ],
            ),
            const SizedBox(height: sectionSpacing),
            const PraiseTheLordCard(),
            const SizedBox(height: 10),
            const CopyrightWidget(),
          ],
        ),
      ),
    );
  }
}

/// A pared-down Settings screen for someone who hasn't entered a church yet
/// (`SelectChurchScreen`'s account icon) — no church to scope
/// leave-church/register-another-church/church-profile-editor sections to,
/// so only the person-level sections are shown: edit profile, preferences,
/// feedback, and account (clear local data, logout, delete account).
class GuestSettingsScreen extends ConsumerWidget {
  const GuestSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userIdentityProvider);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(text: ref.t('settings.title')),
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _SettingsHeroCard(userAsync: userAsync, churchName: ''),
            const SizedBox(height: sectionSpacing),
            _SettingsSectionLabel(
              title: ref.t('settings.profile_title'),
              subtitle: ref.t('settings.profile_subtitle'),
            ),
            const SizedBox(height: 10),
            const _SettingsGroupCard(
              children: [
                _EditProfileSection(),
              ],
            ),
            const SizedBox(height: sectionSpacing),
            _SettingsSectionLabel(
              title: ref.t('settings.preferences_title'),
              subtitle: ref.t('settings.preferences_subtitle'),
            ),
            const SizedBox(height: 10),
            const _SettingsGroupCard(
              children: [
                _AppearanceSection(),
                _PushNotificationSection(),
                _PrayerReminderSection(),
              ],
            ),
            const SizedBox(height: sectionSpacing),
            _SettingsSectionLabel(
              title: ref.t('settings.feedback_title'),
              subtitle: ref.t('settings.feedback_subtitle'),
            ),
            const SizedBox(height: 10),
            const _SettingsGroupCard(
              children: [
                _FeedbackSection(),
              ],
            ),
            const SizedBox(height: sectionSpacing),
            _SettingsSectionLabel(
              title: ref.t('settings.account_title'),
              subtitle: ref.t('settings.account_subtitle'),
            ),
            const SizedBox(height: 10),
            const _SettingsGroupCard(
              children: [
                _StorageSection(),
                _LogoutSection(),
                _DeleteAccountSection(),
              ],
            ),
            const SizedBox(height: sectionSpacing),
            const PraiseTheLordCard(),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeroCard extends StatelessWidget {
  const _SettingsHeroCard({
    required this.userAsync,
    required this.churchName,
  });

  final AsyncValue<UserIdentity?> userAsync;
  final String churchName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: welcomeBackCardDecoration(context),
      child: userAsync.when(
        loading: () => const SizedBox(
          height: 112,
          child: Center(child: AppLoadingIndicator()),
        ),
        error: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('ui.settings.settings'),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: onPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.t(
                  'ui.settings.manage_your_app_preferences_and_account_details'),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: onPrimary.withValues(alpha: 0.88),
              ),
            ),
          ],
        ),
        data: (user) {
          final userName = user?.name.trim().isNotEmpty == true
              ? user!.name.trim()
              : 'Church Tree';
          final email = user?.email.trim() ?? '';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppProfileAvatar(
                    name: userName,
                    imageUrl: user?.profilePhotoUrl,
                    radius: 32,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    foregroundColor: onPrimary,
                    borderColor: Colors.white.withValues(alpha: 0.18),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            color: onPrimary,
                          ),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            email,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: onPrimary.withValues(alpha: 0.88),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (churchName.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                _SettingsHeroChip(
                  icon: Icons.account_balance_outlined,
                  label: churchName.trim(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SettingsHeroChip extends StatelessWidget {
  const _SettingsHeroChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: carouselBoxDecoration(context),
      child: Column(
        children: children
            .asMap()
            .entries
            .expand(
              (entry) => [
                entry.value,
                if (entry.key != children.length - 1)
                  Divider(
                    height: 1,
                    indent: 68,
                    endIndent: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.45),
                  ),
              ],
            )
            .toList(growable: false),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: effectiveIconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.68),
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.42),
                ),
          ],
        ),
      ),
    );
  }
}

/// Opens the same Edit Profile sheet Settings uses, for reuse from other
/// entry points (the account-completion icon on the church picker, and the
/// "Setup Profile" prompt on the home welcome card).
Future<void> showEditProfileSheet(BuildContext context, UserIdentity user) {
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => EditProfileSheet(user: user),
  );
}

class _EditProfileSection extends ConsumerWidget {
  const _EditProfileSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userIdentityProvider);

    return userAsync.when(
      loading: () => _SettingsTile(
        icon: Icons.person_outline,
        title: ref.t('settings.loading_profile'),
        subtitle: ref.t('settings.loading_profile_subtitle'),
        trailing: const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, _) => _SettingsTile(
        icon: Icons.person_outline,
        title: ref.t('settings.edit_profile_title'),
        subtitle: ref
            .t('settings.error_loading_profile', fallback: 'Error: {error}')
            .replaceAll('{error}', '$error'),
      ),
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        return _SettingsTile(
          icon: Icons.person_outline,
          title: ref.t('settings.edit_profile_title'),
          subtitle: ref.t('settings.edit_profile_subtitle'),
          onTap: () => showEditProfileSheet(context, user),
        );
      },
    );
  }
}

/// Church-admin-only section for editing the selected church's public
/// profile (pastor, contact details, social links) — this used to live on
/// the Discover tab (`_ChurchDiscoveryEditorSheet`) but moved here once
/// that tab was removed, since only Settings is guaranteed to still be
/// reachable for every church admin. Hidden entirely for non-admins or
/// when no church is selected.
class _ChurchProfileGroup extends ConsumerWidget {
  const _ChurchProfileGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final selectedChurch = ref.watch(selectedChurchProvider);
    if (!isAdmin || selectedChurch == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsSectionLabel(
          title: ref.t('settings.church_title'),
          subtitle: ref.t('settings.church_subtitle'),
        ),
        const SizedBox(height: 10),
        _SettingsGroupCard(
          children: [
            _SettingsTile(
              icon: Icons.account_balance_outlined,
              title: ref.t('settings.church_profile_title'),
              subtitle: ref.t('settings.church_profile_subtitle'),
              onTap: () => showAppModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ChurchProfileEditorSheet(
                  church: selectedChurch,
                  onSaved: () async {
                    ref.invalidate(churchByIdProvider(selectedChurch.id));
                    ref.invalidate(churchesProvider);
                    ref.invalidate(userChurchesProvider);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ref.t('settings.church_profile_updated'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Leaves the currently selected church only (§6 Phase 7) — identity,
/// favorites, reading plans, Church Tree progress and streak all survive,
/// since they live on `users/{uid}`, never on the membership. Hidden when
/// no church is selected (e.g. from the guest shell).
class _LeaveChurchSection extends ConsumerWidget {
  const _LeaveChurchSection();

  Future<void> _confirmAndLeave(
    BuildContext context,
    WidgetRef ref,
    String churchId,
    String churchName,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ref.t('settings.leave_church_title')),
        content: Text(
          ref.t(
            'settings.leave_church_message',
            parameters: {'church': churchName},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(ref.t('settings.cancel')),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(ref.t('settings.leave_church_confirm')),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(authRepositoryProvider).leaveChurch(churchId: churchId);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      await ChurchLocalStorage().clearChurch();
      await ChurchLocalStorage().clearSubscribedChurchTopic();
      ref.read(selectedChurchProvider.notifier).state = null;
      ref.invalidate(currentChurchIdProvider);
      ref.invalidate(myMembershipsProvider);
      ref.invalidate(userChurchesProvider);
      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, __, ___) => const SelectChurchScreen(),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFirebaseAuthError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChurch = ref.watch(selectedChurchProvider);
    if (selectedChurch == null) return const SizedBox.shrink();

    return _SettingsTile(
      icon: Icons.exit_to_app_rounded,
      iconColor: Colors.red,
      title: ref.t('settings.leave_church_title'),
      subtitle: ref.t(
        'settings.leave_church_subtitle',
        parameters: {'church': selectedChurch.name},
      ),
      onTap: () => _confirmAndLeave(
        context,
        ref,
        selectedChurch.id,
        selectedChurch.name,
      ),
    );
  }
}

/// Opens the full church directory (`SelectChurchScreen` — Your churches,
/// Other churches, and the all-churches feed action) so someone can request
/// access to a church they're not part of yet. `SelectChurchScreen` is
/// always a root-level screen (same as its entry-gate use) — no back button
/// out of it, only actually picking/entering a church — so this clears the
/// whole stack rather than pushing on top of it. Quick switching between
/// churches already joined is separate: tap the church name in
/// `ChurchTabScreen`'s app bar for that (`ChurchQuickSwitcherSheet`).
class _RegisterAnotherChurchSection extends StatelessWidget {
  const _RegisterAnotherChurchSection();

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: Icons.travel_explore_outlined,
      title: context.t('settings.register_another_church_title'),
      subtitle: context.t('settings.register_another_church_subtitle'),
      onTap: () => Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const SelectChurchScreen(initialTabIndex: 1),
        ),
        (route) => false,
      ),
    );
  }
}

/// Fully signs the person out of Firebase Auth — separate from switching
/// church, which now happens by tapping the church name in `ChurchTabScreen`'s
/// app bar (opens `ChurchQuickSwitcherSheet`) and keeps the session, just
/// clearing the locally selected church.
class _LogoutSection extends ConsumerWidget {
  const _LogoutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsTile(
      icon: Icons.logout_rounded,
      iconColor: Colors.redAccent,
      title: ref.t('drawer.logout'),
      subtitle: ref.t('settings.logout_subtitle'),
      onTap: () async {
        final navigator = Navigator.of(context);
        ref.read(logginAccessLoadingProvider.notifier).state = false;
        await ChurchLocalStorage().clearChurch();
        await ChurchLocalStorage().clearSubscribedChurchTopic();
        await ref.read(favoritesProvider.notifier).clearAll();
        ref.read(selectedChurchProvider.notifier).state = null;
        await ref.read(superAdminEntryModeProvider.notifier).setMode(
              SuperAdminEntryMode.normal,
            );
        ref.invalidate(currentChurchIdProvider);
        ref.invalidate(churchesProvider);
        ref.invalidate(userChurchesProvider);
        ref.invalidate(userIdentityProvider);
        ref.invalidate(currentMembershipProvider);
        await FirebaseAuth.instance.signOut();
        navigator.pushAndRemoveUntil(
          PageRouteBuilder(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) => const AuthChoiceScreen(),
          ),
          (route) => false,
        );
      },
    );
  }
}

/// Deletes the person's account entirely, across every church (§6 Phase 7)
/// — the account-deletion UI referenced in
/// `KT Files/testing/android-release-readiness-2026-08-13.md`'s known
/// blockers list.
class _DeleteAccountSection extends ConsumerWidget {
  const _DeleteAccountSection();

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountPasswordDialog(),
    );
    if (password == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(authRepositoryProvider).deleteAccount(password: password);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const AuthChoiceScreen(),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFirebaseAuthError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsTile(
      icon: Icons.person_remove_outlined,
      iconColor: Colors.red,
      title: ref.t('settings.delete_account_title'),
      subtitle: ref.t('settings.delete_account_subtitle'),
      onTap: () => _confirmAndDelete(context, ref),
    );
  }
}

/// Its own StatefulWidget so the password controller is disposed when this
/// dialog's Element is actually torn down (after the dialog's exit
/// transition finishes) — disposing it right after `showDialog`'s Future
/// resolves (i.e. right as `Navigator.pop` fires, but before the fade-out
/// animation that follows it finishes) used the controller after dispose,
/// since the TextFormField is still on screen and rebuilding mid-transition.
class _DeleteAccountPasswordDialog extends ConsumerStatefulWidget {
  const _DeleteAccountPasswordDialog();

  @override
  ConsumerState<_DeleteAccountPasswordDialog> createState() =>
      _DeleteAccountPasswordDialogState();
}

class _DeleteAccountPasswordDialogState
    extends ConsumerState<_DeleteAccountPasswordDialog> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(ref.t('settings.delete_account_title')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ref.t('settings.delete_account_message')),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: ref.t('settings.delete_account_password_label'),
              ),
              validator: (value) => (value == null || value.isEmpty)
                  ? ref.t('settings.delete_account_password_required')
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(ref.t('settings.cancel')),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.pop(context, _passwordController.text);
          },
          child: Text(ref.t('settings.delete_account_confirm')),
        ),
      ],
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
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final isDarkModeEnabled = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && systemBrightness == Brightness.dark);

    return _SettingsTile(
      icon: Icons.dark_mode_outlined,
      title: ref.t('settings.dark_mode'),
      subtitle: ref.t('settings.dark_mode_subtitle'),
      trailing: Switch(
        value: isDarkModeEnabled,
        onChanged: (value) {
          ref.read(themeProvider.notifier).toggle(value);
        },
      ),
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
        _errorMessage = ref.t('settings.push_status_unavailable');
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
      return ref.t('common.loading');
    }

    switch (_settings!.authorizationStatus) {
      case AuthorizationStatus.authorized:
        return ref.t('settings.push_enabled');
      case AuthorizationStatus.provisional:
        return ref.t('settings.push_provisional');
      case AuthorizationStatus.denied:
        return ref.t('settings.push_blocked');
      case AuthorizationStatus.notDetermined:
        return ref.t('settings.push_not_determined');
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
            ref.t('settings.push_not_signed_in'),
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
            ref.t('settings.push_no_church'),
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
        await handleNotificationSetup(
          context: context,
          container: ProviderScope.containerOf(context, listen: false),
        );
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
            ? ref.t('settings.push_manage')
            : _isAuthorized
                ? ref.t('settings.push_refresh')
                : ref.t('settings.push_enable');

    return _SettingsTile(
      icon: Icons.notifications_outlined,
      title: ref.t('settings.push_notifications'),
      subtitle: _subtitleText(),
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
              "${ref.t('settings.prayer_schedule_failed')}: $e",
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
        _SettingsTile(
          icon: Icons.notifications_active_outlined,
          title: ref.t('settings.prayer_reminders'),
          subtitle: enabled && selectedTime != null
              ? "${ref.t('settings.prayer_daily_at_prefix')} ${selectedTime!.format(context)}"
              : ref.t('settings.prayer_reminders_subtitle_off'),
          trailing: Switch(
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
        ),
        if (enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(74, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule_outlined),
                label: Text(
                  ref.t('settings.edit_reminder_time'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FeedbackSection extends ConsumerWidget {
  const _FeedbackSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsTile(
      icon: Icons.favorite_rounded,
      iconColor: Colors.redAccent,
      title: ref.t('settings.feedback_tile_title'),
      subtitle: ref.t('settings.feedback_tile_subtitle'),
      onTap: () => showAppModalBottomSheet<void>(
        context: context,
        heightFactor: 0.72,
        builder: (_) => const _FeedbackSheet(),
      ),
    );
  }
}

class _FeedbackSheet extends ConsumerStatefulWidget {
  const _FeedbackSheet();

  @override
  ConsumerState<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<_FeedbackSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final churchId = await ref.read(currentChurchIdProvider.future);
      final identity = ref.read(userIdentityProvider).asData?.value;
      final membership = ref.read(currentMembershipProvider).asData?.value;
      final selectedChurch = ref.read(selectedChurchProvider);
      final notificationSettings =
          await FirebaseMessaging.instance.getNotificationSettings();
      final feedback = {
        'message': message,
        'status': 'new',
        'source': 'settings',
        'churchId': churchId,
        'churchName': selectedChurch?.name,
        'userId': firebaseUser?.uid ?? identity?.uid,
        'userName': identity?.name,
        'userEmail': firebaseUser?.email ?? identity?.email,
        'userPhone': identity?.phone,
        'userRole': membership?.role,
        'userApproved': membership?.approved,
        'submittedBy': _feedbackSubmittedBy(
          firebaseUser: firebaseUser,
          identity: identity,
          membership: membership,
        ),
        'identitySnapshot': _feedbackIdentitySnapshot(identity),
        'membershipSnapshot': _feedbackMembershipSnapshot(membership),
        'firebaseAuthSnapshot': _feedbackAuthSnapshot(firebaseUser),
        'churchSnapshot': _feedbackChurchSnapshot(selectedChurch),
        'appSnapshot': {
          'platform': defaultTargetPlatform.name,
          'projectId': Firebase.app().options.projectId,
          'notificationAuthorizationStatus':
              notificationSettings.authorizationStatus.name,
          'notificationAlert': notificationSettings.alert.name,
          'notificationBadge': notificationSettings.badge.name,
          'notificationSound': notificationSettings.sound.name,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final firestore = ref.read(firestoreProvider);
      await FirestorePaths.globalFeedbackCollection(firestore).add(feedback);

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final snackMessage = ref.t('settings.feedback_sent');
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(snackMessage)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.t('settings.feedback_failed'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSend = _controller.text.trim().isNotEmpty && !_isSending;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        28,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Container(
          decoration: carouselBoxDecoration(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.favorite_rounded,
                color: Colors.redAccent,
                size: 76,
              ),
              const SizedBox(height: 28),
              Text(
                ref.t('settings.feedback_sheet_title'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                ref.t('settings.feedback_sheet_subtitle'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 30),
              AppTextField(
                controller: _controller,
                minLines: 5,
                maxLines: 7,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: ref.t('settings.feedback_hint'),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton(
                  onPressed: canSend ? _send : null,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    disabledBackgroundColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.34),
                    disabledForegroundColor:
                        theme.colorScheme.surface.withValues(alpha: 0.92),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          ref.t('common.send'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: canSend
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.surface
                                    .withValues(alpha: 0.92),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed:
                    _isSending ? null : () => Navigator.of(context).pop(),
                child: Text(
                  ref.t('settings.not_now'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Map<String, dynamic> _feedbackSubmittedBy({
  required User? firebaseUser,
  required UserIdentity? identity,
  required ChurchMembership? membership,
}) {
  return {
    'uid': firebaseUser?.uid ?? identity?.uid,
    'name': identity?.name,
    'email': firebaseUser?.email ?? identity?.email,
    'phone': identity?.phone,
    'role': membership?.role,
    'approved': membership?.approved,
  };
}

Map<String, dynamic>? _feedbackIdentitySnapshot(UserIdentity? user) {
  if (user == null) return null;

  return {
    'uid': user.uid,
    'name': user.name,
    'profilePhotoUrl': user.profilePhotoUrl,
    'email': user.email,
    'phone': user.phone,
    'location': user.location,
    'address': user.address,
    'gender': user.gender,
    'maritalStatus': user.maritalStatus,
    'weddingDay': _feedbackTimestamp(user.weddingDay),
    'educationalQualification': user.educationalQualification,
    'talentsAndGifts': user.talentsAndGifts,
    'dob': _feedbackTimestamp(user.dob),
    'createdAt': _feedbackTimestamp(user.createdAt),
    'dayStreak': user.dayStreak,
    'lastStreakRecordedAt': _feedbackTimestamp(user.lastStreakRecordedAt),
    'profileComplete': user.profileComplete,
  };
}

Map<String, dynamic>? _feedbackMembershipSnapshot(ChurchMembership? member) {
  if (member == null) return null;

  return {
    'docId': member.docId,
    'churchId': member.churchId,
    'linkedUid': member.linkedUid,
    'category': member.category,
    'familyId': member.familyId,
    'financialStabilityRating': member.financialStabilityRating,
    'financialSupportRequired': member.financialSupportRequired,
    'churchGroupIds': member.churchGroupIds,
    'role': member.role,
    'joinedAt': _feedbackTimestamp(member.joinedAt),
    'approved': member.approved,
    'solemnizedBaptism': member.solemnizedBaptism,
    'baptismDate': _feedbackTimestamp(member.baptismDate),
    'baptismCertificateNumber': member.baptismCertificateNumber,
    'baptismChurchName': member.baptismChurchName,
    'baptismPastorName': member.baptismPastorName,
    'marriageSolemnizationChurchType': member.marriageSolemnizationChurchType,
    'marriageSolemnizationChurchName': member.marriageSolemnizationChurchName,
    'membershipCurrentStatus': member.membershipCurrentStatus,
    'membershipNotes': member.membershipNotes,
    'additionalNotes': member.additionalNotes,
  };
}

Map<String, dynamic>? _feedbackAuthSnapshot(User? user) {
  if (user == null) return null;

  return {
    'uid': user.uid,
    'email': user.email,
    'displayName': user.displayName,
    'phoneNumber': user.phoneNumber,
    'photoURL': user.photoURL,
    'emailVerified': user.emailVerified,
    'isAnonymous': user.isAnonymous,
    'providerIds': user.providerData.map((info) => info.providerId).toList(),
    'creationTime': _feedbackTimestamp(user.metadata.creationTime),
    'lastSignInTime': _feedbackTimestamp(user.metadata.lastSignInTime),
  };
}

Map<String, dynamic>? _feedbackChurchSnapshot(Church? church) {
  if (church == null) return null;

  return {
    'id': church.id,
    'name': church.name,
    'address': church.address,
    'contact': church.contact,
    'email': church.email,
    'pastorName': church.pastorName,
    'enabled': church.enabled,
    'registrationSource': church.registrationSource,
  };
}

Timestamp? _feedbackTimestamp(DateTime? value) {
  return value == null ? null : Timestamp.fromDate(value);
}

class _StorageSection extends ConsumerWidget {
  const _StorageSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsTile(
      icon: Icons.delete_outline,
      iconColor: Colors.red,
      title: ref.t('settings.clear_local_data'),
      subtitle: ref.t('settings.clear_local_data_subtitle'),
      onTap: () async {
        final confirm = await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(
              ref.t('settings.confirm'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            content: Text(
              ref.t('settings.clear_confirm_message'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  ref.t('settings.cancel'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  ref.t('settings.clear'),
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
                ref.t('settings.local_data_cleared'),
              ),
            ),
          );
        }
      },
    );
  }
}

class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key, required this.user});

  final UserIdentity user;

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;
  late final TextEditingController _addressController;
  late final TextEditingController _educationalQualificationController;
  late final TextEditingController _talentsAndGiftsController;
  late final TextEditingController _familyNameController;
  bool _isSaving = false;
  bool _isFetchingLocation = false;
  DateTime? _dob;
  String _maritalStatus = '';
  DateTime? _weddingDay;
  PickedImageData? _profilePhoto;
  bool _removeProfilePhoto = false;

  // Family ID is per-church-membership data (churches/{churchId}/members/
  // {uid}.familyId), not part of the global identity doc this sheet
  // otherwise edits — §9.2/§9.3. Only meaningful (and only shown) when
  // opened from inside a church, since there's no membership to attach it
  // to otherwise (e.g. the account icon on the church picker, before
  // entering any church).
  bool _useExistingFamilyId = false;
  String? _selectedExistingFamilyId;
  bool _familyFieldsPrefilled = false;
  String? _familyIdsFutureChurchId;
  Future<List<String>>? _familyIdsFuture;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.user.phone);
    _locationController = TextEditingController(text: widget.user.location);
    _addressController = TextEditingController(text: widget.user.address);
    _educationalQualificationController =
        TextEditingController(text: widget.user.educationalQualification);
    _talentsAndGiftsController =
        TextEditingController(text: widget.user.talentsAndGifts.join(', '));
    _familyNameController = TextEditingController();
    _dob = widget.user.dob;
    _maritalStatus = widget.user.maritalStatus;
    _weddingDay = widget.user.weddingDay;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _educationalQualificationController.dispose();
    _talentsAndGiftsController.dispose();
    _familyNameController.dispose();
    super.dispose();
  }

  String _category() =>
      _maritalStatus.trim().toLowerCase() == 'married' ? 'family' : 'individual';

  String _normalizeFamilySeed(String value, String churchId) =>
      normalizeMembershipSeed(value, churchId);

  String _formatFamilyOptionLabel(String familyId, String churchId) {
    final normalized = familyId.trim().toLowerCase();
    if (normalized.isEmpty) return familyId;

    final cleaned = normalized
        .replaceFirst(RegExp(r'^family_'), '')
        .replaceFirst(RegExp(r'^individual_'), '')
        .replaceFirst(RegExp('_${churchId.toLowerCase()}\$'), '');

    final displayName = cleaned
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ')
        .trim();

    if (displayName.isEmpty) return familyId;

    final suffix = displayName.endsWith('s') ? "'" : "'s";
    return '$displayName$suffix family';
  }

  String _familySeedFromId(String familyId, String churchId) {
    final normalized = familyId.trim().toLowerCase();
    if (normalized.isEmpty) return '';

    return normalized
        .replaceFirst(RegExp(r'^family_'), '')
        .replaceFirst(RegExp('_${churchId.toLowerCase()}\$'), '')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  void _prefillFamilyFieldsOnce(ChurchMembership membership, String churchId) {
    if (_familyFieldsPrefilled) return;
    _familyFieldsPrefilled = true;
    final familyId = membership.familyId.trim();
    if (familyId.toLowerCase().startsWith('family_')) {
      _selectedExistingFamilyId = familyId.isEmpty ? null : familyId;
      _useExistingFamilyId = _selectedExistingFamilyId != null;
    }
    if (membership.category.trim().toLowerCase() == 'family') {
      _familyNameController.text = _familySeedFromId(familyId, churchId);
    }
  }

  /// Resolves the familyId to persist for the current marital-status-derived
  /// category, mirroring LoginRequestScreen's admin edit form. Empty means
  /// "leave familyId as it already is" (e.g. individual not joining a
  /// family) rather than clearing it.
  String? _resolveFamilyIdToSave(String churchId, ChurchMembership current) {
    if (_useExistingFamilyId &&
        _selectedExistingFamilyId != null &&
        _selectedExistingFamilyId!.trim().isNotEmpty) {
      return _selectedExistingFamilyId!.trim();
    }
    if (_category() != 'family') return null;

    final seed = _familyNameController.text.trim();
    if (seed.isEmpty) return null;
    final normalizedSeed = _normalizeFamilySeed(seed, churchId);
    if (normalizedSeed.isEmpty) return null;
    return 'family_${normalizedSeed}_$churchId';
  }

  List<String> _parsedTalentsAndGifts() {
    return _talentsAndGiftsController.text
        .split(RegExp(r'[,\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _formatDob(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _pickProfilePhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    final image = await PickedImageData.fromXFile(file);
    if (image == null || !mounted) return;
    if (image.bytes.lengthInBytes > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.t('settings.profile_photo_too_large'),
          ),
        ),
      );
      return;
    }

    setState(() {
      _profilePhoto = image;
      _removeProfilePhoto = false;
    });
  }

  void _removeSelectedProfilePhoto() {
    setState(() {
      _profilePhoto = null;
      _removeProfilePhoto = true;
    });
  }

  Future<void> _fillCurrentLocation() async {
    final serviceDisabledMessage = ref.t('auth.location_service_disabled');
    final permissionDeniedMessage = ref.t('auth.location_permission_denied');
    final permissionDeniedForeverMessage =
        ref.t('auth.location_permission_denied_forever');
    final fetchFailedMessage = ref.t('auth.location_fetch_failed');

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

    final phone = _phoneController.text.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.t('settings.profile_phone_invalid'),
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
            ref.t('settings.profile_address_location_required'),
          ),
        ),
      );
      return;
    }
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.t('settings.profile_birthday_required'),
          ),
        ),
      );
      return;
    }
    if (_maritalStatus == 'married' && _weddingDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.t('members.member_wedding_day_required'),
          ),
        ),
      );
      return;
    }
    final churchId = await ref.read(currentChurchIdProvider.future);
    final currentMembership = ref.read(currentMembershipProvider).value;
    if (churchId != null &&
        currentMembership != null &&
        _maritalStatus.isNotEmpty) {
      if (_useExistingFamilyId &&
          (_selectedExistingFamilyId == null ||
              _selectedExistingFamilyId!.trim().isEmpty)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.t('members.existing_family_required'))),
        );
        return;
      }
      if (_category() == 'family' &&
          !_useExistingFamilyId &&
          _familyNameController.text.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.t('members.family_name_required'))),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repo = UserIdentityRepository(
        firestore: ref.read(firestoreProvider),
      );

      final profilePhotoUrl = await repo.updateProfile(
        uid: firebaseUser.uid,
        phone: phone,
        location: _locationController.text,
        address: _addressController.text,
        dob: _dob,
        maritalStatus: _maritalStatus,
        weddingDay: _maritalStatus == 'married' ? _weddingDay : null,
        educationalQualification: _educationalQualificationController.text,
        talentsAndGifts: _parsedTalentsAndGifts(),
        existingProfilePhotoUrl: widget.user.profilePhotoUrl,
        profilePhoto: _profilePhoto,
        removeProfilePhoto: _removeProfilePhoto,
      );
      await firebaseUser.updatePhotoURL(
        profilePhotoUrl.isEmpty ? null : profilePhotoUrl,
      );

      if (churchId != null &&
          currentMembership != null &&
          _maritalStatus.isNotEmpty) {
        final familyId = _resolveFamilyIdToSave(churchId, currentMembership);
        if (familyId != null && familyId != currentMembership.familyId) {
          await MembersRepository(
            firestore: ref.read(firestoreProvider),
            churchId: churchId,
          ).updateMemberCategory(
            firebaseUser.uid,
            category: _category(),
            familyId: familyId,
          );
        }
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final message = ref.t('settings.profile_updated');
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Mirrors LoginRequestScreen's admin family-ID section (existing-family
  /// toggle + dropdown, or a Family Name field to create a new one) — only
  /// shown once a marital status is picked, and only when this sheet was
  /// opened from inside a church (family ID has nowhere to attach to
  /// otherwise). Not shown from the church-picker account icon.
  Widget _buildFamilyIdSection(BuildContext context) {
    final churchId = ref.watch(currentChurchIdProvider).value;
    final membership = ref.watch(currentMembershipProvider).value;
    if (churchId == null || membership == null) return const SizedBox.shrink();

    _prefillFamilyFieldsOnce(membership, churchId);

    if (_familyIdsFutureChurchId != churchId) {
      _familyIdsFutureChurchId = churchId;
      _familyIdsFuture = ref.read(authRepositoryProvider).getFamilyIds(churchId);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: FutureBuilder<List<String>>(
        future: _familyIdsFuture,
        builder: (context, snapshot) {
          final familyIds = snapshot.data ?? const <String>[];
          final selectedFamilyValue =
              familyIds.contains(_selectedExistingFamilyId)
                  ? _selectedExistingFamilyId
                  : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (familyIds.isNotEmpty)
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  title: Text(ref.t('auth.family_existing_toggle')),
                  value: _useExistingFamilyId,
                  onChanged: (value) {
                    setState(() {
                      _useExistingFamilyId = value;
                      if (!value) _selectedExistingFamilyId = null;
                    });
                  },
                ),
              if (familyIds.isNotEmpty) const SizedBox(height: 12),
              if (familyIds.isNotEmpty && _useExistingFamilyId)
                AppDropdownField<String>(
                  initialValue: selectedFamilyValue,
                  labelText: ref.t('members.family_id_label'),
                  items: familyIds
                      .map(
                        (familyId) => DropdownMenuItem(
                          value: familyId,
                          child: Text(
                            _formatFamilyOptionLabel(familyId, churchId),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedExistingFamilyId = value;
                    });
                  },
                )
              else if (_category() == 'family')
                AppTextField(
                  controller: _familyNameController,
                  decoration: InputDecoration(
                    labelText: ref.t('members.family_name_label'),
                    helperText: ref.t('auth.family_name_helper'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              if (_category() == 'individual' && !_useExistingFamilyId)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    familyIds.isEmpty
                        ? ref.t('auth.family_none_available')
                        : ref.t('auth.family_join_existing_hint'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
            ],
          );
        },
      ),
    );
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
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AppProfileAvatar(
                        name: widget.user.name,
                        imageUrl: _removeProfilePhoto
                            ? null
                            : widget.user.profilePhotoUrl,
                        imageBytes: _profilePhoto?.bytes,
                        radius: 52,
                        borderColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.24),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: IconButton.filled(
                          tooltip: ref.t('settings.profile_photo_change'),
                          onPressed: _isSaving ? null : _pickProfilePhoto,
                          icon: const Icon(Icons.camera_alt_outlined),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _isSaving ? null : _pickProfilePhoto,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          ref.t('settings.profile_photo_choose'),
                        ),
                      ),
                      if (_profilePhoto != null ||
                          (!_removeProfilePhoto &&
                              widget.user.profilePhotoUrl.isNotEmpty))
                        TextButton.icon(
                          onPressed:
                              _isSaving ? null : _removeSelectedProfilePhoto,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: Text(
                            ref.t('settings.profile_photo_remove'),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsReviewCard(
              rows: [
                _SettingsReviewRow(
                  ref.t('members.name_label'),
                  widget.user.name,
                ),
                _SettingsReviewRow(
                  ref.t('members.email_label'),
                  widget.user.email,
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: ref.t('auth.phone_label'),
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
                decoration: appTextFieldDecoration(
                  context,
                  labelText: ref.t('auth.birthday_label'),
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _formatDob(_dob).isEmpty
                      ? ref.t('auth.birthday_hint')
                      : _formatDob(_dob),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _locationController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: ref.t('auth.location_label'),
                helperText: ref.t('auth.location_helper'),
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
                  ref.t('auth.location_use_current'),
                ),
              ),
            ),
            AppTextField(
              controller: _addressController,
              keyboardType: TextInputType.streetAddress,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: ref.t('auth.address_label'),
                helperText: ref.t('auth.address_helper'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            AppDropdownField<String>(
              initialValue: _maritalStatus.isEmpty ? null : _maritalStatus,
              labelText: ref.t('members.marital_status_label'),
              items: [
                DropdownMenuItem(
                  value: 'individual',
                  child: Text(ref.t('common.individual')),
                ),
                DropdownMenuItem(
                  value: 'married',
                  child: Text(ref.t('common.married')),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _maritalStatus = value ?? '';
                  if (_maritalStatus != 'married') _weddingDay = null;
                });
              },
            ),
            if (_maritalStatus == 'married') ...[
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _weddingDay ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate == null) return;
                  setState(() {
                    _weddingDay = pickedDate;
                  });
                },
                child: InputDecorator(
                  decoration: appTextFieldDecoration(
                    context,
                    labelText: ref.t('members.wedding_day_label'),
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _weddingDay == null
                        ? ref.t('members.wedding_day_hint')
                        : '${_weddingDay!.day.toString().padLeft(2, '0')}/'
                            '${_weddingDay!.month.toString().padLeft(2, '0')}/'
                            '${_weddingDay!.year}',
                  ),
                ),
              ),
            ],
            if (_maritalStatus.isNotEmpty) _buildFamilyIdSection(context),
            const SizedBox(height: 16),
            AppTextField(
              controller: _educationalQualificationController,
              decoration: InputDecoration(
                labelText: ref.t('members.educational_qualification'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _talentsAndGiftsController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: ref.t('members.talents_and_gifts'),
                helperText: ref.t('members.talents_and_gifts_helper'),
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
                    : Text(ref.t('feed.update_action')),
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
      decoration: carouselBoxDecoration(context),
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
