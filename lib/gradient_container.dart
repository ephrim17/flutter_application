import 'package:flutter/material.dart';
import 'package:flutter_application/styled_Text.dart';

class GradientContainer extends StatelessWidget {
  const GradientContainer({super.key, required this.colors});

  final List<Color> colors;
  
  @override
  Widget build(context) {
    return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: colors,
              begin: Alignment.bottomRight,
              end: Alignment.topLeft),
        ),
        child: const StyledText(outputText: 'outputText with named parameter'));
  }
}
