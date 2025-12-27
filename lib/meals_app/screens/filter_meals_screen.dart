import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/screens/meals_tab_screen.dart';
import 'package:flutter_application/meals_app/widgets/side_drawer.dart';

class FilterMealsScreen extends StatefulWidget {
  const FilterMealsScreen({super.key, required this.currentFilters});

  final Map<Filter, bool> currentFilters;

  @override
  State<FilterMealsScreen> createState() => _FilterMealsScreenState();
}

class _FilterMealsScreenState extends State<FilterMealsScreen> {

  bool _glutenFreeFilterSet = false;

  void onChanged(bool newValue) {
    setState(() {
      _glutenFreeFilterSet = newValue;
    });
  }

  // void _onSelectedMenu(String menu) {
  //   Navigator.of(context).pop();
  //   if (menu == 'meal') {
  //     Navigator.pushReplacement(context, MaterialPageRoute(
  //       builder: (context) => MealsTabScreen(),
  //     ));
  //   }
  // }

  @override
  void initState() {
    super.initState();
    _glutenFreeFilterSet = widget.currentFilters[Filter.glutenFree] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Filter Meals"),
      ),
      //drawer: SideDrawer(onSelectedMenu: _onSelectedMenu),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
          Navigator.of(context).pop({
            Filter.glutenFree: _glutenFreeFilterSet,
          });
        },
        child: Column(
          children: [
            SwitchListTile(
              title: const Text("Gluten-free"),
              subtitle: const Text("Only include gluten-free meals"),
              value: _glutenFreeFilterSet,
              onChanged: onChanged,
              activeColor: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

enum Filter {
  glutenFree,
}