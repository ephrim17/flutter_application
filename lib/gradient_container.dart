import 'package:flutter/material.dart';
import 'package:flutter_application/styled_Text.dart';

class GradientContainer extends StatelessWidget {
  const GradientContainer(this.colors, {super.key});

const GradientContainer.standardColor({super.key})
  : colors = const [Color.fromARGB(255, 0, 0, 0), Color.fromARGB(255, 0, 0, 0)];

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
