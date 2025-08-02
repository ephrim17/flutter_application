

import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/model/meal.dart';

class MealItemWidget extends StatelessWidget {
  const MealItemWidget({super.key, required this.meal});

  final Meal meal;

    @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(meal.title),
      leading: CircleAvatar(
        backgroundImage: NetworkImage(meal.imageUrl),
      ),
      subtitle: Text('${meal.duration} min - ${meal.complexity.name} - ${meal.affordability.name}'),
    );
  }
}