import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/model/meal.dart';
import 'package:transparent_image/transparent_image.dart';

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
      subtitle: Text(
          '${meal.duration} min - ${meal.complexity.name} - ${meal.affordability.name}'),
    );
  }
}

class MealItemStackWidget extends StatelessWidget {
  const MealItemStackWidget({super.key, required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: FadeInImage.memoryNetwork(
              placeholder: kTransparentImage,
              image: meal.imageUrl,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(
                    meal.title,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
