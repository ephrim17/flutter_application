import 'package:flutter/material.dart';
import 'package:flutter_application/styled_Text.dart';

class GradientContainer extends StatelessWidget {
  const GradientContainer({super.key});

  @override
  Widget build(context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [
          Color.fromARGB(255, 0, 0, 0),
          Color.fromARGB(255, 45, 7, 98)
        ], begin: Alignment.bottomRight, end: Alignment.topLeft),
      ),
      child: const StyledText(outputText: 'outputText with named parameter')
    );
  }
}