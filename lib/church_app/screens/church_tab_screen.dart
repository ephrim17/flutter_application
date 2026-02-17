import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/screens/church_side_drawer.dart';
import 'package:flutter_application/church_app/screens/for_you/for_you_screen.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/services/user_service.dart';
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
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (selectedIndex == 0) {
      _activeScreen = HomeScreen();
    } else {
      _activeScreen = ForYouScreen();
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true, // 👈 REQUIRED
        toolbarHeight: 72,
        title: LightningGradientText(
          text:
              'TNBM', //GoogleFonts.lalezar(fontSize: 30, fontWeight: FontWeight.w600)
          style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 32,
                letterSpacing: 1,
              ),
        ),
      ),
      body: _activeScreen,
      drawer: AppDrawer(onSelectedMenu: _onSelectedMenu),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        onTap: (value) => setActiveScreen(value),
        currentIndex: selectedIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'For You'),
        ],
      ),
    );
  }
}
