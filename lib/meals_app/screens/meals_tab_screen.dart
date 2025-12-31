import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/model/meal.dart';
import 'package:flutter_application/meals_app/providers/favorites_provider.dart';
import 'package:flutter_application/meals_app/providers/filtered_meals_provider.dart';
import 'package:flutter_application/meals_app/screens/filter_meals_screen.dart';
import 'package:flutter_application/meals_app/screens/meals_launcher.dart';
import 'package:flutter_application/meals_app/screens/meals_screen.dart';
import 'package:flutter_application/meals_app/widgets/side_drawer.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_application/meals_app/providers/filters_provider.dart';

const kInitialFilters = {
  Filter.glutenFree: false,
};

class MealsTabLauncher extends ConsumerStatefulWidget {
  const MealsTabLauncher({super.key});

  @override
  ConsumerState<MealsTabLauncher> createState() => _MealsTabLauncherState();
}

class _MealsTabLauncherState extends ConsumerState<MealsTabLauncher> {

  Widget? _activeScreen;
  int selectedIndex = 0;
  String title = "Meals App";

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
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => FilterMealsScreen(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    //using provider to get meals
    availableMeals = ref.watch(filteredMealsProvider);
    if (selectedIndex == 0) {
      //final favoriteMeals = ref.watch(favoriteMealProvider).toList();
      _activeScreen = MealsLauncher(availableMeals: availableMeals);
    } else {
      _activeScreen = MealsScreen(
        title: "Your Favorites",
        meals: ref.watch(favoriteMealProvider)
      );
    }

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