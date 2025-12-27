import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/screens/meals_tab_screen.dart';
import 'package:flutter_application/meals_app/widgets/side_drawer.dart';

class FilterMealsScreen extends StatefulWidget {
  const FilterMealsScreen({super.key});

  @override
  State<FilterMealsScreen> createState() => _FilterMealsScreenState();
}

class _FilterMealsScreenState extends State<FilterMealsScreen> {

  bool value = false;

  void onChanged(bool newValue) {
    setState(() {
      value = newValue;
    });
  }

  void _onSelectedMenu(String menu) {
    Navigator.of(context).pop();
    if (menu == 'meal') {
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (context) => MealsTabScreen(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Filter Meals"),
      ),
      drawer: SideDrawer(onSelectedMenu: _onSelectedMenu),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text("Gluten-free"),
            subtitle: const Text("Only include gluten-free meals"),
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}