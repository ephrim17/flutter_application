import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/prompt_sequence_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart'
    show selectedChurchProvider;
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/church_side_drawer.dart';
import 'package:flutter_application/church_app/screens/dashboard/dashboard_screen.dart';
import 'package:flutter_application/church_app/screens/for_you/for_you_screen.dart';
import 'package:flutter_application/church_app/screens/for_you/sections/article_section.dart';
import 'package:flutter_application/church_app/screens/go_further_screen.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/services/analytics/firebase_analytics_helper.dart';
import 'package:flutter_application/church_app/services/notification_service.dart';
import 'package:flutter_application/church_app/widgets/app_bottom_tab_bar.dart';
import 'package:flutter_application/church_app/widgets/gradient_title_widget.dart';
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
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse) {
        if (_appBarVisible) setState(() => _appBarVisible = false);
      } else if (notification.direction == ScrollDirection.forward) {
        if (!_appBarVisible) setState(() => _appBarVisible = true);
      }
    } else if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      if (notification.metrics.pixels <= 0 && !_appBarVisible) {
        setState(() => _appBarVisible = true);
      }
    }
    return false;
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
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
    super.dispose();
  }

  Future<void> _logTabOpen(int index) async {
    if (!mounted) return;
    final eventName = switch (index) {
      0 => 'home_opened',
      1 => 'for_you_opened',
      2 => 'discover_opened',
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
    ref.listen(appUserProvider, (previous, next) {
      final previousUser = previous?.asData?.value;
      final nextUser = next.asData?.value;
      if (nextUser == null ||
          (previousUser?.uid == nextUser.uid &&
              _sameGroups(
                previousUser?.churchGroupIds ?? const [],
                nextUser.churchGroupIds,
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
    final screens = <Widget>[
      HomeScreen(),
      ForYouScreen(),
      const GoFurtherScreen(),
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
      AppBottomTabItem(
        icon: Icons.travel_explore_outlined,
        selectedIcon: Icons.travel_explore_rounded,
        label: ref.t('church_tab.discover'),
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

    return Scaffold(
      body: Column(
        children: [
          _HideableAppBar(
            visible: _appBarVisible,
            appBar: AppBar(
              centerTitle: true,
              toolbarHeight: 88,
              title: ChurchAppBarBrandTitle(
                text: ref.t('church_tab.app_title'),
                logo: selectedChurch?.logo ?? '',
                maxWidth: MediaQuery.of(context).size.width * 0.68,
              ),
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
      bottomNavigationBar: AppBottomTabBar(
        currentIndex: selectedIndex,
        items: items,
        onTap: setActiveScreen,
      ),
    );
  }

  bool _sameGroups(List<String> left, List<String> right) =>
      left.length == right.length && left.toSet().containsAll(right);
}

/// Collapses [appBar] out of view (Instagram-style) rather than pushing it
/// off-screen — the reserved slot never resizes, only the visible slice does,
/// so hiding/showing never triggers a Scaffold relayout of the body below.
class _HideableAppBar extends StatelessWidget {
  const _HideableAppBar({
    required this.visible,
    required this.appBar,
  });

  final bool visible;
  final PreferredSizeWidget appBar;

  @override
  Widget build(BuildContext context) {
    final maxHeight =
        appBar.preferredSize.height + MediaQuery.of(context).padding.top;

    return ClipRect(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: visible ? maxHeight : 0,
        alignment: Alignment.topCenter,
        child: OverflowBox(
          minHeight: maxHeight,
          maxHeight: maxHeight,
          alignment: Alignment.topCenter,
          child: appBar,
        ),
      ),
    );
  }
}
