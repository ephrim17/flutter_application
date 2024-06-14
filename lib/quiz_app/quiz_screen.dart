import 'package:flutter/material.dart';
import 'package:flutter_application/quiz_app/questions/answerButton.dart';
import 'package:flutter_application/quiz_app/questions/questionData.dart';

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

  final model = questions[0];

    return  SizedBox(
      width: double.infinity,
        child: Container(
          margin: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(model.text, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center,),
              const SizedBox(height: 20),
              ...model.getShuffledAnswers().map((answer) => 
                AnswerButton(answer, answerButtonTapped)
              )
            ],
          ),
        ),
    );
  }
}