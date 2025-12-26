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
        updateSnackBarMessage("Meal is no longer a favorite", meal);
        _favoriteMeals.remove(meal);
      });
    } else {
      setState(() {
        updateSnackBarMessage("Meal is added to a favorite", meal);
        _favoriteMeals.add(meal);
      });
    }
  }

  void updateSnackBarMessage(String message, Meal meal){
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
      content: Text(message),
      action: SnackBarAction(label: 'undo', onPressed: () {
        setState(() { 
          if (_favoriteMeals.contains(meal)) {
            _favoriteMeals.remove(meal);
          } else {
            _favoriteMeals.add(meal);
          }
        });
      }),
    ));
  }

  @override
  void initState() {
    super.initState();
    _activeScreen = MealsLauncher(updateFavMeals: updateFavorites);
  }

  @override
  Widget build(BuildContext context) {

    _activeScreen = selectedIndex == 0 ?  MealsLauncher(updateFavMeals: updateFavorites) : MealsScreen(meals: _favoriteMeals, title: "Favorites", updateFavMeals: updateFavorites);

    return Scaffold(
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