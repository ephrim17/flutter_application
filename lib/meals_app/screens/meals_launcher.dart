import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/mock_data/dummy_data.dart';
import 'package:flutter_application/meals_app/model/meal.dart';
import 'package:flutter_application/meals_app/model/meal_category.dart';
import 'package:flutter_application/meals_app/screens/meals_screen.dart';
import 'package:flutter_application/meals_app/widgets/category_grid_item.dart';

class MealsLauncher extends StatelessWidget {
  const MealsLauncher({super.key, required this.availableMeals});

  final List<Meal> availableMeals;

  void selectedCategory(BuildContext context, MealCategory selectedCategory) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(selectedCategory.title),
            ),
            body: MealsScreen(
              title: selectedCategory.title,
              meals: mealByCategory(selectedCategory)
            ),
          );
        },
      ),
    );
  }

  List<Meal> mealByCategory(MealCategory category) {
    return availableMeals.where((meal) => meal.categories.contains(category.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridView(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              mainAxisSpacing: 1,
              crossAxisSpacing: 1),
          children: [
            for (final category in availableCategories)
              CategoryGridItem(
                category: category,
                onSelectCategory: (selectedCategoryItem) {
                  selectedCategory(context, selectedCategoryItem);
                },
              ),
          ]
          ),
    );
  }
}

//availableCategories.map((category) => CategoryGridItem(category: category)).toList())