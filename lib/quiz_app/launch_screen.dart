import 'package:flutter/material.dart';
import 'package:flutter_application/quiz_app/questions/questiondata.dart';
import 'package:flutter_application/quiz_app/quiz_screen.dart';
import 'package:flutter_application/quiz_app/result_screen.dart';
import 'package:flutter_application/quiz_app/start_screen.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => LaunchScreenState();
}

class LaunchScreenState extends State<LaunchScreen> {
  var activeScreen = "start-screen";

  List<String> selectedAnswers = [];

  void setActiveScreen(String value) {
    setState(() {
      activeScreen = value;
    });
  }

  void updateSelectedAnswers(String answer){
    selectedAnswers.add(answer);
    if (selectedAnswers.length == questions.length){
      setState(() {
        setActiveScreen("result-screen");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget screenWidget = StartScreen(setActiveScreen);

    if (activeScreen == 'quiz-screen') {
         screenWidget = QuizScreen(updateSelectedAnswers);
    } else if (activeScreen == 'start-screen') { 
        screenWidget = StartScreen(setActiveScreen);
    } else {
      screenWidget = ResultScreen(setActiveScreen, chosenAnswers: selectedAnswers);
      selectedAnswers = [];
    }

    return MaterialApp(
      home: Scaffold(
          body: Container(
              decoration: const BoxDecoration(color: Colors.deepPurple),
              child: screenWidget)),
    );
  }
}
