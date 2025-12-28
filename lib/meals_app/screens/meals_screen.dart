import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/model/meal.dart';
import 'package:flutter_application/meals_app/widgets/meal_item_widget.dart';
import 'package:google_fonts/google_fonts.dart';

class MealsScreen extends StatelessWidget {
  const MealsScreen(
      {super.key,
      required this.meals,
      required this.title
    });

  final String title;
  final List<Meal> meals;

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
   if (meals.isNotEmpty) {
      content = ListView.builder(
        itemCount: meals.length,
        itemBuilder: (context, index) {
          final meal = meals[index];
          return MealItemWidget(meal: meal);
        },
      );
    }
    return content;
  }
}
