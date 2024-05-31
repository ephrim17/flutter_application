import 'package:flutter/material.dart';
import 'package:flutter_application/quiz_app/quiz_screen.dart';
import 'package:flutter_application/quiz_app/start_screen.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => LaunchScreenState();
}

class LaunchScreenState extends State<LaunchScreen> {
  var activeScreen = "start-screen";

  void setActiveScreen(int value) {
    setState(() {
      activeScreen = "questions-screen";
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = activeScreen == 'start-screen'
        ? StartScreen(setActiveScreen)
        : const QuizScreen();
    return MaterialApp(
      home: Scaffold(
          body: Container(
              decoration: const BoxDecoration(color: Colors.deepPurple),
              child: screen)),
    );
  }
}
