import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/model/meal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:transparent_image/transparent_image.dart';

class MealDetailScreen extends StatelessWidget {
  const MealDetailScreen({super.key, required this.title, required this.meal, required this.updateFavMeals});

  final String title;
  final Meal meal;

  final void Function(Meal meal) updateFavMeals;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              updateFavMeals(meal);
            },
            icon: const Icon(Icons.favorite),
          ),
        ],
        title: Text(
          title,
          style: GoogleFonts.aBeeZee(
          color: Theme.of(context).textTheme.titleLarge?.color),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
                FadeInImage.memoryNetwork(
                  placeholder: kTransparentImage,
                  image: meal.imageUrl,
                ),
              
              const SizedBox(height: 20),
              Text(
                "Ingredients Needed ",
                style: GoogleFonts.aBeeZee(fontSize: 20, fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color),
              ),
              
              for (final ingredient in meal.ingredients)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    '* $ingredient',
                    style: GoogleFonts.aBeeZee(
            color: Theme.of(context).textTheme.titleLarge?.color),
                  ),
                ),
              const SizedBox(height: 20),
          
              Text(
                "Steps to Prepare",
                style: GoogleFonts.aBeeZee(fontSize: 20, fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color),
              ),
          
              for (final step in meal.steps)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    '* $step',
                    style: GoogleFonts.aBeeZee(
            color: Theme.of(context).textTheme.titleLarge?.color),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
    ),
    );
  }
}