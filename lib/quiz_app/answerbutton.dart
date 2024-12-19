import 'package:flutter/material.dart';


class AnswerButton extends StatelessWidget {
  const AnswerButton({super.key, required this.answerText, required this.onPressed});

  final String answerText;
  final void Function(String answer) onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => onPressed(answerText),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(5.0),
        //backgroundColor:  const Color.fromARGB(255, 1, 27, 68),
        //foregroundColor:  Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0))
        ),
      child: Text(answerText, textAlign: TextAlign.center,));
  }
}
