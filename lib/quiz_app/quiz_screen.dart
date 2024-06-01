import 'package:flutter/material.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {


  void answerButtonTapped() {
    print("Answer button tapped");
  }

  @override
  Widget build(BuildContext context) {
    return  SizedBox(
      width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             const Text("Question Screen", style: TextStyle(color: Colors.white)),    
             AnswerButton("answerText", answerButtonTapped)
          ],
        ),
    );
  }
}

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
        backgroundColor:  const Color.fromARGB(255, 33, 1, 95),
        foregroundColor:  Colors.white),
      child: Text(answerText));
  }
}
