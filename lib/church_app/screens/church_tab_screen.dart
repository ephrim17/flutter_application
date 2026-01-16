import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ChurchTabScreen extends ConsumerStatefulWidget {
  const ChurchTabScreen({super.key});

  @override
  ConsumerState<ChurchTabScreen> createState() => _ChurchTabScreenState();
}

class _ChurchTabScreenState extends ConsumerState<ChurchTabScreen> {

  Widget? _activeScreen;
  int selectedIndex = 0;

  void setActiveScreen(int index){
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {

    if (selectedIndex == 0) {
      _activeScreen = HomeScreen();
    } else {
      _activeScreen = Placeholder();
    }

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("Church"),
        ),
        body: _activeScreen,
        bottomNavigationBar: BottomNavigationBar(
          onTap: (value) => setActiveScreen(value),
          currentIndex: selectedIndex,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.star), label: 'For You'),
          ],
        ),
      ),
    );
  }
}