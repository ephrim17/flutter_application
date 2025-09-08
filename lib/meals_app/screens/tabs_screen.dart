import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/screens/meals_launcher.dart';

class MealsTabScreen extends StatefulWidget {
  const MealsTabScreen({super.key});

  @override
  State<MealsTabScreen> createState() => _MealsTabScreenState();
}

class _MealsTabScreenState extends State<MealsTabScreen> {

  Widget? _activeScreen = const MealsLauncher();
  String _activeTitle = 'Meals App';
  int selectedIndex = 0;

  void setActiveScreen(int index){
    setState(() {
      selectedIndex = index;
      _activeScreen = index == 0 ?  const MealsLauncher() : const Placeholder();
      _activeTitle = index == 0 ? 'Meals App' : 'Favorites';
    });
  }

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      appBar: AppBar(
        title:  Text(_activeTitle),
      ),
      body: _activeScreen,
      bottomNavigationBar: BottomNavigationBar(
        onTap: (value) => setActiveScreen(value),
        currentIndex: selectedIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Categories'),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Favorites'),
        ],
      ),
    );
  }
}