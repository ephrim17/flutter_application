import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/screens/church_side_drawer.dart';
import 'package:flutter_application/church_app/screens/dashboard/dashboard_screen.dart';
import 'package:flutter_application/church_app/screens/feed_screen.dart';
import 'package:flutter_application/church_app/screens/for_you/for_you_screen.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
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

  void setActiveScreen(int index) {
    setState(() {
      selectedIndex = index;
    });
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
        ref: ref,
        promptIfNeeded: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final screens = <Widget>[
      HomeScreen(),
      ForYouScreen(),
      FeedScreen(),
      if (isAdmin) const DashboardScreen(),
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
      if (isAdmin)
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
        title: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.62,
          ),
          child: LightningGradientText(
            text: ref.t('church_tab.app_title', fallback: 'TNBM'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
          ),
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
