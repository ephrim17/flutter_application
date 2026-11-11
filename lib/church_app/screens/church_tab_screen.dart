import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_assets.dart';
import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/prompt_sequence_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart'
    show churchRepositoryProvider, selectedChurchProvider;
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/church_side_drawer.dart';
// Parked with the Community tab; kept so re-enabling is one line.
// ignore: unused_import
import 'package:flutter_application/church_app/screens/community/community_feed_screen.dart';
import 'package:flutter_application/church_app/screens/communication/communication_screen.dart';
import 'package:flutter_application/church_app/screens/dashboard/dashboard_screen.dart';
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:flutter_application/church_app/screens/for_you/for_you_screen.dart';
import 'package:flutter_application/church_app/screens/for_you/sections/article_section.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/services/analytics/firebase_analytics_helper.dart';
import 'package:flutter_application/church_app/services/notification_service.dart';
import 'package:flutter_application/church_app/services/user_identity_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bottom_tab_bar.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:flutter_application/church_app/widgets/church_quick_switcher_sheet.dart';
import 'package:flutter_application/church_app/widgets/gradient_title_widget.dart';
import 'package:flutter_application/church_app/widgets/hideable_app_bar.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ChurchTabScreen extends ConsumerStatefulWidget {
  const ChurchTabScreen({super.key});

  @override
  ConsumerState<ChurchTabScreen> createState() => _ChurchTabScreenState();
}

class _ChurchTabScreenState extends ConsumerState<ChurchTabScreen> {
  int selectedIndex = 0;
  bool _appBarVisible = true;

  Future<void> setActiveScreen(int index) async {
    if (!mounted) return;
    setState(() {
      selectedIndex = index;
      _appBarVisible = true;
    });

    await _logTabOpen(index);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    return computeHideableAppBarVisibility(
      notification: notification,
      currentlyVisible: _appBarVisible,
      onChanged: (visible) {
        if (!mounted) return;
        setState(() => _appBarVisible = visible);
      },
    );
  }

