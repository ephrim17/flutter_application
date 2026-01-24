import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';

class PlanCard extends StatelessWidget {
  final String month;
  final Gradient gradient;
  final VoidCallback onTap;

  const PlanCard({super.key, 
    required this.month,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
        child: Container(
          width: 220,
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cornerRadius),
            gradient: gradient,
          ),
          child: Center(
            child: Text(
              month,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
