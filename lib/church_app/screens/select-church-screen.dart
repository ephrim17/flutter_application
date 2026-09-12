// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_confirm_dialog.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/contact_launcher.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/super_admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/church_side_drawer.dart'
    show GuestSideDrawer;
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:flutter_application/church_app/screens/entry/request_church_access_screen.dart';
import 'package:flutter_application/church_app/screens/entry/request_pending_screen.dart';
import 'package:flutter_application/church_app/screens/side_drawer/settings_screen.dart'
    show GuestSettingsScreen;
import 'package:flutter_application/church_app/screens/super_admin/create_church_screen.dart';
import 'package:flutter_application/church_app/screens/super_admin/super_admin_home_screen.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:flutter_application/church_app/services/user_identity_repository.dart';
import 'package:flutter_application/church_app/services/notification_service.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/app_bottom_tab_bar.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/church_discovery_card.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:flutter_application/church_app/widgets/color_text_widget.dart';
import 'package:flutter_application/church_app/widgets/global_feed_list_view.dart';
import 'package:flutter_application/church_app/widgets/gradient_title_widget.dart';
import 'package:flutter_application/church_app/widgets/linear_screen_background_widget.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:async';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';

// Derived from the already-live churchesProvider (StreamProvider) and
// myMembershipsProvider (StreamProvider, collectionGroup('members') —
// §2.5/§5.2/§9.9) rather than doing their own one-time .get(), so Your
// Churches/Pending Approval/Other Churches all update the instant a
// request is submitted, approved, or a church is left — no manual
// ref.invalidate() needed anywhere. A plain Provider watching two
// AsyncValues is still exposed as AsyncValue<List<Church>> to callers,
// same shape a FutureProvider would give, so this is a drop-in swap.
AsyncValue<List<Church>> _combineMembershipChurches(
  Ref ref, {
  required bool Function(ChurchMembership membership) where,
}) {
  final churchesAsync = ref.watch(churchesProvider);
  final membershipsAsync = ref.watch(myMembershipsProvider);

  if (churchesAsync.isLoading || membershipsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (churchesAsync.hasError) {
    return AsyncValue.error(
        churchesAsync.error!, churchesAsync.stackTrace ?? StackTrace.empty);
  }
  if (membershipsAsync.hasError) {
    return AsyncValue.error(membershipsAsync.error!,
        membershipsAsync.stackTrace ?? StackTrace.empty);
  }

  final churches = churchesAsync.value ?? const <Church>[];
  final memberships = membershipsAsync.value ?? const <ChurchMembership>[];
  final churchesById = {for (final church in churches) church.id: church};

  final result = memberships
      .where(where)
      .map((membership) => churchesById[membership.churchId])
      .whereType<Church>()
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return AsyncValue.data(result);
}

// Your Churches is entered churches only — a pending (not yet approved)
// request belongs on RequestPendingScreen, not here (§9.1: membership
// existing is never authorization on its own).
final userChurchesProvider = Provider<AsyncValue<List<Church>>>((ref) {
  return _combineMembershipChurches(ref,
      where: (membership) => membership.approved);
});

/// Same discovery query as [userChurchesProvider], kept separate so a
/// pending request can be surfaced to the person (§9.1: they should always
/// be able to see they've already requested a church) without it slipping
/// into Your Churches, which is entered-church-only.
final pendingChurchesProvider = Provider<AsyncValue<List<Church>>>((ref) {
  return _combineMembershipChurches(ref,
      where: (membership) => !membership.approved);
});

/// The primary landing screen once signed in with nothing resolvable to
/// enter automatically — a two-tab shell, mirroring `ChurchTabScreen`'s own
/// bottom-tab pattern: "Home" (`GlobalFeedListView`, the cross-church feed,
/// "make the user feel engaged") and "Churches" (`ChurchPickerScreen`'s
/// "Welcome Home"/Your churches/Other churches content, embedded as this
/// tab's body rather than a separately pushed screen). Always root-level:
/// no back button out of it in any of its entry points (entry gate, or
/// Settings > Register for another church).
class SelectChurchScreen extends ConsumerStatefulWidget {
  const SelectChurchScreen({super.key, this.initialTabIndex = 0});

  /// 0 = Home, 1 = Churches. Settings > Register for another church opens
  /// straight on the Churches tab instead of the default Home landing.
  final int initialTabIndex;

  @override
  ConsumerState<SelectChurchScreen> createState() => _SelectChurchScreenState();
}

class _SelectChurchScreenState extends ConsumerState<SelectChurchScreen> {
  late int _selectedIndex = widget.initialTabIndex;

  @override
  Widget build(BuildContext context) {
    final firebaseUser = ref.watch(authStateProvider).value;
    final isSuperAdmin = ref.watch(isSuperAdminProvider).maybeWhen(
          data: (value) => value && firebaseUser != null,
          orElse: () => false,
        );
    final userIdentity = ref.watch(userIdentityProvider).value;
    final screens = const [
      GlobalFeedListView(),
      ChurchPickerScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: ChurchAppBarBrandTitle(
          text: context.t('guest_shell.title'),
          logo: '',
        ),
        actions: [
          if (isSuperAdmin)
            IconButton(
              tooltip: context.t('super_admin.open_dashboard'),
              onPressed: () async {
                await ref.read(superAdminEntryModeProvider.notifier).setMode(
                      SuperAdminEntryMode.superAdmin,
                    );
                if (!context.mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const SuperAdminHomeScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          if (userIdentity != null)
            IconButton(
              tooltip: context.t('settings.title'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const GuestSettingsScreen(),
                ),
              ),
              icon: Badge(
                isLabelVisible: !userIdentity.profileComplete,
                smallSize: 10,
                backgroundColor: Theme.of(context).colorScheme.error,
                child: const Icon(Icons.settings_outlined),
              ),
            ),
        ],
      ),
      drawer: const GuestSideDrawer(),
      body: screens[_selectedIndex],
      bottomNavigationBar: AppBottomTabBar(
        currentIndex: _selectedIndex,
        items: [
          AppBottomTabItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: context.t('church_tab.home'),
          ),
          AppBottomTabItem(
            icon: Icons.church_outlined,
            selectedIcon: Icons.church,
            label: context.t('select_church.churches_tab'),
          ),
        ],
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

/// "Welcome Home" — Your churches / Other churches — `SelectChurchScreen`'s
/// "Churches" tab body. No `Scaffold`/`AppBar` of its own; the outer tab
/// shell provides both.
class ChurchPickerScreen extends ConsumerStatefulWidget {
  const ChurchPickerScreen({super.key});

  @override
  ConsumerState<ChurchPickerScreen> createState() => _ChurchPickerScreenState();
}

class _ChurchPickerScreenState extends ConsumerState<ChurchPickerScreen> {
  bool _showYourChurches = true;
  bool _showPendingChurches = false;
  bool _showOtherChurches = false;

  Future<bool> _showRequestAccessPrompt(BuildContext context) async {
    return showAppConfirmDialog(
      context: context,
      title: context.t('auth.user_not_found_title'),
      message: context.t('auth.no_account_found_request_access'),
      cancelLabel: context.t('settings.cancel'),
      confirmLabel: context.t('auth.request_access'),
    );
  }

  Future<void> _handleContinue(
    BuildContext context,
    Church selectedChurch,
  ) async {
    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    if (firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('auth.login_subtitle'),
          ),
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: AppLoadingIndicator()),
    );

    try {
      final memberDoc = await FirestorePaths.churchMemberDoc(
        ref.read(firestoreProvider),
        selectedChurch.id,
        firebaseUser.uid,
      ).get();

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (memberDoc.exists) {
        final approved = memberDoc.data()?['approved'] == true;

        // A membership existing here doesn't mean approved — this list
        // includes every church the person has any relationship with.
        // Never route into ChurchTabScreen for one that isn't (§9.1: role/
        // membership existence is never authorization on its own).
        if (!approved) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RequestPendingScreen(
                churchId: selectedChurch.id,
                churchName: selectedChurch.name,
                churchLogo: selectedChurch.logo,
                initiallyNotifying:
                    memberDoc.data()?['notifyOnApproval'] == true,
              ),
            ),
          );
          return;
        }

        await ref.read(superAdminEntryModeProvider.notifier).setMode(
              SuperAdminEntryMode.normal,
            );
        if (!context.mounted) return;
        await ChurchLocalStorage().saveChurch(
          id: selectedChurch.id,
          name: selectedChurch.name,
          logo: selectedChurch.logo,
        );
        if (!context.mounted) return;
        ref.read(selectedChurchProvider.notifier).state = selectedChurch;
        ref.invalidate(currentChurchIdProvider);
        unawaited(
          UserIdentityRepository(firestore: ref.read(firestoreProvider))
              .setLastActiveChurchId(firebaseUser.uid, selectedChurch.id),
        );
        unawaited(
          syncNotificationTopicIfAuthorized(
            ProviderScope.containerOf(context, listen: false),
          ),
        );

        // Always clear the whole stack, not just the immediately-preceding
        // route — this screen sits on top of `SelectChurchScreen`, and
        // leaving either of those underneath would reopen a back button
        // into the pre-entry state once inside `ChurchTabScreen`.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppEntry()),
          (route) => false,
        );
        return;
      }

      final shouldRequest = await _showRequestAccessPrompt(context);
      if (!context.mounted || !shouldRequest) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RequestChurchAccessScreen(
            churchId: selectedChurch.id,
            churchName: selectedChurch.name,
            churchLogo: selectedChurch.logo,
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? error.code)),
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final churchesAsync = ref.watch(churchesProvider);
    final userChurchesAsync = ref.watch(userChurchesProvider);
    final pendingChurchesAsync = ref.watch(pendingChurchesProvider);
    final firebaseUser = ref.watch(authStateProvider).value;
    final isSuperAdmin = ref.watch(isSuperAdminProvider).maybeWhen(
          data: (value) => value && firebaseUser != null,
          orElse: () => false,
        );

    return LinearScreenBackground(
      solidBackground: true,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      _buildChurchSections(
                        context,
                        churchesAsync: churchesAsync,
                        userChurchesAsync: userChurchesAsync,
                        pendingChurchesAsync: pendingChurchesAsync,
                      ),
                      const Spacer(),
                      const SizedBox(height: 16),
                      if (!isSuperAdmin)
                        Center(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () async {
                              final result =
                                  await Navigator.of(context).push<String>(
                                MaterialPageRoute(
                                  builder: (_) => const CreateChurchScreen(
                                    publicRegistrationMode: true,
                                  ),
                                ),
                              );
                              if (!context.mounted || result == null) return;
                              if (result == 'registered_pending_approval') {
                                await showDialog<void>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    icon: const Icon(
                                      Icons.mark_email_read_outlined,
                                    ),
                                    title: Text(
                                      context
                                          .t('church.register_received_title'),
                                    ),
                                    content: Text(
                                      context
                                          .t('church.register_success_pending'),
                                    ),
                                    actions: [
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext).pop(),
                                        child: Text(
                                          context.t('common.ok'),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: _RegisterChurchText(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChurchSections(
    BuildContext context, {
    required AsyncValue<List<Church>> churchesAsync,
    required AsyncValue<List<Church>> userChurchesAsync,
    required AsyncValue<List<Church>> pendingChurchesAsync,
  }) {
    if (churchesAsync.isLoading ||
        userChurchesAsync.isLoading ||
        pendingChurchesAsync.isLoading) {
      return Container(
        decoration: carouselBoxDecoration(context),
        padding: const EdgeInsets.all(24),
        child: const Center(child: AppLoadingIndicator()),
      );
    }

    if (churchesAsync.hasError ||
        userChurchesAsync.hasError ||
        pendingChurchesAsync.hasError) {
      return Container(
        decoration: carouselBoxDecoration(context),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('church.directory_title'),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              context.t('church.directory_load_error'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final allChurches = churchesAsync.asData?.value ?? const <Church>[];
    final userChurches = userChurchesAsync.asData?.value ?? const <Church>[];
    final pendingChurches =
        pendingChurchesAsync.asData?.value ?? const <Church>[];
    final memberChurchIds = userChurches.map((church) => church.id).toSet();
    final pendingChurchIds = pendingChurches.map((church) => church.id).toSet();
    final otherChurches = allChurches
        .where((church) =>
            !memberChurchIds.contains(church.id) &&
            !pendingChurchIds.contains(church.id))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChurchSectionCard(
          title: context.t('church.your_churches_title'),
          subtitle: userChurches.isEmpty
              ? context.t('church.your_churches_empty_subtitle')
              : context.t('church.your_churches_subtitle'),
          count: userChurches.length,
          isExpanded: _showYourChurches,
          onToggle: () {
            setState(() {
              _showYourChurches = !_showYourChurches;
            });
          },
          onOpen: userChurches.isEmpty
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _ChurchDirectoryScreen(
                        title: context.t('church.your_churches_title'),
                        churches: userChurches,
                        emptyMessage:
                            context.t('church.your_churches_empty_state'),
                        onChurchTap: (directoryContext, church) =>
                            _showChurchDetailsSheet(
                          directoryContext,
                          ref,
                          church,
                          isMemberChurch: true,
                        ),
                      ),
                    ),
                  ),
          child: userChurches.isEmpty
              ? _EmptyChurchState(
                  message: context.t('church.your_churches_empty_state'),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 14),
        _ChurchSectionCard(
          title: context.t('church.pending_churches_title'),
          subtitle: pendingChurches.isEmpty
              ? context.t('church.pending_churches_empty_subtitle')
              : context.t('church.pending_churches_subtitle'),
          count: pendingChurches.length,
          isExpanded: _showPendingChurches,
          onToggle: () {
            setState(() {
              _showPendingChurches = !_showPendingChurches;
            });
          },
          onOpen: pendingChurches.isEmpty
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _ChurchDirectoryScreen(
                        title: context.t('church.pending_churches_title'),
                        churches: pendingChurches,
                        emptyMessage:
                            context.t('church.pending_churches_empty_state'),
                        onChurchTap: (directoryContext, church) =>
                            Navigator.of(directoryContext).push(
                          MaterialPageRoute(
                            builder: (_) => RequestPendingScreen(
                              churchId: church.id,
                              churchName: church.name,
                              churchLogo: church.logo,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          child: pendingChurches.isEmpty
              ? _EmptyChurchState(
                  message: context.t('church.pending_churches_empty_state'),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 14),
        _ChurchSectionCard(
          title: context.t('church.other_churches_title'),
          subtitle: context.t('church.other_churches_subtitle'),
          count: otherChurches.length,
          isExpanded: _showOtherChurches,
          onToggle: () {
            setState(() {
              _showOtherChurches = !_showOtherChurches;
            });
          },
          onOpen: otherChurches.isEmpty
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _ChurchDirectoryScreen(
                        title: context.t('church.other_churches_title'),
                        churches: otherChurches,
                        emptyMessage:
                            context.t('church.other_churches_empty_state'),
                        onChurchTap: (directoryContext, church) =>
                            _showChurchDetailsSheet(
                          directoryContext,
                          ref,
                          church,
                          isMemberChurch: false,
                        ),
                      ),
                    ),
                  ),
          child: otherChurches.isEmpty
              ? _EmptyChurchState(
                  message: context.t('church.other_churches_empty_state'),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showChurchDetailsSheet(
    BuildContext context,
    WidgetRef ref,
    Church church, {
    required bool isMemberChurch,
  }) {
    final parentContext = context;
    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      heightFactor: 0.65,
      builder: (context) {
        final theme = Theme.of(context);
        return Material(
          color: Colors.transparent,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ChurchLogoAvatar(
                        logo: church.logo,
                        size: 52,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              church.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ChurchDetailRow(
                            icon: Icons.person_outline,
                            label: context.t('church.detail_pastor'),
                            value: _valueOrFallback(church.pastorName),
                          ),
                          _ChurchDetailRow(
                            icon: Icons.email_outlined,
                            label: context.t('church.detail_email'),
                            value: _valueOrFallback(church.email),
                          ),
                          _ChurchDetailRow(
                            icon: Icons.phone_outlined,
                            label: context.t('church.detail_contact'),
                            value: _valueOrFallback(church.contact),
                            onActionTap: church.contact.trim().isEmpty
                                ? null
                                : () =>
                                    launchPhoneCall(context, church.contact),
                          ),
                          _ChurchDetailRow(
                            icon: Icons.location_on_outlined,
                            label: context.t('church.detail_address'),
                            value: _valueOrFallback(church.address),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SolidButton(
                    label: isMemberChurch
                        ? context.t('church.select_action')
                        : context.t('auth.request_access'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (!parentContext.mounted) return;
                      if (isMemberChurch) {
                        _handleContinue(parentContext, church);
                        return;
                      }

                      Navigator.of(parentContext).push(
                        MaterialPageRoute(
                          builder: (_) => RequestChurchAccessScreen(
                            churchId: church.id,
                            churchName: church.name,
                            churchLogo: church.logo,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChurchSectionCard extends StatelessWidget {
  const _ChurchSectionCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.isExpanded,
    required this.onToggle,
    this.onOpen,
    required this.child,
  });

  final String title;
  final String subtitle;
  final int count;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback? onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: carouselBoxDecoration(context),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(cornerRadius),
            onTap: onOpen ?? onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.t(
                            count == 1
                                ? 'select_church.count_singular'
                                : 'select_church.count_plural',
                            parameters: {'count': '$count'},
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded && onOpen == null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: child,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChurchDirectoryScreen extends StatefulWidget {
  const _ChurchDirectoryScreen({
    required this.title,
    required this.churches,
    required this.emptyMessage,
    required this.onChurchTap,
  });

  final String title;
  final List<Church> churches;
  final String emptyMessage;
  final void Function(BuildContext context, Church church) onChurchTap;

  @override
  State<_ChurchDirectoryScreen> createState() => _ChurchDirectoryScreenState();
}

class _ChurchDirectoryScreenState extends State<_ChurchDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Church> get _filteredChurches {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.churches;

    return widget.churches.where((church) {
      return church.name.toLowerCase().contains(query) ||
          church.pastorName.toLowerCase().contains(query) ||
          church.address.toLowerCase().contains(query) ||
          church.email.toLowerCase().contains(query) ||
          church.contact.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filteredChurches = _filteredChurches;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: AppBarTitle(text: widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(86),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.12),
                ),
              ),
            ),
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(cornerRadius),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: AppTextField(
                variant: AppTextFieldVariant.search,
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: context.t('common.search'),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 10, right: 6),
                    child: Icon(
                      Icons.search_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _query = '';
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(cornerRadius),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(cornerRadius),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(cornerRadius),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: filteredChurches.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  widget.emptyMessage,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: filteredChurches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final church = filteredChurches[index];
                return ChurchDiscoveryCard(
                  church: church,
                  onTap: () => widget.onChurchTap(context, church),
                );
              },
            ),
    );
  }
}

class _EmptyChurchState extends StatelessWidget {
  const _EmptyChurchState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: carouselBoxDecoration(context),
      padding: const EdgeInsets.all(18),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _RegisterChurchText extends StatelessWidget {
  const _RegisterChurchText();

  @override
  Widget build(BuildContext context) {
    return ColorText(
      badgeText: context.t('church.register_your_church'),
      fontSize: 16,
    );
  }
}

class _ChurchDetailRow extends StatelessWidget {
  const _ChurchDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onActionTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final row = Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );

    if (onActionTap == null) return row;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onActionTap,
      child: row,
    );
  }
}

String _valueOrFallback(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'Not provided' : trimmed;
}
