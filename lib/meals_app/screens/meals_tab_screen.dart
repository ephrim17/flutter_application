import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/model/meal.dart';
import 'package:flutter_application/meals_app/screens/filter_meals_screen.dart';
import 'package:flutter_application/meals_app/screens/meals_launcher.dart';
import 'package:flutter_application/meals_app/screens/meals_screen.dart';
import 'package:flutter_application/meals_app/widgets/side_drawer.dart';

class MealsTabScreen extends StatefulWidget {
  const MealsTabScreen({super.key});

  @override
  State<MealsTabScreen> createState() => _MealsTabScreenState();
}

class _MealsTabScreenState extends State<MealsTabScreen> {

  Widget? _activeScreen;
  int selectedIndex = 0;
  String title = "Meals App";

  final List<Meal> _favoriteMeals = [];

  void setActiveScreen(int index){
    setState(() {
      selectedIndex = index;
    });
  }

  void _onSelectedMenu(String menu) {
    Navigator.of(context).pop();
    if (menu == 'meal') {
      setActiveScreen(0);
    } else if (menu == 'filter') {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => FilterMealsScreen(),
      ));
    }
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

    _activeScreen = selectedIndex == 0 ?  MealsLauncher(updateFavMeals: updateFavorites) : MealsScreen(meals: _favoriteMeals, title: "", updateFavMeals: updateFavorites, showAppBar: false);
    title = selectedIndex == 0 ? "Meals" : "Your Favorites";

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: _activeScreen,
      drawer: SideDrawer(onSelectedMenu: _onSelectedMenu),
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