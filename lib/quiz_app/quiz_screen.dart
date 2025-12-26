import 'package:flutter/material.dart';
import 'package:flutter_application/quiz_app/answerbutton.dart';
import 'package:flutter_application/quiz_app/questions/questiondata.dart';
import 'package:google_fonts/google_fonts.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen(this.updateSelectedAnswers,{super.key});

  final void Function(String answer) updateSelectedAnswers;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {

  var currentQuestionIndex = 0;
  final List<String> selectedAnswers = [];

  void answerButtonTapped(String answer) {
    widget.updateSelectedAnswers(answer); 
    showNextQuestion();
  }

  void showNextQuestion() {
    setState(() {
      currentQuestionIndex += 1;  
    });
  }

  @override
  Widget build(BuildContext context) {

  final model = questions[currentQuestionIndex];

    return  SizedBox(
      width: double.infinity,
        child: Container(
          margin: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(model.text, style: GoogleFonts.lato(
                color: const Color.fromARGB(255, 226, 220, 234),
                fontSize: 24,
                fontWeight: FontWeight.w700
                
              ), textAlign: TextAlign.center,),
              const SizedBox(height: 20),
              ...model.getShuffledAnswers().map((answer) => 
                AnswerButton(answerText: answer, onPressed: answerButtonTapped)
              )
            ],
          ),
        ),
    );
  }
}