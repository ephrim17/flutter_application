import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/providers/filters_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class FilterMealsScreen extends ConsumerWidget {
  const FilterMealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final activeFilters = ref.watch(filterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Filter Meals"),
      ),
      //drawer: SideDrawer(onSelectedMenu: _onSelectedMenu),
      body: Column(
          children: [
            SwitchListTile(
              title: const Text("Gluten-free"),
              subtitle: const Text("Only include gluten-free meals"),
              value: activeFilters[Filter.glutenFree]!,
              onChanged: (newValue) {
                ref.read(filterProvider.notifier).setFilter({
                  Filter.glutenFree: newValue,
                });
              },
              activeColor: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      );
  }
}