import 'package:flutter/material.dart';

class StartSceen extends StatelessWidget {
  const StartSceen(this.startQuiz, {super.key});

  final void Function(int value) startQuiz;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              onPressed: () => startQuiz(123),
              icon: const Icon(
                Icons.arrow_forward,
                color: Colors.white70,
              ),
              label: const Text(
                "Start Quiz",
                style: TextStyle(color: Colors.white70),
              ))
        ],
      ),
    );
  }
}
