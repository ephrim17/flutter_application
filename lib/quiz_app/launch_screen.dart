import 'package:flutter/material.dart';
import 'package:flutter_application/quiz_app/quiz_screen.dart';
import 'package:flutter_application/quiz_app/start_screen.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => LaunchScreenState();
}

class LaunchScreenState extends State<LaunchScreen> {
  //final screen = activeScreen

  Widget? activeScreen;

  void setActiveScreen(int value) {
    setState(() {
      activeScreen = const QuizScreen();
    });
  }

  @override
  void initState() {
    activeScreen = StartSceen(setActiveScreen);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          body: Container(
              decoration: const BoxDecoration(color: Colors.deepPurple),
              child: activeScreen)),
    );
  }
}
