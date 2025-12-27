import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/model/meal.dart';
import 'package:flutter_application/meals_app/widgets/meal_item_widget.dart';
import 'package:google_fonts/google_fonts.dart';

class MealsScreen extends StatelessWidget {
  const MealsScreen({super.key, required this.meals, required this.title, required this.updateFavMeals, required this.showAppBar});

  final String title;
  final void Function(Meal meal) updateFavMeals;
  final List<Meal> meals;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {

    Widget content = Center(
        child: Text(
          'No meals found for the selected category.',
          style: GoogleFonts.aBeeZee(
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
      );
      if (showAppBar && meals.isNotEmpty) {
        content = Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: Text(
              title,
              style: GoogleFonts.aBeeZee(
                  color: Theme.of(context).textTheme.titleLarge?.color),
            ),
          ),
          body: ListView.builder(
        itemCount: meals.length,
        itemBuilder: (context, index) {
          final meal = meals[index];
          return MealItemWidget(meal: meal, updateFavMeals: updateFavMeals);
        },
      ),
    );
    } else if (meals.isNotEmpty && !showAppBar) {
      content = ListView.builder(
        itemCount: meals.length,
        itemBuilder: (context, index) {
          final meal = meals[index];
          return MealItemWidget(meal: meal, updateFavMeals: updateFavMeals);
        },
      );
    }
    return content;
  }
}