  void _onSelectedMenu(String menu) async {
    Navigator.of(context).pop();
    if (menu == 'meal') {
      setActiveScreen(0);
    } else if (menu == 'filter') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => Placeholder(),
      ));
    }
  }

  /// Switches to the church a tapped notification came from, if it is not
  /// the one already open.
  ///
  /// Members of several churches are notified about all of them, so a tap can
  /// legitimately refer to a church that is not on screen. Routing to the
  /// destination without this showed the right screen of the wrong church.
  Future<void> _handleNotificationChurchRequest() async {
    final requestedId = notificationChurchRequest.value;
    if (requestedId == null || !mounted) return;
    if (requestedId == ref.read(selectedChurchProvider)?.id) {
      notificationChurchRequest.value = null;
      return;
    }

    final church =
        await ref.read(churchRepositoryProvider).getChurchById(requestedId);
    if (!mounted) return;
    // Unknown church, or one this person has since left: stay put rather
    // than drop them somewhere they cannot read.
    notificationChurchRequest.value = null;
    if (church == null) return;

    await _switchToChurch(church);
  }

  void _handleNotificationTabRequest() {
    final requestedIndex = notificationTabRequest.value;
    if (requestedIndex == null || !mounted) return;
    notificationTabRequest.value = null;
    setActiveScreen(requestedIndex);
  }

  void _handleNotificationDestinationRequest() {
    final destination = notificationDestinationRequest.value;
    if (destination == null || !mounted) return;

    setActiveScreen(1);
    if (destination != NotificationDestination.articles) return;

    notificationDestinationRequest.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ArticleListScreen()),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    notificationTabRequest.addListener(_handleNotificationTabRequest);
    notificationDestinationRequest
        .addListener(_handleNotificationDestinationRequest);
    notificationChurchRequest.addListener(_handleNotificationChurchRequest);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // A tap that arrived before this screen existed — a cold start, or the
      // rebuild that follows switching church — set these notifiers while
      // nothing was listening, so apply whatever is still pending.
      _handleNotificationChurchRequest();
      _handleNotificationTabRequest();
      _handleNotificationDestinationRequest();
      ref.read(notificationPromptCompletedProvider.notifier).state = false;
      try {
        await handleNotificationSetup(
          context: context,
          container: ProviderScope.containerOf(context, listen: false),
          promptIfNeeded: true,
        );
      } finally {
        if (mounted) {
          ref.read(notificationPromptCompletedProvider.notifier).state = true;
        }
      }
      if (!mounted) return;
      await _logTabOpen(selectedIndex);
    });
  }

  @override
  void dispose() {
    notificationTabRequest.removeListener(_handleNotificationTabRequest);
    notificationDestinationRequest
        .removeListener(_handleNotificationDestinationRequest);
    notificationChurchRequest.removeListener(_handleNotificationChurchRequest);
    super.dispose();
  }

  Future<void> _logTabOpen(int index) async {
    if (!mounted) return;
    final eventName = switch (index) {
      0 => 'home_opened',
      1 => 'for_you_opened',
      // 2 => 'community_opened',
      2 => 'communication_opened',
      _ => null,
    };

    if (eventName == null) return;
    await logChurchAnalyticsEvent(
      ref,
      name: eventName,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentMembershipProvider, (previous, next) {
      final previousMembership = previous?.asData?.value;
      final nextMembership = next.asData?.value;
      if (nextMembership == null ||
          (previousMembership?.docId == nextMembership.docId &&
              _sameGroups(
                previousMembership?.churchGroupIds ?? const [],
                nextMembership.churchGroupIds,
              ))) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          syncNotificationTopicIfAuthorized(
            ProviderScope.containerOf(context, listen: false),
          ),
        );
      });
    });

    final isAdmin = ref.watch(isAdminProvider);
    final config = ref.watch(appConfigProvider).asData?.value;
    final selectedChurch = ref.watch(selectedChurchProvider);
    final canSeeDashboard = isAdmin && (config?.dashboardEnabled ?? false);

    // Community is parked, not deleted — `CommunityFeedScreen` and its
    // providers are untouched, so restoring it is re-enabling these lines.
    // Its slot now carries Communication, which is church staff only: a
    // member sees Home and For You.
    // const communityIndex = 2;
    final screens = <Widget>[
      HomeScreen(),
      ForYouScreen(),
      // const CommunityFeedScreen(),
      if (isAdmin) const CommunicationScreen(),
      if (canSeeDashboard) const DashboardScreen(),
    ];
    final items = <AppBottomTabItem>[
      AppBottomTabItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: ref.t('church_tab.home'),
      ),
      AppBottomTabItem(
        icon: Icons.star_outline_rounded,
        selectedIcon: Icons.star_rounded,
        label: ref.t('church_tab.for_you'),
      ),
      // AppBottomTabItem(
      //   icon: Icons.play_circle_outline_rounded,
      //   selectedIcon: Icons.play_circle_rounded,
      //   label: ref.t('church_tab.community'),
      // ),
      if (isAdmin)
        AppBottomTabItem(
          icon: Icons.forum_outlined,
          selectedIcon: Icons.forum_rounded,
          label: ref.t('church_tab.communication'),
        ),
      if (canSeeDashboard)
        AppBottomTabItem(
          icon: Icons.dashboard_customize_outlined,
          selectedIcon: Icons.dashboard_customize_rounded,
          label: ref.t('church_tab.dashboard'),
        ),
    ];

    if (selectedIndex >= screens.length) {
      selectedIndex = 0;
    }

    // The feed hid the app bar and the tab bar as you scrolled. Nothing
    // else does, so while Community is parked that behaviour is inert —
    // restore it with the tab:
    // final isCommunityTab = selectedIndex == communityIndex;

    // Once inside a church there is no "back" out of it — switching only
    // ever happens by tapping the church name above, which navigates
    // deliberately rather than relying on the system back gesture/button.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Column(
          children: [
            HideableAppBar(
              visible: _appBarVisible, // && !isCommunityTab,
              appBar: AppBar(
                centerTitle: false,
                // `kToolbarHeight`, the Material standard, rather than the
                // 40 this used to hard-code. At 40 the bar was shorter than
                // the 48dp minimum touch target, so the drawer button and
                // the church switcher were both undersized and the bar read
                // as a cramped strip rather than a navigation bar.
                toolbarHeight: kToolbarHeight,
                title: ChurchAppBarBrandTitle(
                  text: ref.t('guest_shell.title'),
                  logo: AppAssets.churchTreeAppIcon,
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _openChurchSwitcher,
                      child: ConstrainedBox(
                        // A real target, not just the size of the artwork.
                        constraints: const BoxConstraints(
                          minHeight: 48,
                          minWidth: 48,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ChurchLogoAvatar(
                                logo: selectedChurch?.logo ?? '',
                                size: 32,
                              ),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: screens[selectedIndex],
              ),
            ),
          ],
        ),
        drawer: AppDrawer(onSelectedMenu: _onSelectedMenu),
        bottomNavigationBar: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          // child: (isCommunityTab && !_appBarVisible)
          //     ? const SizedBox(width: double.infinity, height: 0)
          //     : AppBottomTabBar(...),
          child: AppBottomTabBar(
            currentIndex: selectedIndex,
            items: items,
            onTap: setActiveScreen,
          ),
        ),
      ),
    );
  }

  Future<void> _openChurchSwitcher() async {
    final picked = await showAppModalBottomSheet<Church>(
      context: context,
      heightFactor: 0.6,
      builder: (_) => const ChurchQuickSwitcherSheet(),
    );
    if (picked == null || !mounted) return;
    await _switchToChurch(picked);
  }

  Future<void> _switchToChurch(Church church) async {
    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    if (firebaseUser == null) return;

    await ChurchLocalStorage().saveChurch(
      id: church.id,
      name: church.name,
      logo: church.logo,
    );
    if (!mounted) return;
    ref.read(selectedChurchProvider.notifier).state = church;
    ref.invalidate(currentChurchIdProvider);
    unawaited(
      UserIdentityRepository(firestore: ref.read(firestoreProvider))
          .setLastActiveChurchId(firebaseUser.uid, church.id),
    );
    unawaited(
      syncNotificationTopicIfAuthorized(
        ProviderScope.containerOf(context, listen: false),
      ),
    );
    if (!mounted) return;
    // Always clears the whole stack — this screen is the church's own
    // root, so switching must never leave it (or the church being left)
    // reachable via back.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppEntry()),
      (route) => false,
    );
  }

  bool _sameGroups(List<String> left, List<String> right) =>
      left.length == right.length && left.toSet().containsAll(right);
}
