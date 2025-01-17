import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/mock_data/dummy_data.dart';
import 'package:flutter_application/meals_app/widgets/category_grid_item.dart';
import 'package:google_fonts/google_fonts.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

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
          children: availableCategories.map((category) => CategoryGridItem(category: category)).toList()),
    );
  }
}