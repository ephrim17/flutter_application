import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/mock_data/dummy_data.dart';
import 'package:flutter_application/meals_app/model/meal.dart';
import 'package:flutter_application/meals_app/providers/meals_provider.dart';
import 'package:flutter_application/meals_app/screens/filter_meals_screen.dart';
import 'package:flutter_application/meals_app/screens/meals_launcher.dart';
import 'package:flutter_application/meals_app/screens/meals_screen.dart';
import 'package:flutter_application/meals_app/widgets/side_drawer.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';


const kInitialFilters = {
  Filter.glutenFree: false,
};

class MealsTabScreen extends ConsumerStatefulWidget {
  const MealsTabScreen({super.key});

  @override
  ConsumerState<MealsTabScreen> createState() => _MealsTabScreenState();
}

class _MealsTabScreenState extends ConsumerState<MealsTabScreen> {

  Widget? _activeScreen;
  int selectedIndex = 0;
  String title = "Meals App";

  final List<Meal> _favoriteMeals = [];
  List<Meal> availableMeals = [];
  Map<Filter, bool> selectedFilters = kInitialFilters;

  void setActiveScreen(int index){
    setState(() {
      selectedIndex = index;
    });
  }

  void _onSelectedMenu(String menu) async {
    Navigator.of(context).pop();
    if (menu == 'meal') {
      setActiveScreen(0);
    } else if (menu == 'filter') {
      final result = await Navigator.of(context).push<Map<Filter, bool>>(MaterialPageRoute(
        builder: (context) => FilterMealsScreen(currentFilters: selectedFilters),
      ));
      setState(() {
        selectedFilters = result ?? kInitialFilters;
      });
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

  // @override
  // void initState() {
  //   super.initState();
  //   _activeScreen = MealsLauncher(updateFavMeals: updateFavorites, availableMeals: ,);
  // }

  @override
  Widget build(BuildContext context) {
    //using provider to get meals
    final meals = ref.watch(mealsProvider);
    availableMeals = meals.where((meal) {
      if (!meal.isGlutenFree && selectedFilters[Filter.glutenFree]!) {
        return false;
      }
      return true;
    }).toList();

    _activeScreen = selectedIndex == 0 ?  MealsLauncher(updateFavMeals: updateFavorites, availableMeals: availableMeals) : MealsScreen(meals: _favoriteMeals, title: "", updateFavMeals: updateFavorites, showAppBar: false);
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