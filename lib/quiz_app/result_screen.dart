import 'package:flutter/material.dart';
import 'package:flutter_application/quiz_app/questions/questiondata.dart';
import 'package:flutter_application/quiz_app/result_summary.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen(this.restartQuiz, {required this.chosenAnswers, super.key});

  final void Function(String value) restartQuiz;

  final List<String> chosenAnswers;

  List<Map<String, Object>> getSummaryData() {
    final List<Map<String, Object>> summary = [];
    for (var i = 0; i < chosenAnswers.length; i++){
      summary.add({
        'question_index' : i,
        'question': questions[i].text,
        'user_answer': chosenAnswers[i],
        'correct_answer': questions[i].answers[0],
      });
    }
    return summary;
  }

  void restartQuizTapped() {
    restartQuiz('start-screen');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        margin: const EdgeInsets.all(40),
        child: ResultSummary(getSummaryData()),
      )
    );
  }
}