import 'package:flutter/material.dart';
import 'package:flutter_application/quiz_app/questions/questiondata.dart';
import 'package:flutter_application/quiz_app/result_summary.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen(this.restartQuiz,
      {required this.chosenAnswers, super.key});

  final void Function(String value) restartQuiz;
  final List<String> chosenAnswers;

  List<Map<String, Object>> getSummaryData() {
    final List<Map<String, Object>> summary = [];
    for (var i = 0; i < chosenAnswers.length; i++) {
      summary.add({
        'question_index': i,
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

  int getCorrectQuestions() {
    var summary = getSummaryData();
    var correctQuestionsLength = summary
        .where((item) => item['user_answer'] == item['correct_answer'])
        .length;
    return correctQuestionsLength;
  }

  @override
  Widget build(BuildContext context) {
    final summaryData = getSummaryData();
    final numberOfCorrectQuestions = getCorrectQuestions();
    final totalNumberOfQuestions = chosenAnswers.length;

    return SizedBox(
        width: double.infinity,
        child: Container(
          margin: const EdgeInsets.all(25),
          child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'You have answered $numberOfCorrectQuestions out of $totalNumberOfQuestions correctly!',
                style: const TextStyle(
                    color: Color.fromARGB(255, 255, 94, 255),
                    fontSize: 22,
                    fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ResultSummary(summaryData),
              ElevatedButton(
                onPressed: restartQuizTapped,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 33, 1, 95),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                 child: const Text(
                  "Restart quiz"
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ));
  }
}
