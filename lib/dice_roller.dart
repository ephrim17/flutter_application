import 'dart:math';

import 'package:flutter/material.dart';

class DiceRoller extends StatefulWidget{

  const DiceRoller({super.key});

  @override
  State<DiceRoller> createState(){
    return _DiceRollerState();
  }
}

class _DiceRollerState extends State<DiceRoller>{

  var activeDiceImage = 'assets/images/dice-3.png';
  final random = Random();

   void rollDice() {
    var diceRoll = random.nextInt(6) + 1;
    setState(() {
      activeDiceImage = 'assets/images/dice-$diceRoll.png';
    }); 
  }

  @override
  Widget build(BuildContext context) {
    return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(activeDiceImage, width: 200),
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
            );
  }
}