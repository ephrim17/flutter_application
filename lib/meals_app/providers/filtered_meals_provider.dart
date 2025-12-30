import 'package:flutter_application/meals_app/model/meal.dart';
import 'package:flutter_application/meals_app/providers/filters_provider.dart';
import 'package:flutter_application/meals_app/providers/meals_provider.dart';
import 'package:riverpod/riverpod.dart';

final filteredMealsProvider = Provider<List<Meal>>((ref) {
  final meals = ref.watch(mealsProvider);
  final activeFilters = ref.watch(filterProvider);

  return meals.where((meal) {
    if (!meal.isGlutenFree && activeFilters[Filter.glutenFree]!) {
      return false;
    }
    return true;
  }).toList();
});
