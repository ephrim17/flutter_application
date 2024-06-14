import 'package:flutter/material.dart';


class AnswerButton extends StatelessWidget {
  const AnswerButton(this.answerText, this.onPressed,{
    super.key,
  });

  final String answerText;
  final void Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(5.0),
        backgroundColor:  const Color.fromARGB(255, 33, 1, 95),
        foregroundColor:  Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0))
        ),
      child: Text(answerText, textAlign: TextAlign.center,));
  }
}
