import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/providers/filters_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class FilterMealsScreen extends ConsumerStatefulWidget {
  const FilterMealsScreen({super.key});

  @override
  ConsumerState<FilterMealsScreen> createState() => _FilterMealsScreenState();
}

class _FilterMealsScreenState extends ConsumerState<FilterMealsScreen> {

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
    final activeFilter = ref.read(filterProvider);
    _glutenFreeFilterSet = activeFilter[Filter.glutenFree]!;
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
          ref.read(filterProvider.notifier).setFilter({
            Filter.glutenFree: _glutenFreeFilterSet,
          });
          Navigator.of(context).pop(result);
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