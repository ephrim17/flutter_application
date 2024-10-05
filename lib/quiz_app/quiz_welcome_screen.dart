import 'package:flutter/material.dart';

class QuizWelcomeScreen extends StatelessWidget {
  const QuizWelcomeScreen(this.startQuiz, {super.key});

  final void Function(String value) startQuiz;

  @override
  Widget build(BuildContext context) {
    return
    Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: [
      Padding(
        padding: const EdgeInsets.only(top: 60, right: 10),
        child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Image.asset(
            'assets/images/quiz-logo.png',
            width: 250,
            color: Colors.white70,
          ),
          const SizedBox(height: 20),
          const Text(
            "Let's Start Flutter The Fun Way!",
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
              onPressed: () => startQuiz("quiz-screen"),
              icon: const Icon(
                Icons.arrow_forward,
                color: Colors.white70,
              ),
              label: const Text(
                "Start Quiz",
                style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
        ]
        ),
      ),
    ],
    );
  }
}
