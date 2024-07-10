import 'package:flutter/material.dart';
import 'package:flutter_application/dice_app/dice_roller.dart';

class GradientContainer extends StatelessWidget {
  const GradientContainer(this.colors, {super.key});

  const GradientContainer.standardColor({super.key})
      : colors = const [
          Color.fromARGB(255, 118, 51, 51),
          Color.fromARGB(255, 0, 0, 0)
        ];

  final List<Color> colors;

  @override
  Widget build(context) {
    return MaterialApp(
      home: Scaffold(
        body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.bottomRight,
                  end: Alignment.topLeft),
            ),
            child: const Center(child: DiceRoller())),
      ),
    );
  }
}
