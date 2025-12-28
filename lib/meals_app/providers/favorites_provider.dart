import 'package:flutter_application/meals_app/model/meal.dart';
import 'package:hooks_riverpod/legacy.dart';

class FavoriteMealNotifier extends StateNotifier<List<Meal>> {
  FavoriteMealNotifier() : super([]);

  void toggleFavoriteStatus(Meal meal) {
    final mealIsFavorite = state.contains(meal);
    if (mealIsFavorite) {
      state = state.where((m) => m != meal).toList();
    } else {
      state = [...state, meal];
    }
  }

  bool isFavorite(String mealId) {
    return state.any((meal) => meal.id == mealId);
  }
}



final favoriteMealProvider = 
StateNotifierProvider<FavoriteMealNotifier, List<Meal>>((ref) {
  return FavoriteMealNotifier();
});