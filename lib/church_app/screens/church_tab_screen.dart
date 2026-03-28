import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart'
    show selectedChurchProvider;
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/church_side_drawer.dart';
import 'package:flutter_application/church_app/screens/dashboard/dashboard_screen.dart';
import 'package:flutter_application/church_app/screens/feed_screen.dart';
import 'package:flutter_application/church_app/screens/for_you/for_you_screen.dart';
import 'package:flutter_application/church_app/screens/go_further_screen.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/services/analytics/firebase_analytics_helper.dart';
import 'package:flutter_application/church_app/services/church_user_repository.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_application/church_app/services/notification_service.dart';
import 'package:flutter_application/church_app/widgets/gradient_title_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ChurchTabScreen extends ConsumerStatefulWidget {
  const ChurchTabScreen({super.key});

  @override
  ConsumerState<ChurchTabScreen> createState() => _ChurchTabScreenState();
}

class _ChurchTabScreenState extends ConsumerState<ChurchTabScreen> {
  Widget? _activeScreen;
  int selectedIndex = 0;
  String? _lastDailyStreakSyncKey;

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  Future<void> _syncDailyStreakIfNeeded(AppUser user) async {
    final churchId = await ref.read(currentChurchIdProvider.future);
    if (churchId == null || !mounted) return;

    final today = DateTime.now();
    if (user.lastStreakRecordedAt != null &&
        _isSameDay(user.lastStreakRecordedAt!, today)) {
      return;
    }

    final syncKey =
        '$churchId:${user.uid}:${today.year}-${today.month}-${today.day}';
    if (_lastDailyStreakSyncKey == syncKey) return;

    _lastDailyStreakSyncKey = syncKey;
    final repository = ChurchUsersRepository(
      firestore: ref.read(firestoreProvider),
      churchId: churchId,
    );

    try {
      await repository.updateDailyStreak(uid: user.uid);
      ref.invalidate(appUserProvider);
      ref.invalidate(getCurrentUserProvider);
    } catch (_) {
      _lastDailyStreakSyncKey = null;
    }
  }

  Future<void> setActiveScreen(int index) async {
    setState(() {
      selectedIndex = index;
    });

    await _logTabOpen(index);
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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await handleNotificationSetup(
        context: context,
        container: ProviderScope.containerOf(context, listen: false),
        promptIfNeeded: true,
      );
      final user = await ref.read(getCurrentUserProvider.future);
      if (user != null) {
        await _syncDailyStreakIfNeeded(user);
      }
      await _logTabOpen(selectedIndex);
    });

    ref.listenManual(appUserProvider, (previous, next) async {
      final user = next.asData?.value;
      if (user == null) return;
      await _syncDailyStreakIfNeeded(user);
    }, fireImmediately: true);
  }

  Future<void> _logTabOpen(int index) async {
    final eventName = switch (index) {
      0 => 'home_opened',
      1 => 'for_you_opened',
      2 => 'feed_opened',
      3 => 'go_further_opened',
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
    final isAdmin = ref.watch(isAdminProvider);
    final config = ref.watch(appConfigProvider).asData?.value;
    final selectedChurch = ref.watch(selectedChurchProvider);
    final canSeeDashboard = isAdmin && (config?.dashboardEnabled ?? false);
    final screens = <Widget>[
      HomeScreen(),
      ForYouScreen(),
      FeedScreen(),
      const GoFurtherScreen(),
      if (canSeeDashboard) const DashboardScreen(),
    ];
    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: const Icon(Icons.home_filled),
        label: ref.t('church_tab.home', fallback: 'Home'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.star),
        label: ref.t('church_tab.for_you', fallback: 'For You'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.newspaper_rounded),
        label: ref.t('church_tab.feeds', fallback: 'Feeds'),
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.travel_explore_rounded),
        label: 'Go Further',
      ),
      if (canSeeDashboard)
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_customize_rounded),
          label: 'Dashboard',
        ),
    ];

    if (selectedIndex >= screens.length) {
      selectedIndex = 0;
    }
    _activeScreen = screens[selectedIndex];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 88,
        title: ChurchAppBarBrandTitle(
          text: ref.t('church_tab.app_title', fallback: 'TNBM'),
          logo: selectedChurch?.logo ?? '',
          maxWidth: MediaQuery.of(context).size.width * 0.68,
        ),
      ),
      body: _activeScreen,
      drawer: AppDrawer(onSelectedMenu: _onSelectedMenu),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        decoration: carouselBoxDecoration(context),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            backgroundColor: Colors.transparent,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
            selectedLabelStyle:
                Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
            unselectedLabelStyle:
                Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
            onTap: (value) => setActiveScreen(value),
            currentIndex: selectedIndex,
            items: items,
          ),
        ),
      ),
    );
  }
}
