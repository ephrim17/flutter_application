import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/model/meal.dart';
import 'package:flutter_application/meals_app/widgets/meal_widget.dart';

class MealsScreen extends StatelessWidget {
  const MealsScreen({super.key, required this.meals, required this.title});

  final String title;
  final List<Meal> meals;

  @override
  Widget build(BuildContext context) {

    Widget content = Center(
      child: Text(
        'No meals found for the selected category.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );

    if (meals.isNotEmpty) {
      content = ListView.builder(
        itemCount: meals.length,
        itemBuilder: (context, index) {
          final meal = meals[index];
          return MealItemStackWidget(meal: meal);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
      ),
      body: content,
    );
  }
}

