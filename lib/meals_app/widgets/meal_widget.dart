import 'package:flutter/material.dart';
import 'package:flutter_application/meals_app/model/meal.dart';
import 'package:flutter_application/meals_app/screens/meal_detail_screen.dart';
import 'package:flutter_application/meals_app/widgets/meal_widget_metadata.dart';
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

  void onSelectMeal(BuildContext context, Meal selectedMeal) {
     Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return MealDetailScreen(
            title: selectedMeal.title,
            meal: selectedMeal,
          );
        },
      ),
    );
  }

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
            child: InkWell(
              onTap: () => onSelectMeal(context, meal),
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      meal.title,
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 8,
                      children: [
                        MealWidgetMetaData(icon: Icons.schedule, metadata: '${meal.duration} min'),
                        MealWidgetMetaData(icon: Icons.subtitles_outlined, metadata: meal.affordability.name),
                        MealWidgetMetaData(icon: Icons.attach_money_rounded, metadata: meal.complexity.name)
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
