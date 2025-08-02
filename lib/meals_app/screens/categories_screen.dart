import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/mock_data/dummy_data.dart';
import 'package:flutter_application/meals_app/screens/meals_screen.dart';
import 'package:flutter_application/meals_app/widgets/category_grid_item.dart';
import 'package:google_fonts/google_fonts.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});


  void selectedCategory(BuildContext context, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return MealsScreen(
            title: title,
            meals: dummyMeals,
          );
        },
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          "Meal App",
          style: GoogleFonts.aBeeZee(
              color: Theme.of(context).textTheme.titleLarge?.color),
        ),
      ),
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
                  selectedCategory(context, selectedCategoryItem.title);
                },
              ),
          ]
          ),
    );
  }
}

//availableCategories.map((category) => CategoryGridItem(category: category)).toList())