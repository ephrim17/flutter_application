import 'package:flutter/material.dart';
import 'package:flutter_application/styled_Text.dart';

class GradientContainer extends StatelessWidget {
  const GradientContainer(this.colors, {super.key});

const GradientContainer.standardColor({super.key}) : colors = const [Color.fromARGB(255, 118, 51, 51), Color.fromARGB(255, 0, 0, 0)];

  final List<Color> colors;

  void rollDice() {

  }
  
  @override
  Widget build(context) {
    return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: colors,
              begin: Alignment.bottomRight,
              end: Alignment.topLeft
              ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/dice-2.png', width: 200),
              const SizedBox(height: 20),
              TextButton(
                onPressed: rollDice,
                style: TextButton.styleFrom(
                  //padding: const EdgeInsets.only(top: 30),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle( color: Colors.white, fontSize: 20)
                ),
                child: const Text("Roll Dice"),
                )
              ],
            )
        ));
  }
}
