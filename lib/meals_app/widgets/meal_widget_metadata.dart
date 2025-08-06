import 'package:flutter/material.dart';

class MealWidgetMetaData extends StatelessWidget {
  const MealWidgetMetaData({super.key, required this.icon, required this.metadata});

  final IconData icon;
  final String metadata;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          metadata,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
        
      ],
    );
  }
}