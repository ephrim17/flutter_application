import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/model/meal.dart';
import 'package:flutter_application/meals_app/providers/favorites_provider.dart';
import 'package:flutter_application/meals_app/widgets/heart_icon_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:transparent_image/transparent_image.dart';


class MealDetailScreen extends ConsumerWidget {
  const MealDetailScreen({super.key, required this.title, required this.meal});

  final String title;
  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void updateSnackBarMessage(String message, Meal meal) {
      ScaffoldMessenger.of(context).clearMaterialBanners();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    void toggleFavoriteStatus() {
      ref.read(favoriteMealProvider.notifier).toggleFavoriteStatus(meal);
      final isFavorite = ref.read(favoriteMealProvider).contains(meal);
      final message = isFavorite
          ? 'Meal added to favorites.'
          : 'Meal removed from favorites.';
      updateSnackBarMessage(message, meal);
    }

  final isFavorite = ref.watch(favoriteMealProvider).contains(meal);
  final iconName = isFavorite ? Icons.favorite : Icons.favorite_border;
  
  return Scaffold(
    appBar: AppBar(
      centerTitle: true,
      actions: [
        HeartIconButton(
          isFavorite: isFavorite,
          onToggle: toggleFavoriteStatus,
          iconName: iconName,
        ),
      ],
      title: Text(
        title,
        style: GoogleFonts.aBeeZee(
          color: Theme.of(context).textTheme.titleLarge?.color,
        ),
      ),
    ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: meal.id,
                child: FadeInImage.memoryNetwork(
                  placeholder: kTransparentImage,
                  image: meal.imageUrl,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Ingredients Needed ",
                style: GoogleFonts.aBeeZee(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
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
                style: GoogleFonts.aBeeZee(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
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