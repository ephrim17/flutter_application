import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/model/meal_category.dart';

class CategoryGridItem extends StatelessWidget {
  const CategoryGridItem({super.key, required this.category, required this.onSelectCategory});

  final MealCategory category;
  final void Function(MealCategory category) onSelectCategory;

  @override
  Widget build(BuildContext context) {
    //return Text(category.title, style: Theme.of(context).textTheme.bodyMedium);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: () => onSelectCategory(category),
        splashColor: category.color,
        borderRadius: BorderRadius.circular(10),
        child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0),
                  gradient: LinearGradient(
                      colors: [category.color, category.color.withBlue(100)],
                      begin: Alignment.bottomRight,
                      end: Alignment.topLeft),
                ),
                child: Center(child: Text(category.title, style: Theme.of(context).textTheme.bodyMedium))),
      ),
    );
  }
}