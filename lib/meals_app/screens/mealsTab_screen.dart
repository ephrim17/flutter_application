import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/model/meal.dart';
import 'package:flutter_application/meals_app/screens/meals_launcher.dart';
import 'package:flutter_application/meals_app/screens/meals_screen.dart';

class MealsTabScreen extends StatefulWidget {
  const MealsTabScreen({super.key});

  @override
  State<MealsTabScreen> createState() => _MealsTabScreenState();
}

class _MealsTabScreenState extends State<MealsTabScreen> {

  Widget? _activeScreen;
  String _activeTitle = 'Meals App';
  int selectedIndex = 0;

  final List<Meal> _favoriteMeals = [];

  void setActiveScreen(int index){
    setState(() {
      selectedIndex = index;
    });
  }

  void updateFavorites(Meal meal) {
    if (_favoriteMeals.contains(meal)) {
      setState(() {
        _favoriteMeals.remove(meal);
      });
    } else {
      setState(() {
        _favoriteMeals.add(meal);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _activeScreen = MealsLauncher(updateFavMeals: updateFavorites);
  }

  @override
  Widget build(BuildContext context) {

    _activeScreen = selectedIndex == 0 ?  MealsLauncher(updateFavMeals: updateFavorites) : MealsScreen(meals: _favoriteMeals, title: "", updateFavMeals: updateFavorites);
    _activeTitle = selectedIndex == 0 ? 'Meals App' : 'Favorites';

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