import 'package:flutter/material.dart';

class QuizWelcomeScreen extends StatelessWidget {
  const QuizWelcomeScreen({super.key, required this.startQuiz, required this.restartQuiz});

  final void Function(String value) startQuiz;
  final void Function(String value) restartQuiz;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Home button pinned to the top-right below the safe area
        SafeArea(
          top: true,
          bottom: false,
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: HomeButton(startQuiz: startQuiz, restartQuiz: restartQuiz,),
            ),
          ),
        ),

        // Centered welcome content
        Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
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
          ),
        ),
      ],
    );
  }
}

class HomeButton extends StatelessWidget {
  const HomeButton({
    super.key,
    required this.startQuiz,
    required this.restartQuiz,
  });

  final void Function(String value) startQuiz;
  final void Function(String value) restartQuiz;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => restartQuiz("quiz-screen"),
      icon: const Icon(
        Icons.home,
        color: Colors.white70,
      ),
      label: const Text(
        "Home Screen",
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}
