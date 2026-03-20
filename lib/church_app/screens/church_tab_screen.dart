import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/screens/church_side_drawer.dart';
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
    if (selectedIndex == 0) {
      _activeScreen = HomeScreen();
    } else if (selectedIndex == 1) {
      _activeScreen = ForYouScreen();
    } else {
      _activeScreen = FeedScreen();
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true, // 👈 REQUIRED
        toolbarHeight: 72,
        title: LightningGradientText(
          text: ref.t('church_tab.app_title', fallback: 'TNBM'),
          style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
      body: _activeScreen,
      drawer: AppDrawer(onSelectedMenu: _onSelectedMenu),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        onTap: (value) => setActiveScreen(value),
        currentIndex: selectedIndex,
        items: [
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
        ],
      ),
    );
  }
}
