import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/model/meal_category.dart';

class CategoryGridItem extends StatelessWidget {
  const CategoryGridItem({super.key, required this.category});

  final MealCategory category;

  @override
  Widget build(BuildContext context) {
    return Text(category.title, style: Theme.of(context).textTheme.bodyMedium);
  }
}