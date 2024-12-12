import 'package:flutter/material.dart';
import 'package:flutter_application/quiz_app/questions/questiondata.dart';
import 'package:flutter_application/quiz_app/quiz_screen.dart';
import 'package:flutter_application/quiz_app/quiz_welcome_screen.dart';
import 'package:flutter_application/quiz_app/result_screen.dart';

class QuizLauncher extends StatefulWidget {
  const QuizLauncher({super.key});

  @override
  State<QuizLauncher> createState() => QuizLauncherState();
}

class QuizLauncherState extends State<QuizLauncher> {
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
    Widget screenWidget = QuizWelcomeScreen(setActiveScreen);

    if (activeScreen == 'quiz-screen') {
         screenWidget = QuizScreen(updateSelectedAnswers);
    } else if (activeScreen == 'start-screen') { 
        screenWidget = QuizWelcomeScreen(setActiveScreen);
    } else {
      screenWidget = ResultScreen(setActiveScreen, chosenAnswers: selectedAnswers);
      selectedAnswers = [];
    }

    return  Scaffold(
          body: Container(
              decoration: const BoxDecoration(color: Colors.deepPurple),
              child: screenWidget));
  }
}
